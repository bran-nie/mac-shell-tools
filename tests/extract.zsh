#!/bin/zsh
# Native macOS/Linux backends; Python is used only to construct adversarial fixtures.
emulate -R zsh
setopt nounset pipefail
project_directory=$1
test_directory=$(mktemp -d "${TMPDIR:-/tmp}/mac-shell-tools-extract-test.XXXXXX") || exit 1
trap 'rm -rf "$test_directory"' EXIT
trap 'exit 1' HUP INT TERM
checks=0
fail() { print -ru2 -- "FAIL extract: $*"; exit 1; }
expect_status() {
  local expected=$1 label=$2 actual
  shift 2
  "$@" > "$test_directory/out" 2> "$test_directory/err"
  actual=$?
  [[ $actual == $expected ]] || fail "$label: expected $expected, got $actual; $(<"$test_directory/err")"
  if (( expected )); then [[ -s "$test_directory/err" ]] || fail "$label: missing diagnostic"; fi
  (( checks++ ))
  return 0
}
mkdir -p "$test_directory/archives" "$test_directory/work" "$test_directory/mock"
python3 - "$test_directory/archives" <<'PY'
import io, pathlib, stat, sys, tarfile, zipfile
root = pathlib.Path(sys.argv[1])
content = b"example content\n"
formats = {"tar": "w", "tar.gz": "w:gz", "tgz": "w:gz", "tar.bz2": "w:bz2", "tbz2": "w:bz2", "tar.xz": "w:xz", "txz": "w:xz", "TAR.GZ": "w:gz"}
for extension, mode in formats.items():
    with tarfile.open(root / ("sample." + extension), mode) as archive:
        directory = tarfile.TarInfo("nested/")
        directory.type = tarfile.DIRTYPE
        directory.mode = 0o755
        archive.addfile(directory)
        entry = tarfile.TarInfo("nested/中文 file.txt")
        entry.size, entry.mode = len(content), 0o644
        archive.addfile(entry, io.BytesIO(content))
for name in ("sample.zip", "空格 [a]*.ZIP", "-dash.zip", ".zip"):
    with zipfile.ZipFile(root / name, "w") as archive:
        archive.writestr("nested/", "")
        archive.writestr("nested/中文 file.txt", content)
for name in ("../outside", "/tmp/mst-absolute-escape", "safe/../../outside"):
    identifier = {"../outside": "parent", "/tmp/mst-absolute-escape": "absolute", "safe/../../outside": "nested-parent"}[name]
    with tarfile.open(root / (identifier + ".tar"), "w") as archive:
        entry = tarfile.TarInfo(name)
        entry.size = len(content)
        archive.addfile(entry, io.BytesIO(content))
    with zipfile.ZipFile(root / (identifier + ".zip"), "w") as archive:
        archive.writestr(name, content)
for identifier, kind in (("symlink", tarfile.SYMTYPE), ("hardlink", tarfile.LNKTYPE), ("fifo", tarfile.FIFOTYPE), ("device", tarfile.CHRTYPE)):
    with tarfile.open(root / (identifier + ".tar"), "w") as archive:
        entry = tarfile.TarInfo("pivot")
        entry.type, entry.linkname = kind, "../outside"
        archive.addfile(entry)
with zipfile.ZipFile(root / "symlink.zip", "w") as archive:
    entry = zipfile.ZipInfo("pivot")
    entry.create_system = 3
    entry.external_attr = (stat.S_IFLNK | 0o777) << 16
    archive.writestr(entry, "../outside")
for identifier, name in (("windows-parent", "..\\outside"), ("windows-drive", "C:/outside"), ("tab", "has\ttab")):
    with zipfile.ZipFile(root / (identifier + ".zip"), "w") as archive:
        archive.writestr(name, content)
