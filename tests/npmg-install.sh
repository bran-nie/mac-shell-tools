#!/bin/sh
# Install dependencies are validated before writes, without a real Node/npm.
set -eu
project_dir=$1
. "$project_dir/tests/common.sh"
test_directory=$(mktemp -d "${TMPDIR:-/tmp}/mac-shell-tools-npmg-install-test.XXXXXX")
test_directory=$(CDPATH= cd -P "$test_directory" && pwd)
trap 'rm -rf "$test_directory"' 0
trap 'exit 1' HUP INT TERM
test_home="$test_directory/home"
install_directory="$test_home/.config/zsh/mac-shell-tools"
checks=0
mkdir -p "$test_home" "$test_directory/base" "$test_directory/node-only" "$test_directory/npm-only"
for dependency in uname zsh mkdir mktemp cat awk sed cmp cp mv date rm rmdir chmod dirname tar; do
  ln -s "$(command -v "$dependency")" "$test_directory/base/$dependency"
done
mock_node_npm "$test_directory/both"
cp "$test_directory/both/node" "$test_directory/node-only/node"
cp "$test_directory/both/npm" "$test_directory/npm-only/npm"
test_path="$test_directory/base"
installer="$project_dir/install.sh"
fail() {
  printf 'FAIL npmg install: %s\n' "$*" >&2
  cat "$test_directory/out" "$test_directory/err" >&2
  exit 1
}
run() {
  expected=$1; shift
  if env HOME="$test_home" XDG_CONFIG_HOME= ZDOTDIR= MST_LANG= RUNZSH=no PATH="$test_path" \
      /bin/sh "$installer" "$@" > "$test_directory/out" 2> "$test_directory/err"; then actual=0; else actual=$?; fi
  [ "$actual" -eq "$expected" ] || fail "$*: expected $expected, got $actual"
  checks=$((checks + 1))
}
assert_no_install() {
  [ ! -e "$test_home/.config" ] && [ ! -e "$test_home/.zshrc" ] || fail 'missing dependency caused writes'
}
run 1 install npmg
grep -Fq 'npmg requires command node' "$test_directory/err" || fail 'missing Node diagnostic'
assert_no_install
run 1 install dsize npmg
assert_no_install
run 1 install --all
assert_no_install
test_path="$test_directory/node-only:$test_directory/base"
run 1 install npmg
grep -Fq 'npmg requires command npm' "$test_directory/err" || fail 'missing npm diagnostic'
assert_no_install
test_path="$test_directory/npm-only:$test_directory/base"
run 1 --lang zh-CN install npmg
grep -Fq 'npmg 需要当前 PATH 中的命令 node' "$test_directory/err" || fail 'Chinese dependency diagnostic'
assert_no_install

# Synchronize scripts even when the additional runtime is unavailable.
test_path="$test_directory/base"
run 0
[ -f "$install_directory/repository/tools/npmg/dependencies.list" ] || fail 'dependency declaration not synchronized'
[ ! -e "$install_directory/tools/npmg" ] || fail 'bootstrap enabled npmg'
installer="$install_directory/manager/mst.sh"
run 0 list
run 1 install npmg
[ ! -e "$install_directory/tools/installed.list" ] || fail 'failed install registered tools'
test_path="$test_directory/both:$test_directory/base"
run 0 install npmg
for asset in npmg.zsh dependencies.list i18n.sh locales/en.sh locales/zh-CN.sh version files.list; do
  [ -f "$install_directory/tools/npmg/$asset" ] || fail "missing installed $asset"
done
grep -Fxq dependencies.list "$install_directory/tools/npmg/files.list" || fail 'dependency ownership missing'

# Config uses the pinned install root, survives uninstall, and works without npm.
custom_prefix="$test_directory/shared space"
test_path="$test_directory/base"
if env HOME="$test_home" XDG_CONFIG_HOME="$test_directory/changed-config" MST_LANG= PATH="$test_path" \
    /bin/zsh -f -c 'source "$HOME/.zshrc"; npmg config prefix "$1"; npmg config show' -- "$custom_prefix" \
    > "$test_directory/out" 2> "$test_directory/err"; then :; else fail 'configuration without Node'; fi
[ "$(cat "$install_directory/npmg.conf")" = "prefix=$custom_prefix" ] || fail "configuration not pinned: expected prefix=$custom_prefix, actual $(cat "$install_directory/npmg.conf")"
grep -Fq "$install_directory/npmg.conf" "$test_directory/out" || fail 'configuration location missing'
mkdir -p "$custom_prefix/lib/node_modules/fixture"
printf 'keep packages\n' > "$custom_prefix/lib/node_modules/fixture/owned-by-npm"
run 0 list

# Declarations remain data and unsafe/linked declarations block installation.
declaration="$install_directory/repository/tools/npmg/dependencies.list"
cp "$declaration" "$test_directory/dependencies"
printf 'node\nnpm\nnode\n' > "$declaration"
run 1 install npmg
grep -Fq 'Invalid command dependency declaration' "$test_directory/err" || fail 'duplicate declaration accepted'
printf 'touch %s/executed\n' "$test_directory" > "$declaration"
run 1 install npmg
[ ! -e "$test_directory/executed" ] || fail 'declaration executed'
rm "$declaration"
ln -s "$test_directory/dependencies" "$declaration"
run 1 install npmg
[ -L "$declaration" ] || fail 'linked declaration overwritten'
rm "$declaration"
cp "$test_directory/dependencies" "$declaration"

run 0 uninstall npmg
[ ! -e "$install_directory/tools/npmg/npmg.zsh" ] || fail 'wrapper retained'
[ -f "$install_directory/npmg.conf" ] || fail 'prefix setting deleted on uninstall'
[ -f "$custom_prefix/lib/node_modules/fixture/owned-by-npm" ] || fail 'npm packages deleted on uninstall'
printf 'PASS npmg install: %s dependency, declaration, configuration and ownership checks.\n' "$checks"
