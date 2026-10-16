#!/bin/zsh
# No real dotfiles: aliases and functions are exercised in this isolated shell.
emulate -R zsh
setopt nounset pipefail
project_directory=$1
test_directory=$(mktemp -d "${TMPDIR:-/tmp}/mst-aliases-test.XXXXXX") || exit 1
test_directory=${test_directory:a}
trap 'rm -rf "$test_directory"' EXIT
trap 'exit 1' HUP INT TERM
export HOME="$test_directory/home" XDG_CONFIG_HOME="$test_directory/config" MST_LANG=''
mkdir -p "$HOME"
checks=0
fail() { print -ru2 -- "FAIL aliases: $*"; exit 1; }
expect_status() {
  local expected=$1 label=$2 actual
  shift 2
  "$@" > "$test_directory/out" 2> "$test_directory/err"
  actual=$?
  [[ $actual == $expected ]] || fail "$label: expected $expected, got $actual; $(<"$test_directory/err")"
  (( checks++ ))
  return 0
}
before_options=$(setopt)
before_directory=$PWD
before_umask=$(umask)
before_path=$PATH
alias ll='ls from-user'
function duls { print -r -- user-function; }
expect_status 0 quiet-source source "$project_directory/tools/aliases/aliases.zsh"
[[ ! -s "$test_directory/out" && ! -s "$test_directory/err" ]] || fail 'source printed output'
[[ $aliases[ll] == 'ls from-user' && ! ${+aliases[duls]} -eq 1 ]] || fail 'default replaced user alias/function'
[[ $(duls) == user-function ]] || fail 'user function replaced'
expect_status 0 skipped-default aliases show ll
[[ $(<"$test_directory/out") == *'State: skipped'* ]] || fail 'missing conflict state'
config_file="$XDG_CONFIG_HOME/zsh/mac-shell-tools/aliases.conf"
[[ ! -e $config_file ]] || fail 'source created configuration'
PATH=/nonexistent expect_status 0 help aliases --help
[[ $(<"$test_directory/out") == *'Usage: aliases'* ]] || fail 'help'
PATH=/nonexistent expect_status 0 version aliases --version
[[ $(<"$test_directory/out") == 'aliases development (unbuilt; unknown)' ]] || fail 'version'
PATH=/nonexistent expect_status 0 config-without-backends aliases config show
expect_status 0 bare-help aliases
expect_status 2 unknown-command aliases unknown
expect_status 2 extra-arguments aliases list extra
expect_status 2 unknown-name aliases show unknown
expect_status 2 missing-name aliases show
expect_status 2 config-usage aliases config
expect_status 2 config-extra aliases config show extra
unalias ll
unfunction duls
expect_status 0 defaults aliases reload
[[ $aliases[ll] == 'ls -alh' && $aliases[duls] == 'du -h -d 1 -c' ]] || fail 'builtins'
expect_status 0 repeated-source source "$project_directory/tools/aliases/aliases.zsh"
expect_status 0 builtin-origin aliases show ll
[[ $(<"$test_directory/out") == *'Source: builtin'* && $(<"$test_directory/out") == *'State: active'* ]] || fail 'ownership lost after source'

personal_file="$test_directory/personal space 中文.zsh"
alias existing_alias='print original'
function existing_function { print -r -- original; }
original_function=$functions[existing_function]
cat > "$personal_file" <<'PERSONAL'
typeset -g alias_test_loads=$(( ${alias_test_loads:-0} + 1 ))
alias ll='ls -al'
alias added_alias='print added'
alias existing_alias='print replacement'
alias empty_alias=''
alias delayed_alias='printf "%s\n" "$HOME" "$(printf deferred)"'
function existing_function { print -r -- replacement; }
function added_function { print -r -- "$1"; }
PERSONAL
expect_status 0 save-file aliases config file "$personal_file"
[[ $(<"$config_file") == "file=$personal_file" && ${alias_test_loads:-0} == 0 ]] || fail 'saving executed personal file'
expect_status 0 configured-file aliases config file
[[ $(<"$test_directory/out") == "$personal_file" ]] || fail 'saved path'
expect_status 0 reload-personal aliases reload
[[ ${alias_test_loads:-0} == 1 && $aliases[ll] == 'ls -al' && $aliases[added_alias] == 'print added' ]] || fail 'personal activation'
[[ $(added_function 'argument with spaces') == 'argument with spaces' && $(existing_function) == replacement ]] || fail 'functions'
[[ $aliases[delayed_alias] == 'printf "%s\n" "$HOME" "$(printf deferred)"' ]] || fail 'alias expanded on load'
[[ ${+aliases[empty_alias]} == 1 && -z $aliases[empty_alias] ]] || fail 'empty alias lost'
expect_status 0 list-personal aliases list
[[ $(<"$test_directory/out") == *personal* && $(<"$test_directory/out") == *'ls -al'* ]] || fail 'list'
expect_status 0 show-function aliases show added_function
[[ $(<"$test_directory/out") == *'Type: function'* && $(<"$test_directory/out") == *'Source: personal'* ]] || fail 'function source'
expect_status 0 read-only-config aliases config show
[[ ${alias_test_loads:-0} == 1 && $(<"$test_directory/out") == *"Loaded personal file: $personal_file"* ]] || fail 'inspection sourced personal file'
expect_status 0 repeat-personal-source source "$project_directory/tools/aliases/aliases.zsh"
[[ ${alias_test_loads:-0} == 2 ]] || fail 'file not sourced exactly once'

