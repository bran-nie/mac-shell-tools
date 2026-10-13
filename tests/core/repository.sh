#!/bin/sh
# Distribution boundaries, offline installation and explicitly online resources.
set -eu
project_dir=$1
. "$project_dir/tests/common.sh"
test_directory=$(mktemp -d "${TMPDIR:-/tmp}/mac-shell-tools-repository-test.XXXXXX")
trap 'chmod -R u+rwX "$test_directory"; rm -rf "$test_directory"' 0
trap 'exit 1' HUP INT TERM
fixture="$test_directory/release"
test_home="$test_directory/home"
install_directory="$test_home/.config/zsh/mac-shell-tools"
checks=0
download_mode=ok
archive_override=
mkdir -p "$test_home" "$test_directory/mock" "$test_directory/tmp"
copy_package "$project_dir" "$fixture"
printf '%s\n' sample.zsh remote.zsh > "$fixture/scripts/tools.list"
mkdir -p "$fixture/tools/remote"
printf '%s\n' 0.1.0-dev > "$fixture/tools/remote/VERSION"
cat > "$fixture/tools/remote/remote.zsh" <<'TOOL'
remote() {
  local remote_directory=${${(%):-%x}:A:h}
  "$remote_directory/bin/helper"
}
TOOL
printf '%s\n' online > "$fixture/tools/remote/install.mode"
printf '#!/bin/sh\nprintf "resource-ready\\n"\n' > "$test_directory/resource"
resource_digest=$(python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest())' "$test_directory/resource")
printf 'bin/helper\thttps://example.invalid/resource\t%s\texecutable\n' "$resource_digest" > "$fixture/tools/remote/downloads.list"
mock_release_curl "$test_directory/mock"
sh "$fixture/scripts/build-installer.sh" > "$test_directory/build"

fail() {
  printf 'FAIL repository: %s\n' "$*" >&2
  cat "$test_directory/out" "$test_directory/err" >&2
  exit 1
}
run_source() {
  env HOME="$test_home" XDG_CONFIG_HOME= ZDOTDIR= MST_LANG= RUNZSH=no TMPDIR="$test_directory/tmp" \
    /bin/sh "$fixture/install.sh" "$@" > "$test_directory/out" 2> "$test_directory/err" || fail "source $*"
  checks=$((checks + 1))
}
run_mst() {
  expected=$1; shift
  if env HOME="$test_home" XDG_CONFIG_HOME= ZDOTDIR= MST_LANG= RUNZSH=no TMPDIR="$test_directory/tmp" \
      PATH="$test_directory/mock:/usr/bin:/bin:/usr/sbin:/sbin" MST_RELEASE="$fixture/install.sh" \
      MST_RESOURCE="$test_directory/resource" MST_DOWNLOAD_MODE="$download_mode" MST_ARCHIVE="$archive_override" \
      MST_CURL_LOG="$test_directory/downloads" /bin/zsh -f -c 'source "$HOME/.zshrc"; mst "$@"' -- "$@" \
      > "$test_directory/out" 2> "$test_directory/err"; then actual=0; else actual=$?; fi
  [ "$actual" -eq "$expected" ] || fail "$*: expected $expected, got $actual"
  checks=$((checks + 1))
}
downloads() {
  if [ -f "$test_directory/downloads" ]; then wc -l < "$test_directory/downloads" | tr -d ' '; else printf 0; fi
}

