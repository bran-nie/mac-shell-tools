#!/bin/sh
# Previous public layout, compatibility launcher, interruption, and ownership.
set -eu
project_dir=$1
. "$project_dir/tests/common.sh"
test_directory=$(mktemp -d "${TMPDIR:-/tmp}/mac-shell-tools-migration-test.XXXXXX")
trap 'chmod -R u+rwX "$test_directory"; rm -rf "$test_directory"' 0
trap 'exit 1' HUP INT TERM
checks=0
mkdir -p "$test_directory/mock"
: > "$test_directory/out"
: > "$test_directory/err"
mock_release_curl "$test_directory/mock"
chmod +x "$test_directory/mock/curl"

fail() {
  printf 'FAIL migration: %s\n' "$*" >&2
  cat "$test_directory/out" "$test_directory/err" >&2
  exit 1
}

# Minimal v1 runtime fixture: old paths, plain manifest, frozen function location,
# and the download/exec contract of the previously published manager.
new_legacy() {
  test_home="$test_directory/$1/home"
  config_home="$test_home/.config"
  zdot_home=$test_home
  case $1 in custom) config_home="$test_directory/config 空格' "; zdot_home="$test_directory/zdot 空格' " ;; esac
  legacy_directory="$config_home/zsh/tools"
  install_directory="$config_home/zsh/mac-shell-tools"
  zshrc="$zdot_home/.zshrc"
  mkdir -p "$legacy_directory/.mac-shell-tools" "$zdot_home"
  printf 'dsize() { print -r -- legacy-dsize; }\n' > "$legacy_directory/dsize.zsh"
  printf 'other() { print -r -- legacy-other; }\n' > "$legacy_directory/other.zsh"
  printf '%s\n' dsize.zsh other.zsh > "$legacy_directory/.mac-shell-tools-installed"
  printf '# unregistered personal tool\n' > "$legacy_directory/personal.zsh"
  printf 'export LEGACY_PERSONAL=kept\n' > "$legacy_directory/personal-settings.zsh"
  printf '# original backup\n' > "$legacy_directory/init.zsh.bak.original"
  cat > "$legacy_directory/.mac-shell-tools/mst.zsh" <<'ZSH'
mst() {
  emulate -L zsh
  local legacy_manager_directory=${${(%):-%x}:A:h}
  command /bin/sh "$legacy_manager_directory/mst.sh" "$@"
}
ZSH
  cat > "$legacy_directory/.mac-shell-tools/manager-core.sh" <<'CORE'
legacy_main() {
  legacy_root=$1; legacy_rc=$2; shift 2
  release_stage=$(mktemp -d "${TMPDIR:-/tmp}/legacy-mst.XXXXXX")
  curl -fsSL -o "$release_stage/release.sh" https://raw.githubusercontent.com/bran-nie/mac-shell-tools/main/install.sh || exit 1
  /bin/sh -n "$release_stage/release.sh" || exit 1
  awk '$0 == "# mac-shell-tools bootstrap v1" {ok=1} END {exit !ok}' "$release_stage/release.sh" || exit 1
  code=$(cat "$release_stage/release.sh")
  rm -rf "$release_stage"
  MAC_SHELL_TOOLS_TARGET_DIRECTORY="$legacy_root" MAC_SHELL_TOOLS_TARGET_ZSHRC="$legacy_rc" \
    RUNZSH=no exec /bin/sh -c "$code" -- "$@"
}
CORE
  quote_core=$(/bin/zsh -f -c 'print -r -- ${(qq)1}' -- "$legacy_directory/.mac-shell-tools/manager-core.sh")
  quote_root=$(/bin/zsh -f -c 'print -r -- ${(qq)1}' -- "$legacy_directory")
  quote_rc=$(/bin/zsh -f -c 'print -r -- ${(qq)1}' -- "$zshrc")
  printf '#!/bin/sh\nset -eu\n. %s\nlegacy_main %s %s "$@"\n' "$quote_core" "$quote_root" "$quote_rc" \
    > "$legacy_directory/.mac-shell-tools/mst.sh"
  cat > "$legacy_directory/init.zsh" <<'INIT'