# Deletions restore overwritten definitions and remove definitions created here.
print -r -- "alias ll='ls -l'" > "$personal_file"
expect_status 0 changed-and-deleted aliases reload
[[ $aliases[ll] == 'ls -l' && $aliases[existing_alias] == 'print original' && $functions[existing_function] == "$original_function" ]] || fail 'previous definitions not restored'
(( ! ${+aliases[added_alias]} && ! ${+functions[added_function]} && ! ${+aliases[empty_alias]} )) || fail 'deleted definitions retained'
expect_status 2 deleted-name aliases show added_alias

# A personal function has priority over an otherwise applicable builtin alias.
print -r -- 'function ll { print -r -- personal-function; }' > "$personal_file"
expect_status 0 function-before-default aliases reload
(( ! ${+aliases[ll]} )) || fail 'default shadows personal function'
[[ $(ll) == personal-function ]] || fail 'function invocation'
print -r -- "alias ll='ls personal'" > "$personal_file"
expect_status 0 alias-after-function aliases reload
(( ! ${+functions[ll]} )) || fail 'removed personal function retained'

# A failed load restores both live definitions and ownership for the next retry.
cat > "$personal_file" <<'PERSONAL'
alias ll='ls broken'
alias transient='print broken'
function existing_function { print broken; }
return 19
PERSONAL
expect_status 1 failed-source aliases reload
[[ $aliases[ll] == 'ls personal' && $functions[existing_function] == "$original_function" ]] || fail 'failed source changed previous definitions'
(( ! ${+aliases[transient]} )) || fail 'failed source leaked alias'
[[ $(<"$test_directory/err") == *'exit 19'* ]] || fail 'failed source diagnostic'
expect_status 1 failed-load-visible aliases list
expect_status 0 failed-load-config aliases config show
[[ $(<"$test_directory/out") == *'Last load exit code: 1'* ]] || fail 'last load status hidden'
print -r -- 'function invalid {' > "$personal_file"
expect_status 2 invalid-syntax aliases reload
[[ $aliases[ll] == 'ls personal' ]] || fail 'syntax error changed aliases'
expect_status 0 quiet-invalid-source source "$project_directory/tools/aliases/aliases.zsh"
[[ ! -s "$test_directory/out" && ! -s "$test_directory/err" ]] || fail 'invalid startup noisy'
cat > "$personal_file" <<'PERSONAL'
alias ll='ls recovered'
function manual_function_case { print -r -- configured; }
PERSONAL
expect_status 0 recovery aliases reload
[[ $aliases[ll] == 'ls recovered' ]] || fail 'recovery'