(root / "corrupt.zip").write_bytes(b"not a zip")
(root / "corrupt.tar.gz").write_bytes(b"not a tar")
(root / "unknown.rar").write_bytes(b"unsupported")
PY
# Native encryption fixture; the password is public test data, not a credential.
print -r -- 'encrypted fixture' > "$test_directory/archives/encrypted-content"
( cd "$test_directory/archives" && zip -q -P fixture-password encrypted.zip encrypted-content ) || fail 'encrypted fixture creation'
cd "$test_directory/work" || exit 1
before_directory=$PWD
before_options=$(setopt)
before_traps=$(trap)
before_umask=$(umask)
source "$project_directory/tools/extract/extract.zsh" > "$test_directory/out" 2> "$test_directory/err"
[[ ! -s "$test_directory/out" && ! -s "$test_directory/err" ]] || fail 'noisy source'
expect_status 0 help extract --help
expect_status 0 short-help extract -h
expect_status 0 version extract --version
[[ $(<"$test_directory/out") == 'extract development (unbuilt; unknown)' ]] || fail 'source version'
format_index=0
for extension in tar tar.gz tgz tar.bz2 tbz2 tar.xz txz TAR.GZ zip; do
  (( format_index++ ))
  expect_status 0 "$extension" extract "$test_directory/archives/sample.$extension" -C "result-$format_index"
  [[ $(<"result-$format_index/nested/中文 file.txt") == 'example content' ]] || fail "$extension content"
done
expect_status 0 default-directory extract "$test_directory/archives/sample.tar.gz"
[[ -f sample/nested/'中文 file.txt' ]] || fail 'default destination'
expect_status 0 wildcard-archive-name extract "$test_directory/archives/空格 [a]*.ZIP"
[[ -f '空格 [a]*/nested/中文 file.txt' ]] || fail 'wildcard or Unicode archive name'
cp "$test_directory/archives/-dash.zip" ./-dash.zip
expect_status 0 dash-archive-name extract -- -dash.zip
[[ -f '-dash/nested/中文 file.txt' ]] || fail 'dash archive'
expect_status 0 hidden-archive-name extract "$test_directory/archives/.zip"
[[ -f .zip.extracted/nested/'中文 file.txt' ]] || fail 'empty basename fallback'
cp "$test_directory/archives/sample.zip" "$test_directory/archives/archive-data"
ln -s archive-data "$test_directory/archives/linked.zip"
expect_status 0 symlink-archive-input extract "$test_directory/archives/linked.zip"
[[ -f linked/nested/'中文 file.txt' ]] || fail 'archive input name was lost'
expect_status 0 list-only extract --list "$test_directory/archives/sample.zip"
[[ $(<"$test_directory/out") == *'nested/'* && ! -d "$test_directory/archives/sample" ]] || fail 'preview output'
expect_status 0 short-list extract "$test_directory/archives/sample.tar" -l
expect_status 0 directory-equals extract --directory='space 目录' "$test_directory/archives/sample.zip"
[[ -f 'space 目录/nested/中文 file.txt' ]] || fail 'destination quoting'
expect_status 0 repeated-destination extract -C first --directory final "$test_directory/archives/sample.tar"
[[ ! -e first && -f final/nested/'中文 file.txt' ]] || fail 'last directory option'
expect_status 2 no-archive extract
expect_status 2 two-archives extract a.zip b.zip
expect_status 2 missing-archive extract missing.zip
expect_status 2 empty-archive extract ''
expect_status 2 unknown-option extract --invalid
expect_status 2 missing-directory extract -C
expect_status 2 empty-directory extract --directory=
expect_status 2 list-and-directory extract --list -C new "$test_directory/archives/sample.zip"
expect_status 2 unsupported extract "$test_directory/archives/unknown.rar"
expect_status 2 existing-directory extract "$test_directory/archives/sample.tar" -C sample
print -r -- original > existing-file
expect_status 2 existing-file extract "$test_directory/archives/sample.zip" -C existing-file
[[ $(<existing-file) == original ]] || fail 'existing file overwritten'
ln -s missing-target dangling
expect_status 2 dangling-symlink extract "$test_directory/archives/sample.zip" -C dangling
expect_status 2 missing-parent extract "$test_directory/archives/sample.zip" -C missing-parent/new
for archive in corrupt.zip corrupt.tar.gz; do
  expect_status 1 "$archive" extract "$test_directory/archives/$archive" -C corrupt-result
  [[ ! -e corrupt-result ]] || fail 'corrupt archive created destination'
