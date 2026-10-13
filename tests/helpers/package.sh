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
run install --all
printf 'personal\n' > "$install_directory/tools/$tool/personal.txt"
run uninstall "$tool"
[ -f "$install_directory/tools/$tool/personal.txt" ] || fail 'personal file removed'
[ ! -e "$install_directory/tools/$tool/$tool.zsh" ] || fail 'managed source retained'
zsh -f -c 'source "$HOME/.zshrc"; (( $+functions[mst] && $+functions[$2] && ! $+functions[$1] ))' -- "$tool" "$peer" || fail 'peer or manager removed'
run uninstall --all
zsh -f -c 'source "$HOME/.zshrc"; (( $+functions[mst] && ! $+functions[$2] && ! $+functions[$1] ))' -- "$tool" "$peer" || fail 'uninstall-all registration'
printf 'PASS package %s: selective/all install, assets, ownership, versions, languages and uninstall.\n' "$tool"