# personal prefix
# >>> mac-shell-tools managed tools >>>
() {
  emulate -L zsh
  local mac_shell_tools_directory=${${(%):-%x}:A:h}
  source "$mac_shell_tools_directory/.mac-shell-tools/mst.zsh"
  if [[ -f "$mac_shell_tools_directory/dsize.zsh" ]]; then
    source "$mac_shell_tools_directory/dsize.zsh"
  fi
  if [[ -f "$mac_shell_tools_directory/other.zsh" ]]; then
    source "$mac_shell_tools_directory/other.zsh"
  fi
}
# <<< mac-shell-tools managed tools <<<
# personal suffix; relative references must stay valid at the old location
source "${${(%):-%x}:A:h}/personal-settings.zsh"
INIT
  quote_init=$(/bin/zsh -f -c 'print -r -- ${(qq)1}' -- "$legacy_directory/init.zsh")
  printf '# personal rc\n# >>> mac-shell-tools >>>\nsource %s\n# <<< mac-shell-tools <<<\n' "$quote_init" > "$zshrc"
}

run_legacy() {
  expected=$1; shift
  if env HOME="$test_home" XDG_CONFIG_HOME="$test_directory/unexpected-config" ZDOTDIR="$test_directory/unexpected-zdot" \
      MST_LANG= RUNZSH=no PATH="$test_directory/mock:/usr/bin:/bin:/usr/sbin:/sbin" \
      MST_RELEASE="$project_dir/install.sh" /bin/zsh -f -c '
        source "$1"; shift
        mst "$@" || exit $?
        # This function was loaded before migration and still has its old path.
        mst list
      ' -- "$zshrc" "$@" > "$test_directory/out" 2> "$test_directory/err"; then actual=0; else actual=$?; fi
  [ "$actual" -eq "$expected" ] || fail "$*: expected $expected, got $actual"
  checks=$((checks + 1))
}

run_bootstrap() {
  expected=$1; shift
  if env HOME="$test_home" XDG_CONFIG_HOME="$config_home" ZDOTDIR="$zdot_home" MST_LANG= RUNZSH=no \
      PATH="$test_directory/mock:/usr/bin:/bin:/usr/sbin:/sbin" \
      /bin/sh "$project_dir/install.sh" "$@" > "$test_directory/out" 2> "$test_directory/err"; then actual=0; else actual=$?; fi
  [ "$actual" -eq "$expected" ] || fail "$*: expected $expected, got $actual"
  checks=$((checks + 1))
}

assert_migrated() {
  [ -f "$install_directory/manager/migration-complete" ] || fail 'migration completion missing'
  cmp -s "$legacy_directory/dsize.zsh" "$install_directory/tools/dsize/dsize.zsh" || fail 'legacy tool content changed'
  cmp -s "$legacy_directory/other.zsh" "$install_directory/tools/other/other.zsh" || fail 'unavailable tool lost'
  [ "$(awk -F '\t' '$1 == "dsize.zsh" {print $2}' "$install_directory/tools/installed.list")" = unknown ] || fail 'legacy tool given false version'
  [ "$(cat "$install_directory/tools/dsize/version")" = "$(printf 'unknown\nunknown\nunknown')" ] || fail 'legacy component version'
  [ -f "$legacy_directory/personal.zsh" ] && [ -f "$legacy_directory/init.zsh.bak.original" ] || fail 'personal files/backups lost'
  [ ! -e "$test_directory/unexpected-config" ] && [ ! -e "$test_directory/unexpected-zdot" ] || fail 'pinned paths ignored'
  if grep -Fq 'source "$mac_shell_tools_directory/dsize.zsh"' "$legacy_directory/init.zsh"; then fail 'legacy block not retired'; fi
  env HOME="$test_home" MST_LANG= /bin/zsh -f -c '
    source "$1"
    [[ $LEGACY_PERSONAL == kept && $(dsize) == legacy-dsize && $(other) == legacy-other ]]
    mst list >/dev/null
  ' -- "$zshrc" || fail 'personal relative content or functions unusable'
  set -- "$install_directory"/backups/legacy/init.zsh.bak.*
  [ -f "$1" ] || fail 'legacy entry backup missing'
  [ ! -d "$install_directory/.mac-shell-tools-install.lock" ] && \
    [ ! -d "$legacy_directory/.mac-shell-tools-install.lock" ] || fail 'migration lock remained'
  checks=$((checks + 1))
}

