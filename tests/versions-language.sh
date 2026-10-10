#!/bin/sh
# Version and language contracts, with local releases and an isolated HOME.
set -eu
project_dir=$1
. "$project_dir/tests/common.sh"
test_directory=$(mktemp -d "${TMPDIR:-/tmp}/mac-shell-tools-language-test.XXXXXX")
trap 'chmod -R u+rwX "$test_directory"; rm -rf "$test_directory"' 0
trap 'exit 1' HUP INT TERM
checks=0
test_home="$test_directory/home"
install_directory="$test_home/.config/zsh/mac-shell-tools"
manager_directory="$install_directory/manager"
zshrc="$test_home/.zshrc"
mkdir -p "$test_home" "$test_directory/mock"
: > "$test_directory/out"
: > "$test_directory/err"

fail() {
  printf 'FAIL versions/language: %s\n' "$*" >&2
  cat "$test_directory/out" "$test_directory/err" >&2
  exit 1
}

run() {
  expected=$1; shift
  if env HOME="$test_home" XDG_CONFIG_HOME= ZDOTDIR= MST_LANG= RUNZSH=no \
      /bin/sh "$project_dir/install.sh" "$@" > "$test_directory/out" 2> "$test_directory/err"; then actual=0; else actual=$?; fi
  [ "$actual" -eq "$expected" ] || fail "$*: expected $expected, got $actual"
  checks=$((checks + 1))
}

shell_run() {
  expected=$1; code=$2
  if env HOME="$test_home" XDG_CONFIG_HOME= ZDOTDIR= MST_LANG= RUNZSH=no \
      PATH="$test_directory/mock:/usr/bin:/bin:/usr/sbin:/sbin" MST_RELEASE="$fixture/install.sh" \
      /bin/zsh -f -c 'source "$HOME/.zshrc"; eval "$1"' -- "$code" \
      > "$test_directory/out" 2> "$test_directory/err"; then actual=0; else actual=$?; fi
  [ "$actual" -eq "$expected" ] || fail "$code: expected $expected, got $actual"
  checks=$((checks + 1))
}

# Read-only commands do not create installation state.
run 0 --version
package_version=$(awk '/^# Package version: / {print $4; exit}' "$project_dir/install.sh")
grep -Fq "mst $package_version (" "$test_directory/out" || fail 'bootstrap version missing'
run 0 --help
grep -Fq 'Usage: mst' "$test_directory/out" || fail 'default is not English'
run 0 config language
grep -Fxq 'Language: en' "$test_directory/out" || fail 'default language is not en'
[ ! -e "$test_home/.config" ] && [ ! -e "$zshrc" ] || fail 'query wrote configuration'

fixture="$test_directory/release"
copy_package "$project_dir" "$fixture"
printf '0.2.0\n' > "$fixture/VERSION"
printf '\n# Next tool release\n' >> "$fixture/tools/dsize/dsize.zsh"
printf '\n# Next tool catalog\n' >> "$fixture/tools/dsize/locales/en.sh"
printf '\n# Next manager catalog\n' >> "$fixture/locales/en.sh"
sh "$fixture/scripts/build-installer.sh" > "$test_directory/build"
cat > "$test_directory/mock/curl" <<'MOCK'
#!/bin/sh
set -eu
while [ "$#" -gt 0 ]; do
  case $1 in -o) output=$2; shift 2 ;; *) shift ;; esac
done
cp "$MST_RELEASE" "$output"
MOCK
chmod +x "$test_directory/mock/curl"
run 0 install dsize
[ "$(sed -n '1p' "$manager_directory/version")" = "$package_version" ] || fail 'manager version record'
[ "$(sed -n '1p' "$install_directory/tools/dsize/version")" = "$package_version" ] || fail 'tool version record'
[ "$(awk -F '\t' '{print $2}' "$install_directory/tools/installed.list")" = "$package_version" ] || fail 'manifest version record'
shell_run 0 'mst --version; dsize --version'
grep -Fq "dsize $package_version (" "$test_directory/out" || fail 'tool version output'