[ "$(wc -l < "$fixture/install.sh")" = "$(wc -l < "$project_dir/install.sh")" ] || fail 'adding a tool grew the bootstrap'
[ "$(wc -l < "$fixture/install.sh")" -lt 120 ] || fail 'bootstrap is no longer lightweight'
if grep -Fq 'remote()' "$fixture/install.sh"; then fail 'bootstrap embeds tool source'; fi
run_source
cmp -s "$fixture/lib/manager.sh" "$install_directory/manager/manager-core.sh" || fail 'manager embeds tool payload'
[ -f "$install_directory/repository/tools/sample/sample.zsh" ] || fail 'initial scripts were not synchronized'
[ -f "$install_directory/repository/tools/remote/downloads.list" ] || fail 'online metadata not synchronized'
[ ! -e "$install_directory/repository/tools/remote/bin/helper" ] || fail 'sync downloaded online assets'
[ ! -e "$install_directory/tools/installed.list" ] || fail 'sync enabled tools'
[ "$(downloads)" -eq 0 ] || fail 'local snapshot synchronization accessed the network'

download_mode=fail
run_mst 0 install sample
run_mst 0 list
[ "$(downloads)" -eq 0 ] || fail 'ordinary installation accessed the network'
cp "$install_directory/tools/installed.list" "$test_directory/installed-before-online"
run_mst 1 install remote
cmp -s "$install_directory/tools/installed.list" "$test_directory/installed-before-online" || fail 'download failure registered a tool'
[ ! -e "$install_directory/tools/remote/remote.zsh" ] || fail 'download failure installed partial files'
download_mode=ok
cp "$test_directory/resource" "$test_directory/resource-original"
printf 'corrupted download\n' > "$test_directory/resource"
run_mst 1 install remote
cmp -s "$install_directory/tools/installed.list" "$test_directory/installed-before-online" || fail 'checksum failure changed installed state'
cp "$test_directory/resource-original" "$test_directory/resource"
run_mst 0 install remote
[ -x "$install_directory/tools/remote/bin/helper" ] || fail 'executable resource lost permissions'
env HOME="$test_home" /bin/zsh -f -c 'source "$HOME/.zshrc"; remote' > "$test_directory/result"
[ "$(cat "$test_directory/result")" = resource-ready ] || fail 'online tool cannot use its resource'

cp -R "$install_directory/tools" "$test_directory/tools-before-upgrade"
printf '0.3.0\n' > "$fixture/VERSION"
printf '\n# synchronized revision\n' >> "$fixture/tools/sample/sample.zsh"
sh "$fixture/scripts/build-installer.sh" > "$test_directory/build"
run_mst 0 upgrade
diff -r "$install_directory/tools" "$test_directory/tools-before-upgrade" > "$test_directory/diff" || fail 'upgrade changed installed tools'
tool_matches "$fixture" sample "$install_directory/repository/tools/sample/sample.zsh" || fail 'upgrade did not sync tool source'
[ ! -e "$install_directory/repository/tools/remote/bin/helper" ] || fail 'upgrade downloaded online resources'
cp -R "$install_directory/manager" "$test_directory/manager-before-update"
printf '0.4.0\n' > "$fixture/VERSION"
printf '0.2.0\n' > "$fixture/tools/sample/VERSION"
printf '\n# updated revision\n' >> "$fixture/tools/sample/sample.zsh"
sh "$fixture/scripts/build-installer.sh" > "$test_directory/build"
run_mst 0 update sample
diff -r "$install_directory/manager" "$test_directory/manager-before-update" > "$test_directory/diff" || fail 'update replaced the manager'
[ "$(sed -n '1p' "$install_directory/repository/tools/sample/version")" = 0.2.0 ] || fail 'update did not sync repository'
[ "$(sed -n '1p' "$install_directory/tools/sample/version")" = 0.2.0 ] || fail 'update did not record installed version'
download_mode=fail
count=$(downloads)
run_mst 0 uninstall sample
run_mst 0 install sample
[ "$(downloads)" -eq "$count" ] || fail 'reinstall required network'
run_mst 0 list
grep -Fq '0.2.0' "$test_directory/out" || fail 'available version came from manager'
run_mst 0 uninstall remote
[ ! -e "$install_directory/tools/remote/bin/helper" ] || fail 'uninstall left downloaded resource'
download_mode=ok
count=$(downloads)
run_mst 0 install remote
[ "$(downloads)" -eq "$((count + 1))" ] || fail 'online install downloaded more than declared resource'

