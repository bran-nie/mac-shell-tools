#!/bin/sh
# Exercise the actual tool package, using its separate local source files.
set -eu
project_dir=$1
. "$project_dir/tests/common.sh"
test_directory=$(mktemp -d "${TMPDIR:-/tmp}/mac-shell-tools-catalog-test.XXXXXX")
trap 'rm -rf "$test_directory"' 0
trap 'exit 1' HUP INT TERM
test_home="$test_directory/home"
install_directory="$test_home/.config/zsh/mac-shell-tools"
checks=0
mkdir -p "$test_home"
mock_node_npm "$test_directory/dependencies"
export PATH="$test_directory/dependencies:$PATH"
fail() {
  printf 'FAIL catalog: %s\n' "$*" >&2
  cat "$test_directory/out" "$test_directory/err" >&2
  exit 1
}
run() {
  if env HOME="$test_home" XDG_CONFIG_HOME= ZDOTDIR= MST_LANG= RUNZSH=no \
      sh "$project_dir/install.sh" "$@" > "$test_directory/out" 2> "$test_directory/err"; then :; else fail "$*"; fi
  checks=$((checks + 1))
}
shell_run() {
  if env HOME="$test_home" XDG_CONFIG_HOME= ZDOTDIR= MST_LANG= RUNZSH=no \
      zsh -f -c 'source "$HOME/.zshrc"; eval "$1"' -- "$1" \
      > "$test_directory/out" 2> "$test_directory/err"; then :; else fail "$1"; fi
  checks=$((checks + 1))
}
run
[ ! -f "$install_directory/tools/installed.list" ] || fail 'default bootstrap installed tools'
run list
for tool in dsize portwho extract npmg; do
  awk -v tool="$tool" '$1 == tool && $2 == "not" && $3 == "installed" {found=1} END {exit !found}' "$test_directory/out" || fail "catalog lacks $tool"
done
run install portwho extract
[ ! -e "$install_directory/tools/dsize" ] || fail 'selective install enabled dsize'
[ "$(wc -l < "$install_directory/tools/installed.list" | tr -d ' ')" -eq 2 ] || fail 'selective manifest'
for tool in portwho extract; do
  for resource in "$tool.zsh" version files.list i18n.sh locales/en.sh locales/zh-CN.sh; do
    [ -f "$install_directory/tools/$tool/$resource" ] || fail "missing $tool/$resource"
  done
done
shell_run '(( ! $+functions[dsize] && $+functions[portwho] && $+functions[extract] )) && portwho --help && extract --help && portwho --version && extract --version'
grep -Fq 'Usage: portwho' "$test_directory/out" || fail 'installed portwho help'
grep -Fq 'Usage: extract' "$test_directory/out" || fail 'installed extract help'
for tool in portwho extract; do
  tool_version=$(sed -n '1p' "$project_dir/tools/$tool/package.meta")
  grep -Fq "$tool $tool_version (" "$test_directory/out" || fail "$tool installed version"
done
shell_run 'mst config language zh-CN && portwho --help && extract --help'
grep -Fq '用法：portwho' "$test_directory/out" || fail 'portwho saved language'
grep -Fq '用法：extract' "$test_directory/out" || fail 'extract saved language'
shell_run 'mst config language en && portwho --help && extract --help'
run install --all
shell_run '(( $+functions[dsize] && $+functions[portwho] && $+functions[extract] && $+functions[npmg] )) && npmg --help && npmg --version'
tool_version=$(sed -n '1p' "$project_dir/tools/npmg/package.meta")
grep -Fq "npmg $tool_version (" "$test_directory/out" || fail 'npmg installed version'
[ -f "$install_directory/tools/npmg/dependencies.list" ] || fail 'npmg dependencies not packaged'
shell_run 'mst config language zh-CN && npmg --help && npmg config show'
grep -Fq '用法：npmg' "$test_directory/out" || fail 'npmg saved language'
shell_run 'mst config language en'
printf 'personal content\n' > "$install_directory/tools/portwho/personal.txt"
run uninstall portwho
[ -f "$install_directory/tools/portwho/personal.txt" ] || fail 'uninstall deleted personal file'
[ ! -e "$install_directory/tools/portwho/portwho.zsh" ] || fail 'uninstall kept managed source'
shell_run '(( ! $+functions[portwho] && $+functions[extract] && $+functions[dsize] ))'
run uninstall extract
shell_run '(( ! $+functions[portwho] && ! $+functions[extract] && $+functions[dsize] ))'
run uninstall --all
shell_run '(( $+functions[mst] && ! $+functions[dsize] && ! $+functions[portwho] && ! $+functions[extract] && ! $+functions[npmg] ))'
printf 'PASS catalog: %s actual-tool packaging, selection, language, and uninstall checks.\n' "$checks"
