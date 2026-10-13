#!/bin/zsh
# Isolated npm contract: exact argv, streams, configuration and shell state.
emulate -R zsh
setopt nounset pipefail
project_directory=$1
test_directory=$(mktemp -d "${TMPDIR:-/tmp}/mac-shell-tools-npmg-test.XXXXXX") || exit 1
test_directory=${test_directory:a}
trap 'rm -rf "$test_directory"' EXIT
trap 'exit 1' HUP INT TERM
checks=0
fail() { print -ru2 -- "FAIL npmg: $*"; exit 1; }
expect_status() {
  local expected=$1 label=$2 actual
  shift 2
  "$@" > "$test_directory/out" 2> "$test_directory/err"
  actual=$?
  [[ $actual == $expected ]] || fail "$label: expected $expected, got $actual; $(<"$test_directory/err")"
  (( checks++ ))
  return 0
}
expect_argv() {
  local argument index
  local -a actual expected
  expected=( "$@" )
  while IFS= read -r -d '' argument; do actual+=( "$argument" ); done < "$MST_NPMG_ARGS"
  (( ${#actual} == ${#expected} )) || fail 'argument boundaries changed'
  for index in {1..${#expected}}; do
    [[ $actual[$index] == $expected[$index] ]] || fail "argument $index: ${(qq)actual[$index]}"
  done
}

mkdir -p "$test_directory/mock" "$test_directory/node-only" "$test_directory/npm-only"
export XDG_CONFIG_HOME="$test_directory/config"
export MST_NPMG_ARGS="$test_directory/args" MST_NPMG_MODE=ok
cat > "$test_directory/mock/node" <<'MOCK'
#!/bin/sh
exit 0
MOCK
cat > "$test_directory/mock/npm" <<'MOCK'
#!/bin/sh
printf '%s\0' "$@" > "$MST_NPMG_ARGS"
printf 'npm stdout\n'
printf 'npm stderr\n' >&2
case $MST_NPMG_MODE in
  failure) exit 37 ;;
  stdin) IFS= read -r input; printf '%s\n' "$input" ;;
esac
MOCK
chmod +x "$test_directory/mock/node" "$test_directory/mock/npm"
cp "$test_directory/mock/node" "$test_directory/node-only/node"
cp "$test_directory/mock/npm" "$test_directory/npm-only/npm"
original_path=$PATH
before_options=$(setopt)
before_directory=$PWD
before_umask=$(umask)
source "$project_directory/tools/npmg/npmg.zsh" > "$test_directory/out" 2> "$test_directory/err"
[[ ! -s "$test_directory/out" && ! -s "$test_directory/err" ]] || fail 'noisy source'
default_prefix="$HOME/.local/npm"
config_file="$XDG_CONFIG_HOME/zsh/mac-shell-tools/npmg.conf"
loaded_path=$PATH
source "$project_directory/tools/npmg/npmg.zsh"
[[ $PATH == $loaded_path && $path[-1] == "$default_prefix/bin" ]] || fail 'PATH was duplicated or prepended'
[[ ! -e "$config_file" ]] || fail 'source created configuration'

PATH=/nonexistent expect_status 0 help-without-node npmg
[[ $(<"$test_directory/out") == *'Usage: npmg'* ]] || fail 'bare help'
PATH=/nonexistent expect_status 0 version-without-node npmg --version
[[ $(<"$test_directory/out") == 'npmg development (unbuilt; unknown)' ]] || fail 'source version'
PATH=/nonexistent expect_status 0 config-without-node npmg config show
[[ $(<"$test_directory/out") == *'Source: default'* ]] || fail 'default configuration'
PATH="$test_directory/npm-only" expect_status 1 missing-node npmg live-server
[[ $(<"$test_directory/err") == *'node'* && ! -e "$MST_NPMG_ARGS" ]] || fail 'npm ran without Node'
PATH="$test_directory/node-only" expect_status 1 missing-npm npmg live-server
[[ $(<"$test_directory/err") == *'npm'* ]] || fail 'missing npm diagnostic'
node() { return 0; }
PATH="$test_directory/npm-only" expect_status 1 node-function-is-not-runtime npmg live-server
unfunction node
PATH="$test_directory/mock:$loaded_path"

expect_status 0 shortcut npmg live-server@latest --registry=https://example.invalid --verbose
expect_argv install -g --prefix "$default_prefix" live-server@latest --registry=https://example.invalid --verbose
[[ $(<"$test_directory/out") == 'npm stdout' && $(<"$test_directory/err") == 'npm stderr' ]] || fail 'npm streams changed'
expect_status 0 multiple-packages npmg i playwright @larksuite/cli
expect_argv install -g --prefix "$default_prefix" playwright @larksuite/cli
for action in update up; do
  expect_status 0 update-all npmg "$action"
  expect_argv update -g --prefix "$default_prefix"
done
for action in uninstall rm; do
  expect_status 0 uninstall npmg "$action" live-server --verbose
  expect_argv uninstall -g --prefix "$default_prefix" live-server --verbose
done
expect_status 0 list-default npmg list
expect_argv ls -g --prefix "$default_prefix" --depth=0
expect_status 0 explicit-overrides npmg ls --depth=2 --prefix "$test_directory/other prefix" --global=false --json
expect_argv ls -g --prefix "$default_prefix" --depth=0 --depth=2 --prefix "$test_directory/other prefix" --global=false --json
expect_status 0 npm-help npmg install --help
expect_argv install -g --prefix "$default_prefix" --help
expect_status 0 npm-version npmg ls --version
expect_argv ls -g --prefix "$default_prefix" --depth=0 --version
expect_status 0 reserved-package-name npmg -- config
expect_argv install -g --prefix "$default_prefix" -- config
literal_spec='literal $(touch unexpected) `touch unexpected`'
expect_status 0 literal-boundaries npmg install "$literal_spec" $'line\nbreak' '' -- --help
expect_argv install -g --prefix "$default_prefix" "$literal_spec" $'line\nbreak' '' -- --help
[[ ! -e unexpected ]] || fail 'arguments executed as shell code'
MST_NPMG_MODE=failure expect_status 37 npm-status npmg up live-server
print -r -- 'stdin survives' > "$test_directory/input"
MST_NPMG_MODE=stdin expect_status 0 npm-stdin npmg install package < "$test_directory/input"
[[ $(<"$test_directory/out") == $'npm stdout\nstdin survives' ]] || fail 'stdin changed'

custom_prefix="$test_directory/shared space/中文"
expect_status 0 save-prefix npmg config prefix "$custom_prefix"
[[ $(<"$config_file") == "prefix=$custom_prefix" && $path[-1] == "$custom_prefix/bin" ]] || fail "saved prefix/PATH: last=${(qq)path[-1]} expected=${(qq)custom_prefix}"
(( ! ${path[(Ie)$default_prefix/bin]} )) || fail 'old managed PATH remained'
expect_status 0 read-prefix npmg config prefix
[[ $(<"$test_directory/out") == "$custom_prefix" ]] || fail 'effective prefix'
expect_status 0 saved-config npmg config show
[[ $(<"$test_directory/out") == *'Source: saved'* && $(<"$test_directory/out") == *"Config: $config_file"* ]] || fail 'configuration source/location'
expect_status 0 saved-install npmg live-server
expect_argv install -g --prefix "$custom_prefix" live-server
expect_status 0 temporary-prefix npmg install live-server --prefix "$test_directory/temporary"
expect_argv install -g --prefix "$custom_prefix" live-server --prefix "$test_directory/temporary"
[[ $(<"$config_file") == "prefix=$custom_prefix" && $path[-1] == "$custom_prefix/bin" ]] || fail 'temporary override persisted'
expect_status 0 fresh-shell env MST_LANG= /bin/zsh -f -c 'source "$1/tools/npmg/npmg.zsh"; npmg config prefix; print -r -- "$path[-1]"' -- "$project_directory"
[[ $(<"$test_directory/out") == "$custom_prefix"$'\n'"$custom_prefix/bin" ]] || fail 'fresh shell ignored saved prefix'
expect_status 0 relative-prefix npmg config prefix './npm relative'
[[ $(<"$config_file") == "prefix=$PWD/npm relative" ]] || fail 'relative prefix not normalized'
expect_status 0 quoted-tilde npmg config prefix '~/npm custom'
expected_tilde_prefix="$HOME/npm custom"
expected_tilde_prefix=${expected_tilde_prefix:a}
[[ $(<"$config_file") == "prefix=$expected_tilde_prefix" ]] || fail 'quoted tilde not expanded'
for invalid in '' 'bad:path' $'bad\npath' $'bad\rpath'; do
  expect_status 2 invalid-prefix npmg config prefix "$invalid"
done
expect_status 2 invalid-config-command npmg config show extra
expect_status 2 missing-config-command npmg config

# A failed replacement preserves both persisted settings and the live PATH.
mkdir "$test_directory/write-failure"
print -rl -- '#!/bin/sh' 'exit 1' > "$test_directory/write-failure/mv"
chmod +x "$test_directory/write-failure/mv"
before_config=$(<"$config_file")
before_write_path=$PATH
PATH="$test_directory/write-failure:$PATH" expect_status 1 failed-config-write npmg config prefix "$custom_prefix"
[[ $(<"$config_file") == "$before_config" && $PATH == $before_write_path ]] || fail 'failed write changed configuration/PATH'
[[ -z $(print -rl -- "${config_file:h}"/.npmg.conf.*(N)) ]] || fail 'temporary configuration leaked'

# Config input is data; malformed files cannot execute instructions.
cp "$config_file" "$test_directory/saved-config"
print -rl -- 'prefix=/tmp/one' "touch $test_directory/executed" > "$config_file"
expect_status 2 invalid-config npmg live-server
[[ ! -e "$test_directory/executed" ]] || fail 'configuration executed'
expect_status 0 quiet-invalid-source source "$project_directory/tools/npmg/npmg.zsh"
[[ ! -s "$test_directory/out" && ! -s "$test_directory/err" ]] || fail 'invalid configuration made startup noisy'
expect_status 0 reset-invalid-config npmg config prefix --reset
[[ ! -e "$config_file" && $path[-1] == "$default_prefix/bin" ]] || fail 'reset failed'
cp "$test_directory/saved-config" "$test_directory/config-target"
ln -s "$test_directory/config-target" "$config_file"
expect_status 2 linked-config npmg config show
expect_status 2 linked-write npmg config prefix "$custom_prefix"
expect_status 2 linked-reset npmg config prefix --reset
[[ -L "$config_file" ]] || fail 'configuration symlink modified'
rm "$config_file"

# npmg removes only PATH entries it added, preserving a preexisting user entry.
user_prefix="$test_directory/user-owned"
path+=( "$user_prefix/bin" )
expect_status 0 existing-path npmg config prefix "$user_prefix"
expect_status 0 reset-prefix npmg config prefix --reset
(( ${path[(Ie)$user_prefix/bin]} )) || fail 'user-owned PATH removed'
MST_LANG=zh-CN expect_status 0 Chinese-help npmg --help
[[ $(<"$test_directory/out") == *'用法：npmg'* ]] || fail 'Chinese help'
MST_LANG=zh-CN expect_status 0 Chinese-config npmg config show
[[ $(<"$test_directory/out") == *'配置文件'* ]] || fail 'Chinese configuration'
[[ $PWD == $before_directory && $(setopt) == $before_options && $(umask) == $before_umask ]] || fail 'caller shell state changed'
PATH=$original_path
print -r -- "PASS npmg: $checks npm, configuration, PATH, dependency and isolation checks."