# Hand edits, deletions, and alias-to-function changes survive every reload.
alias ll='ls manually-edited'
function manual_function_case { print -r -- hand-edited; }
expect_status 0 manual-edit aliases reload
[[ $aliases[ll] == 'ls manually-edited' ]] || fail 'manual alias overwritten'
[[ $(manual_function_case) == hand-edited ]] || fail 'manual function overwritten'
expect_status 0 manual-state aliases show ll
[[ $(<"$test_directory/out") == *'State: overridden'* ]] || fail 'manual state'
expect_status 0 repeat-manual-edit aliases reload
[[ $aliases[ll] == 'ls manually-edited' ]] || fail 'manual alias overwritten on second reload'
[[ $(manual_function_case) == hand-edited ]] || fail 'manual function overwritten on second reload'
unalias ll
function ll { print -r -- manual-function; }
expect_status 0 manual-type-change aliases reload
(( ! ${+aliases[ll]} )) || fail 'manual function shadowed'
[[ $(ll) == manual-function ]] || fail 'manual function overwritten'
unalias duls
expect_status 0 manual-delete aliases reload
(( ! ${+aliases[duls]} )) || fail 'manual deletion undone'
expect_status 0 fresh-shell env /bin/zsh -f -c 'source "$1/tools/aliases/aliases.zsh"; print -r -- "$aliases[ll]"; print -r -- "$aliases[duls]"' -- "$project_directory"
[[ $(<"$test_directory/out") == $'ls recovered\ndu -h -d 1 -c' ]] || fail 'manual overrides persisted across sessions'

# Dotfiles links work, while the saved pointer remains non-executable data.
ln -s "$personal_file" "$test_directory/linked personal.zsh"
expect_status 0 personal-symlink aliases config file "$test_directory/linked personal.zsh"
expect_status 0 linked-personal-load aliases reload
for invalid in '' $'bad\npath' $'bad\rpath' "$test_directory/missing" "$test_directory"; do
  expect_status 2 invalid-personal-path aliases config file "$invalid"
done
cp "$personal_file" "$HOME/relative file.zsh"
expect_status 0 tilde-path aliases config file '~/relative file.zsh'
[[ $(<"$config_file") == "file=$HOME/relative file.zsh" ]] || fail 'tilde expansion'
cd "$test_directory" || fail 'temporary directory'
expect_status 0 relative-path aliases config file "./${personal_file:t}"
cd "$before_directory" || fail 'restore directory'
relative_setting=$(<"$config_file")
# Zsh may use /private/var while logical PWD uses /var on macOS. The saved
# absolute path must identify the same file regardless of that spelling.
[[ $relative_setting == file=/* && ${relative_setting#file=} -ef $personal_file ]] || fail 'relative path did not identify the same file'
saved_config=$(<"$config_file")
mkdir "$test_directory/write-failure"
print -rl -- '#!/bin/sh' 'exit 1' > "$test_directory/write-failure/mv"
chmod +x "$test_directory/write-failure/mv"
PATH="$test_directory/write-failure:$PATH" expect_status 1 failed-write aliases config file "$HOME/relative file.zsh"
[[ $(<"$config_file") == "$saved_config" ]] || fail 'failed write changed saved path'
[[ -z $(print -rl -- "${config_file:h}"/.aliases.conf.*(N)) ]] || fail 'temporary file leaked'
print -rl -- "file=$personal_file" "touch $test_directory/unexpected" > "$config_file"
expect_status 2 data-only-config aliases reload
[[ ! -e "$test_directory/unexpected" ]] || fail 'config executed as code'
expect_status 0 reset-malformed aliases config file --reset
[[ ! -e $config_file && -f $personal_file ]] || fail 'reset removed personal file'
print -r -- "$saved_config" > "$test_directory/config-target"
ln -s "$test_directory/config-target" "$config_file"
expect_status 2 linked-config-read aliases config show
expect_status 2 linked-config-write aliases config file "$personal_file"
expect_status 2 linked-config-reset aliases config file --reset
[[ -L $config_file ]] || fail 'saved config link replaced'
rm "$config_file"
expect_status 0 reset-reload aliases reload
[[ $(ll) == manual-function ]] || fail 'reset removed manual definition'
[[ $(manual_function_case) == hand-edited ]] || fail 'reset removed manual function'
MST_LANG=zh-CN expect_status 0 chinese-help aliases --help
[[ $(<"$test_directory/out") == *'用法：aliases'* ]] || fail 'Chinese help'
MST_LANG=zh-CN expect_status 0 chinese-list aliases list
[[ $(<"$test_directory/out") == *'来源'* ]] || fail 'Chinese list'
[[ $PWD == "$before_directory" && $(setopt) == "$before_options" && $(umask) == "$before_umask" && $PATH == "$before_path" ]] || fail 'caller state changed'
print -r -- "PASS aliases: $checks loading, ownership, recovery, configuration and language checks."