# A language change affects an already loaded function on the next invocation.
shell_run 0 'mst config language zh-CN; dsize --help; mst --help'
grep -Fq '用法：dsize' "$test_directory/out" || fail 'loaded tool did not switch'
grep -Fq '用法：mst' "$test_directory/out" || fail 'manager did not switch'
shell_run 2 'mst invalid-command'
grep -Fq '未知命令' "$test_directory/err" || fail 'saved language did not apply to parse errors'
shell_run 2 'dsize --invalid'
grep -Fq '未知选项' "$test_directory/err" || fail 'tool error did not switch'
shell_run 0 'mst --lang en --help; mst config language'
grep -Fq 'Usage: mst' "$test_directory/out" || fail '--lang not effective'
grep -Fq 'zh-CN' "$test_directory/out" || fail '--lang changed saved preference'
[ "$(cat "$install_directory/config.conf")" = language=zh-CN ] || fail 'one-off persisted'
shell_run 0 'MST_LANG=en dsize --help; MST_LANG=en mst --lang zh-CN --help'
grep -Fq 'Usage: dsize' "$test_directory/out" || fail 'environment override ignored'
grep -Fq '用法：mst' "$test_directory/out" || fail '--lang did not override environment'
shell_run 0 'mst config language en; dsize --help'
grep -Fq 'Usage: dsize' "$test_directory/out" || fail 'English switch did not apply'

# Both languages produce identical disk-usage data and version identifiers.
shell_run 0 'dsize "$HOME" -d 0; MST_LANG=zh-CN dsize "$HOME" -d 0'
[ "$(sed -n '1p' "$test_directory/out")" = "$(sed -n '2p' "$test_directory/out")" ] || fail 'language changed data'
shell_run 0 'dsize --version; MST_LANG=zh-CN dsize --version'
[ "$(sed -n '1p' "$test_directory/out")" = "$(sed -n '2p' "$test_directory/out")" ] || fail 'language changed version'

# Missing translations fall back per key; catalogs are loaded from component files.
cp "$manager_directory/locales/zh-CN.sh" "$test_directory/manager-zh"
printf 'mst_text_zh_CN() { return 1; }\n' > "$manager_directory/locales/zh-CN.sh"
shell_run 0 'mst --lang zh-CN --help'
grep -Fq 'Usage: mst' "$test_directory/out" || fail 'manager fallback missing'
cp "$test_directory/manager-zh" "$manager_directory/locales/zh-CN.sh"
cp "$install_directory/tools/dsize/locales/zh-CN.sh" "$test_directory/tool-zh"
printf 'mst_text_zh_CN() { return 1; }\n' > "$install_directory/tools/dsize/locales/zh-CN.sh"
shell_run 0 'MST_LANG=zh-CN dsize --help'
grep -Fq 'Usage: dsize' "$test_directory/out" || fail 'tool fallback missing'
rm "$install_directory/tools/dsize/locales/zh-CN.sh"
shell_run 0 'MST_LANG=zh-CN dsize --help'
grep -Fq 'Usage: dsize' "$test_directory/out" || fail 'missing catalog fallback'
cp "$test_directory/tool-zh" "$install_directory/tools/dsize/locales/zh-CN.sh"

# Configuration is data: no executable lines, duplicate values, or links accepted.
for invalid in executable duplicate unsupported; do
  case $invalid in
    executable) printf 'touch %s/executed\n' "$test_home" > "$install_directory/config.conf" ;;
    duplicate) printf 'language=en\nlanguage=zh-CN\n' > "$install_directory/config.conf" ;;
    unsupported) printf 'language=fr\n' > "$install_directory/config.conf" ;;
  esac
  shell_run 2 'mst list'
  shell_run 2 'dsize --help'
  [ ! -e "$test_home/executed" ] || fail 'configuration executed'
done
shell_run 0 'mst --lang en config language en'
cp "$install_directory/config.conf" "$test_directory/settings"
rm "$install_directory/config.conf"
ln -s "$test_directory/settings" "$install_directory/config.conf"
shell_run 2 'mst list'
shell_run 1 'mst --lang en config language zh-CN'
[ "$(cat "$test_directory/settings")" = language=en ] || fail 'configuration link target changed'
rm "$install_directory/config.conf"
cp "$test_directory/settings" "$install_directory/config.conf"
shell_run 2 'mst --lang fr list'
shell_run 2 'mst config language fr'

# Upgrade changes manager version/catalog but keeps every tool asset and record.
cp -R "$install_directory/tools" "$test_directory/old-tools"
cp "$manager_directory/locales/en.sh" "$test_directory/old-manager-en"
shell_run 0 'mst upgrade'
grep -Fq '0.2.0' "$manager_directory/version" || fail 'manager version not upgraded'
diff -r "$install_directory/tools" "$test_directory/old-tools" > "$test_directory/diff" || fail 'upgrade changed tools'
cmp -s "$manager_directory/locales/en.sh" "$fixture/locales/en.sh" || fail 'manager language pack not upgraded'
shell_run 0 'mst list'
grep -Fq "$package_version" "$test_directory/out" || fail 'installed version lost'
grep -Fq '0.2.0' "$test_directory/out" || fail 'catalog version not upgraded'
cp -R "$manager_directory" "$test_directory/manager-after-upgrade"

