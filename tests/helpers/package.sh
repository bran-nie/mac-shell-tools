#!/bin/sh
# The same package contract runs for each catalog component, with a small peer.
set -eu
project_dir=$1
tool=$2
peer=$(awk -v actual="$tool.zsh" '$0 != actual {sub(/\.zsh$/, ""); print; exit}' "$project_dir/scripts/tools.list")
. "$project_dir/tests/common.sh"
test_directory=$(mktemp -d "${TMPDIR:-/tmp}/mst-package.XXXXXX")
trap 'rm -rf "$test_directory"' 0
trap 'exit 1' HUP INT TERM
export HOME="$test_directory/home" XDG_CONFIG_HOME= ZDOTDIR= MST_LANG= RUNZSH=no
mkdir -p "$HOME"
install_directory="$HOME/.config/zsh/mac-shell-tools"
mock_node_npm "$test_directory/bin"
export PATH="$test_directory/bin:$PATH"
fail() { printf 'FAIL package %s: %s\n' "$tool" "$*" >&2; exit 1; }
run() { sh "$project_dir/install.sh" "$@"; }
run
[ ! -e "$install_directory/tools/installed.list" ] || fail 'bootstrap enabled a component'
run list > "$test_directory/list"
awk -v tool="$tool" '$1 == tool && $2 == "not" && $3 == "installed" {found=1} END {exit !found}' "$test_directory/list" || fail 'missing catalog entry'
run install "$tool"
[ ! -e "$install_directory/tools/$peer" ] || fail 'selective install enabled peer'
[ "$(wc -l < "$install_directory/tools/installed.list" | tr -d ' ')" -eq 1 ] || fail 'selective manifest'
for resource in "$tool.zsh" version files.list LICENSE; do
  [ -f "$install_directory/tools/$tool/$resource" ] || fail "missing $resource"
done
for resource in locales/en.sh locales/zh-CN.sh dependencies.list install.mode downloads.list; do
  if [ -f "$project_dir/tools/$tool/$resource" ]; then
    cmp -s "$project_dir/tools/$tool/$resource" "$install_directory/tools/$tool/$resource" || fail "incorrect $resource"
    grep -Fxq "$resource" "$install_directory/tools/$tool/files.list" || fail "unowned $resource"
  fi
done
version=$(sed -n '1p' "$project_dir/tools/$tool/package.meta")
zsh -f -c '
  source "$HOME/.zshrc"
  (( $+functions[$1] && ! $+functions[$2] )) || exit 1
  "$1" --help; "$1" --version
  mst config language zh-CN
  "$1" --help
  mst config language en
  "$1" --help
' -- "$tool" "$peer" > "$test_directory/output" || fail 'installed invocation/language switching'
grep -Fq "Usage: $tool" "$test_directory/output" || fail 'English help'
grep -Fq "用法：$tool" "$test_directory/output" || fail 'Chinese help'
grep -Fq "$tool $version (" "$test_directory/output" || fail 'installed version'

# Keep real component language and loaded-version boundaries here, while core
# tests use synthetic components to exercise manager configuration and upgrades.
language_output() {
  env MST_LANG="$1" zsh -f -c 'source "$HOME/.zshrc"; "$1" "$2"' -- "$tool" "$2"
}
english_help=$(language_output en --help)
english_version=$(language_output en --version)
[ "$(language_output zh-CN --version)" = "$english_version" ] || fail 'language changed version'
run config language zh-CN
[ "$(language_output en --help)" = "$english_help" ] || fail 'environment did not override saved language'
translation="$install_directory/tools/$tool/locales/zh-CN.sh"
cp "$translation" "$test_directory/translation"
printf 'mst_text_zh_CN() { return 1; }\n' > "$translation"
[ "$(language_output '' --help)" = "$english_help" ] || fail 'missing-key fallback'
rm "$translation"
[ "$(language_output '' --help)" = "$english_help" ] || fail 'missing-catalog fallback'
cp "$test_directory/translation" "$translation"
printf 'touch %s/executed\n' "$test_directory" > "$install_directory/config.conf"
if language_output '' --help > "$test_directory/output" 2> "$test_directory/error"; then
  fail 'executable language configuration accepted'
else
  [ "$?" -eq 2 ] || fail 'invalid configuration exit code'
fi
[ ! -e "$test_directory/executed" ] || fail 'configuration executed'
run --lang en config language en

installed_source="$install_directory/tools/$tool/$tool.zsh"
cp "$installed_source" "$test_directory/installed-source"
zsh -f -c '
  source "$HOME/.zshrc"
  original_version=$("$1" --version) || exit 1
  source_text=$(<"$3")
  print -r -- "${source_text//$2/contract-next}" > "$3"
  [[ $("$1" --version) == "$original_version" ]] || exit 1
  source "$HOME/.zshrc"
  [[ $("$1" --version) == "$1 contract-next ("* ]] || exit 1
' -- "$tool" "$version" "$installed_source" || fail 'loaded version changed before reload or failed to refresh'
cp "$test_directory/installed-source" "$installed_source"
run install --all
printf 'personal\n' > "$install_directory/tools/$tool/personal.txt"
run uninstall "$tool"
[ -f "$install_directory/tools/$tool/personal.txt" ] || fail 'personal file removed'
[ ! -e "$install_directory/tools/$tool/$tool.zsh" ] || fail 'managed source retained'
zsh -f -c 'source "$HOME/.zshrc"; (( $+functions[mst] && $+functions[$2] && ! $+functions[$1] ))' -- "$tool" "$peer" || fail 'peer or manager removed'
run uninstall --all
zsh -f -c 'source "$HOME/.zshrc"; (( $+functions[mst] && ! $+functions[$2] && ! $+functions[$1] ))' -- "$tool" "$peer" || fail 'uninstall-all registration'
printf 'PASS package %s: selective/all install, assets, ownership, versions, languages and uninstall.\n' "$tool"
