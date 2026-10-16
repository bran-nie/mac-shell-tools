#!/bin/sh
# Personal settings survive tool replacement/removal and use the pinned root.
set -eu
project_dir=$1
test_directory=$(mktemp -d "${TMPDIR:-/tmp}/mst-aliases-install.XXXXXX")
trap 'rm -rf "$test_directory"' 0
trap 'exit 1' HUP INT TERM
export HOME="$test_directory/home" XDG_CONFIG_HOME= ZDOTDIR= MST_LANG= RUNZSH=no
mkdir -p "$HOME"
install_directory="$HOME/.config/zsh/mac-shell-tools"
fail() { printf 'FAIL aliases install: %s\n' "$*" >&2; exit 1; }
personal_file="$HOME/personal.zsh"
printf '%s\n' "alias personal_alias='print personal'" > "$personal_file"
sh "$project_dir/install.sh" install aliases
env XDG_CONFIG_HOME="$test_directory/changed-config" zsh -f -c '
  source "$HOME/.zshrc"
  aliases config file "$1" || exit 1
  aliases reload || exit 1
  [[ $aliases[personal_alias] == "print personal" ]] || exit 1
  aliases config show
' -- "$personal_file" > "$test_directory/output"
[ "$(cat "$install_directory/aliases.conf")" = "file=$personal_file" ] || fail 'config root was not pinned'
grep -Fq "$install_directory/aliases.conf" "$test_directory/output" || fail 'config path not shown'
sh "$project_dir/install.sh" install aliases
zsh -f -c 'source "$HOME/.zshrc"; [[ $aliases[personal_alias] == "print personal" ]]' || fail 'reinstall lost configuration'
sh "$install_directory/manager/mst.sh" uninstall aliases
[ -f "$install_directory/aliases.conf" ] && [ -f "$personal_file" ] || fail 'uninstall removed personal data'
zsh -f -c 'source "$HOME/.zshrc"; (( ! $+functions[aliases] && ! $+aliases[personal_alias] ))' || fail 'uninstalled configuration still loaded'
sh "$install_directory/manager/mst.sh" install aliases
zsh -f -c 'source "$HOME/.zshrc"; [[ $aliases[personal_alias] == "print personal" ]]' || fail 'offline reinstall failed'
printf 'PASS aliases install: pinned settings, personal data, replacement, uninstall and offline reinstall.\n'
