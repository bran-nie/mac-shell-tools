#!/bin/zsh
# Actual catalog assembly smoke: every function registers without backend work.
emulate -R zsh
setopt errexit nounset
project=$1
mkdir -p "$HOME/bin"
for backend in du lsof tar unzip node npm curl; do
  print -r -- '#!/bin/sh' 'printf "unexpected backend\n" >> "$HOME/backend-log"' 'exit 99' > "$HOME/bin/$backend"
  chmod +x "$HOME/bin/$backend"
done
export PATH="$HOME/bin:$PATH"
before_pwd=$PWD
before_options=$(setopt)
before_node=$(command -v node)
before_npm=$(command -v npm)
source "$project/tools/init.zsh" > "$HOME/source-out" 2> "$HOME/source-err"
[[ ! -s "$HOME/source-out" && ! -s "$HOME/source-err" && ! -e "$HOME/backend-log" ]] || { print -ru2 'FAIL loading: output or backend invocation'; exit 1; }
[[ $PWD == "$before_pwd" && $(setopt) == "$before_options" ]] || exit 1
[[ $(command -v node) == "$before_node" && $(command -v npm) == "$before_npm" ]] || exit 1
(( ! $+functions[compdef] )) || exit 1
typeset -a names=( ${(f)"$(<"$project/scripts/tools.list")"} )
for file in $names; do
  name=${file%.zsh}
  (( $+functions[$name] && $+functions[_$name] )) || { print -ru2 "FAIL loading: missing $name"; exit 1; }
done
# Existing completion is reused, preserving unrelated user registrations.
autoload -Uz compinit
compinit
compdef _files personal-command
compinit() { print -ru2 'FAIL loading: completion initialized twice'; return 1; }
source "$project/tools/init.zsh"
for file in $names; do
  name=${file%.zsh}
  [[ ${_comps[$name]-} == _$name ]] || exit 1
done
[[ ${_comps[personal-command]-} == _files && ! -e "$HOME/backend-log" ]] || exit 1
# Exercise the source loader's automatic compinit branch in a bare interactive
# shell too. The real Tab suites separately test ZLE on a pseudo-terminal.
zsh -f -i -c '
  (( ! $+functions[compdef] )) || exit 1
  source "$1/tools/init.zsh"
  (( $+functions[compdef] )) || exit 1
  compdef _files personal-command
  compinit() { print -ru2 "unexpected compinit"; return 1; }
  source "$1/tools/init.zsh"
  [[ ${_comps[personal-command]-} == _files ]] || exit 1
  for file in ${(f)"$(<"$1/scripts/tools.list")"}; do
    name=${file%.zsh}
    [[ ${_comps[$name]-} == _$name ]] || exit 1
  done
' -- "$project" > "$HOME/interactive-out" 2> "$HOME/interactive-err"
[[ ! -s "$HOME/interactive-out" && ! -s "$HOME/interactive-err" && ! -e "$HOME/backend-log" ]] || { cat "$HOME/interactive-out" "$HOME/interactive-err" >&2; exit 1; }
print -r -- "PASS loading: $#names real components, registration, shared completion and isolation."