# Update changes the complete tool bundle and its record, without replacing mst.
# The loaded function retains its version until its source is loaded again.
shell_run 0 'mst update dsize; dsize --version; source "$HOME/.zshrc"; dsize --version'
grep -Fq "dsize $package_version (" "$test_directory/out" || fail 'loaded version changed without reload'
grep -Fq 'dsize 0.2.0 (' "$test_directory/out" || fail 'new loaded version missing'
diff -r "$manager_directory" "$test_directory/manager-after-upgrade" > "$test_directory/diff" || fail 'update changed manager'
cmp -s "$install_directory/tools/dsize/locales/en.sh" "$fixture/tools/dsize/locales/en.sh" || fail 'tool language pack not updated'
[ "$(awk -F '\t' '{print $2}' "$install_directory/tools/installed.list")" = 0.2.0 ] || fail 'updated manifest version'

# A version record must still work without a final newline.
unterminated_record=$(cat "$install_directory/tools/installed.list")
printf '%s' "$unterminated_record" > "$install_directory/tools/installed.list"
shell_run 0 'mst list'
grep -Eq '^dsize[[:space:]]+installed[[:space:]]+0.2.0' "$test_directory/out" || fail 'unterminated record lost'

# Generated files remain stable; canonical source edits must make --check fail.
cp "$fixture/install.sh" "$test_directory/generated"
sh "$fixture/scripts/build-installer.sh" > "$test_directory/build"
cmp -s "$fixture/install.sh" "$test_directory/generated" || fail 'build is not deterministic'
sh "$fixture/scripts/build-installer.sh" --check > "$test_directory/build"
printf '\n# changed translation source\n' >> "$fixture/locales/en.sh"
if sh "$fixture/scripts/build-installer.sh" --check > "$test_directory/out" 2> "$test_directory/err"; then fail 'stale installer accepted'; fi
sh "$fixture/scripts/build-installer.sh" > "$test_directory/build"
sh "$fixture/scripts/build-installer.sh" --check > "$test_directory/build"
checks=$((checks + 3))

# Publication commits do not invalidate recorded source provenance.
git -C "$fixture" init -q
git -C "$fixture" add .
git -C "$fixture" -c user.name=MST-Test -c user.email=mst@example.invalid -c commit.gpgsign=false \
  -c core.hooksPath=/dev/null commit -qm 'Source snapshot'
source_commit=$(git -C "$fixture" rev-parse HEAD)
sh "$fixture/scripts/build-installer.sh" --refresh-revision > "$test_directory/build"
grep -Fxq "# Source revision: $source_commit" "$fixture/install.sh" || fail 'source revision missing'
grep -Fxq '# Source state: clean' "$fixture/install.sh" || fail 'clean source marked modified'
git -C "$fixture" add install.sh
git -C "$fixture" -c user.name=MST-Test -c user.email=mst@example.invalid -c commit.gpgsign=false \
  -c core.hooksPath=/dev/null commit -qm 'Generated package'
sh "$fixture/scripts/build-installer.sh" --check > "$test_directory/build"
checks=$((checks + 1))

# Complete catalogs share keys and printf arguments; fallback is tested above.
for catalog_directory in "$project_dir/locales" "$project_dir"/tools/*/locales; do
  for catalog_language in en zh-CN; do
    awk '/^[[:space:]]+[a-z][a-z_.]*\)/ {key=$1; sub(/\)$/, "", key); print key}' \
      "$catalog_directory/$catalog_language.sh" > "$test_directory/keys-$catalog_language"
  done
  cmp -s "$test_directory/keys-en" "$test_directory/keys-zh-CN" || fail 'catalog keys differ'
  while IFS= read -r key; do
    english_format=$(/bin/sh -c '. "$1/en.sh"; mst_text_en "$2"' -- "$catalog_directory" "$key")
    chinese_format=$(/bin/sh -c '. "$1/zh-CN.sh"; mst_text_zh_CN "$2"' -- "$catalog_directory" "$key")
    english_arguments=$(printf '%s\n' "$english_format" | sed 's/[^%]//g')
    chinese_arguments=$(printf '%s\n' "$chinese_format" | sed 's/[^%]//g')
    [ "$english_arguments" = "$chinese_arguments" ] || fail "catalog arguments differ: $key"
  done < "$test_directory/keys-en"
  checks=$((checks + 1))
done
printf 'PASS versions/language: %s version, language, and package checks.\n' "$checks"