printf 'personal content\n' > "$install_directory/tools/remote/notes.txt"
rm "$fixture/tools/remote/install.mode" "$fixture/tools/remote/downloads.list"
printf 'remote() { print -r -- local-ready; }\n' > "$fixture/tools/remote/remote.zsh"
sh "$fixture/scripts/build-installer.sh" > "$test_directory/build"
run_source update remote
[ ! -e "$install_directory/tools/remote/bin/helper" ] || fail 'obsolete online resource retained'
[ ! -e "$install_directory/repository/tools/remote/downloads.list" ] || fail 'obsolete repository metadata retained'
[ -f "$install_directory/tools/remote/notes.txt" ] || fail 'update removed personal file'

cp "$install_directory/repository/catalog.tsv" "$test_directory/catalog"
printf 'touch %s/executed\n' "$test_home" > "$install_directory/repository/catalog.tsv"
run_mst 1 list
[ ! -e "$test_home/executed" ] || fail 'catalog executed'
cp "$test_directory/catalog" "$install_directory/repository/catalog.tsv"
mv "$install_directory/repository/tools/sample/locales" "$test_directory/locales"
ln -s "$test_directory/locales" "$install_directory/repository/tools/sample/locales"
run_mst 1 install sample
rm "$install_directory/repository/tools/sample/locales"
mv "$test_directory/locales" "$install_directory/repository/tools/sample/locales"

cp -R "$install_directory/tools" "$test_directory/stable-tools"
cp -R "$install_directory/manager" "$test_directory/stable-manager"
for invalid_archive in traversal link invalid-tool missing-metadata; do
  archive_override="$test_directory/$invalid_archive.tar.gz"
  python3 - "$fixture" "$archive_override" "$invalid_archive" <<'PYARCHIVE'
import io
import sys
import tarfile
from pathlib import Path
source, destination, kind = sys.argv[1:]
with tarfile.open(destination, "w:gz") as archive:
    for path in Path(source).rglob("*"):
        name = "release/" + path.relative_to(source).as_posix()
        if kind == "missing-metadata" and name == "release/package.meta":
            continue
        if kind == "invalid-tool" and name == "release/tools/sample/sample.zsh":
            data = b"if (\n"
            entry = tarfile.TarInfo(name)
            entry.size = len(data)
            archive.addfile(entry, io.BytesIO(data))
        else:
            archive.add(path, arcname=name, recursive=False)
    if kind == "traversal":
        archive.addfile(tarfile.TarInfo("release/../escape"))
    elif kind == "link":
        entry = tarfile.TarInfo("release/linked")
        entry.type = tarfile.SYMTYPE
        entry.linkname = "/tmp"
        archive.addfile(entry)
PYARCHIVE
  run_mst 1 upgrade
  diff -r "$install_directory/tools" "$test_directory/stable-tools" > "$test_directory/diff" || fail 'invalid archive changed tools'
  diff -r "$install_directory/manager" "$test_directory/stable-manager" > "$test_directory/diff" || fail 'invalid archive changed manager'
done
# Cache loss must remain recoverable through upgrade and cannot block uninstall.
archive_override=
rm -rf "$install_directory/repository"
download_mode=fail
run_mst 1 list
run_mst 0 uninstall sample
run_mst 1 install sample
download_mode=ok
run_mst 0 upgrade
[ -f "$install_directory/repository/tools/sample/sample.zsh" ] || fail 'upgrade cannot repair a missing repository'
[ ! -e "$install_directory/tools/sample/sample.zsh" ] || fail 'cache repair reinstalled an uninstalled tool'
for temporary in "$test_directory/tmp"/mac-shell-tools-*; do
  [ ! -e "$temporary" ] || fail 'operation left temporary files'
done
printf 'PASS repository: %s synchronization, offline install, online resource, and archive checks.\n' "$checks"