new_legacy normal
run_legacy 0 upgrade --no-run-zsh
grep -Eq '^dsize[[:space:]]+installed[[:space:]]+unknown' "$test_directory/out" || fail 'old loaded mst did not forward'
assert_migrated
run_bootstrap 0 update dsize
tool_matches "$project_dir" dsize "$install_directory/tools/dsize/dsize.zsh" || fail 'migrated tool update failed'
run_bootstrap 0 uninstall other
[ ! -e "$install_directory/tools/other/other.zsh" ] && [ -f "$legacy_directory/other.zsh" ] || fail 'uninstalled wrong copy'
cp -R "$install_directory/tools" "$test_directory/retained-tools"
run_bootstrap 0 upgrade
diff -r "$install_directory/tools" "$test_directory/retained-tools" > "$test_directory/diff" || fail 'repeat upgrade changed tools'

new_legacy custom
run_legacy 0 upgrade --no-run-zsh
assert_migrated
[ ! -e "$test_home/.zshrc" ] || fail 'custom migration wrote default rc'

cat > "$test_directory/mock/mv" <<'MOCK'
#!/bin/sh
for destination do :; done
case $destination in */tools/dsize/version) printf 'simulated migration interruption\n' >&2; exit 1 ;; esac
exec /bin/mv "$@"
MOCK
chmod +x "$test_directory/mock/mv"
new_legacy interrupted-copy
run_legacy 1 upgrade --no-run-zsh
[ -f "$install_directory/manager/legacy-root" ] || fail 'no recovery journal'
[ ! -d "$legacy_directory/.mac-shell-tools-install.lock" ] && \
  [ ! -d "$install_directory/.mac-shell-tools-install.lock" ] || fail 'lock remained'
rm "$test_directory/mock/mv"
run_bootstrap 0 upgrade
assert_migrated

cat > "$test_directory/mock/mv" <<'MOCK'
#!/bin/sh
for destination do :; done
case $destination in */migration-complete) printf 'simulated completion failure\n' >&2; exit 1 ;; esac
exec /bin/mv "$@"
MOCK
chmod +x "$test_directory/mock/mv"
new_legacy interrupted-final
run_legacy 1 upgrade --no-run-zsh
[ ! -f "$install_directory/manager/migration-complete" ] || fail 'failure marked complete'
rm "$test_directory/mock/mv"
run_bootstrap 0 upgrade
assert_migrated

new_legacy conflict
mkdir -p "$install_directory/tools/dsize"
printf '# independent new file\n' > "$install_directory/tools/dsize/dsize.zsh"
run_legacy 1 upgrade --no-run-zsh
[ "$(cat "$install_directory/tools/dsize/dsize.zsh")" = '# independent new file' ] || fail 'conflicting file overwritten'
[ ! -f "$install_directory/manager/manager-core.sh" ] || fail 'conflict wrote manager first'
new_legacy legacy-linked-manager
mv "$legacy_directory/.mac-shell-tools" "$legacy_directory/linked-manager"
ln -s "$legacy_directory/linked-manager" "$legacy_directory/.mac-shell-tools"
run_legacy 1 upgrade --no-run-zsh
[ -L "$legacy_directory/.mac-shell-tools" ] && [ ! -e "$install_directory" ] || fail 'linked legacy manager altered'
new_legacy legacy-lock
mkdir "$legacy_directory/.mac-shell-tools-install.lock"
run_legacy 1 upgrade --no-run-zsh
[ -d "$legacy_directory/.mac-shell-tools-install.lock" ] || fail 'foreign legacy lock removed'
[ ! -d "$install_directory/.mac-shell-tools-install.lock" ] || fail 'own new lock remained'
new_legacy legacy-missing
rm "$legacy_directory/dsize.zsh"
run_legacy 1 upgrade --no-run-zsh
[ ! -f "$install_directory/manager/manager-core.sh" ] || fail 'missing legacy tool wrote manager first'
new_legacy legacy-manifest
printf 'touch %s/executed\n' "$test_home" > "$legacy_directory/.mac-shell-tools-installed"
run_legacy 1 upgrade --no-run-zsh
[ ! -e "$test_home/executed" ] && [ ! -e "$install_directory" ] || fail 'legacy manifest caused writes'
printf 'PASS migration: %s migration, recovery, and compatibility checks.\n' "$checks"