done
expect_status 2 encrypted-ZIP extract "$test_directory/archives/encrypted.zip" -C encrypted-result
[[ ! -e encrypted-result && $(<"$test_directory/err") == *'Encrypted ZIP entries are unsupported'* ]] || fail 'encrypted ZIP was not rejected before unpacking'
expect_status 0 encrypted-ZIP-preview extract --list "$test_directory/archives/encrypted.zip"
for archive in parent.zip absolute.zip nested-parent.zip windows-parent.zip windows-drive.zip symlink.zip symlink.tar hardlink.tar fifo.tar device.tar; do
  expect_status 2 "$archive" extract "$test_directory/archives/$archive" -C rejected
  [[ ! -e rejected && ! -e outside ]] || fail "$archive wrote before validation"
done
# tar can itself reject unsafe names during listing; either explicit rejection or
# a backend read failure is acceptable, provided there is no extraction.
for archive in parent.tar absolute.tar nested-parent.tar; do
  extract "$test_directory/archives/$archive" -C rejected > "$test_directory/out" 2> "$test_directory/err"
  actual=$?
  [[ ( $actual == 1 || $actual == 2 ) && ! -e rejected && -s "$test_directory/err" ]] || fail "$archive containment"
  (( checks++ ))
done

# Backend option variables are ignored only inside the tool's subshell.
export TAR_OPTIONS='--not-a-real-option' UNZIPOPT='--not-a-real-option' ZIPINFOOPT='--not-a-real-option'
expect_status 0 isolated-tar-options extract "$test_directory/archives/sample.tar" -C isolated-tar
expect_status 0 isolated-zip-options extract "$test_directory/archives/sample.zip" -C isolated-zip
[[ $TAR_OPTIONS == --not-a-real-option && $UNZIPOPT == --not-a-real-option ]] || fail 'caller environment changed'
unset TAR_OPTIONS UNZIPOPT ZIPINFOOPT
MST_LANG=zh-CN expect_status 0 Chinese-help extract --help
[[ $(<"$test_directory/out") == *'用法：extract'* ]] || fail 'Chinese help'
MST_LANG=zh-CN expect_status 0 Chinese-success extract "$test_directory/archives/sample.zip" -C Chinese
[[ $(<"$test_directory/out") == *'已解压到：'* ]] || fail 'Chinese success'
PATH=/nonexistent expect_status 0 help-without-dependencies extract --help
PATH=/nonexistent expect_status 1 missing-dependency extract "$test_directory/archives/sample.zip" -C no-dependency

# A real extraction failure must retain partial files and explain the location.
cat > "$test_directory/mock/tar" <<'MOCK'
#!/bin/sh
case $1 in
  -tf|-tvf) exec /usr/bin/tar "$@" ;;
  -xf) printf 'partial\n' > "$4/partial"; exit 1 ;;
esac
exit 2
MOCK
chmod +x "$test_directory/mock/tar"
PATH="$test_directory/mock:$PATH" expect_status 1 partial-output extract "$test_directory/archives/sample.tar" -C partial
[[ -f partial/partial && $(<"$test_directory/err") == *"$PWD/partial"* ]] || fail 'partial output missing'
[[ $PWD == $before_directory && $(setopt) == $before_options && $(trap) == $before_traps && $(umask) == $before_umask ]] || fail 'caller state changed'
[[ -z $(print -rl -- "$TMPDIR"/mst-extract.*(N)) ]] || fail 'temporary snapshot leaked'
print -r -- "PASS extract: $checks format, content, containment, failure, language, and isolation checks."
