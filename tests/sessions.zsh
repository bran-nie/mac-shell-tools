#!/bin/zsh
# 通过真实伪终端验证新登录 Zsh、参数禁用和非交互入口。
emulate -R zsh
setopt nounset
if [[ ${MST_TEST_DEBUG:-no} == yes ]]; then setopt xtrace; fi
project_directory=$1
test_directory=$(mktemp -d "${TMPDIR:-/tmp}/mac-shell-tools-session-test.XXXXXX") || exit 1
zmodload zsh/zpty || exit 1
zmodload zsh/zselect || exit 1
checks=0
session_started=0
run_zsh_value=yes
# zpty 为 builtin；先建立 export 属性，再用调用作用域传递各用例的值。
export RUNZSH=yes ZDOTDIR= XDG_CONFIG_HOME=
export MST_INSTALLER="$project_directory/install.sh"
export MST_EXEC_LOG="$test_directory/exec-log"
export MST_REDIRECT_LOG="$test_directory/redirect-log"
export SHELL_SESSIONS_DISABLE=1
mkdir "$test_directory/mock"
# 在线命令只读本地构建的发布包，避免终端测试访问网络。
fixture="$test_directory/release"
mkdir -p "$fixture/scripts" "$fixture/tools" "$fixture/lib"
cp "$project_directory/scripts/build-installer.sh" "$project_directory/scripts/installer.sh.in" \
  "$project_directory/scripts/bootstrap.sh.in" "$project_directory/scripts/tools.list" "$fixture/scripts/"
cp "$project_directory/tools/"*.zsh "$fixture/tools/"
cp "$project_directory/lib/mst.zsh" "$fixture/lib/"
cp "$project_directory/LICENSE" "$fixture/"
printf '\n# terminal release two\n' >> "$fixture/tools/dsize.zsh"
printf '\n# terminal manager release two\n' >> "$fixture/lib/mst.zsh"
sh "$fixture/scripts/build-installer.sh" > "$test_directory/build-log" || exit 1
export MST_RELEASE="$fixture/install.sh"
cat > "$test_directory/mock/curl" <<'MOCK'
#!/bin/sh
set -eu
output=
while [ "$#" -gt 0 ]; do
  case $1 in -o) output=$2; shift 2 ;; *) shift ;; esac
done
[ -n "$output" ] || exit 90
cp "$MST_RELEASE" "$output"
MOCK
cat > "$test_directory/mock/zsh" <<'MOCK'
#!/bin/sh
case ${1:-} in
  -l)
    if [ -d "$HOME/.config/zsh/tools/.mac-shell-tools-install.lock" ]; then
      printf 'lock still held\n' >&2
      exit 1
    fi
    for directory in "$TMPDIR"/mac-shell-tools-install.* "$TMPDIR"/mac-shell-tools-bootstrap.* "$TMPDIR"/mac-shell-tools-download.*; do
      if [ -d "$directory" ]; then printf 'stage still present\n' >&2; exit 1; fi
    done
    printf 'login\n' >> "$MST_EXEC_LOG"
    ;;
esac
exec /bin/zsh "$@"
MOCK
chmod +x "$test_directory/mock/zsh" "$test_directory/mock/curl"

cleanup() {
  if (( session_started )); then zpty -d mst-session 2>/dev/null; fi
  zselect -t 5
  rm -rf "$test_directory"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

fail() {
  print -ru2 -- "FAIL sessions: $*: ${(V)terminal_output}"
  exit 1
}

new_home() {
  test_home="$test_directory/$1/home"
  mkdir -p "$test_home" "$test_home/tmp"
  # precmd 在完整 .zshrc 加载后报告函数状态。
  cat > "$test_home/.zshrc" <<'RC'
emulate -R zsh
PS1='__MST_PROMPT__ '
RPROMPT=''
unsetopt beep promptcr promptsp
unset HISTFILE
SAVEHIST=0
precmd() { print -r -- "__MST_SHELL__${+functions[dsize]}__MST_MANAGER__${+functions[mst]}__"; }
RC
}

start_command() {
  # 外层进程在命令结束后保持伪终端打开，便于读取完整输出再统一关闭。
  local holder='"$@"; result=$?; printf "\n__MST_EXIT__%s__\n" "$result"; while IFS= read -r reply; do :; done'
  local -a arguments=( /bin/sh -c "$holder" -- "$@" )
  terminal_output=
  HOME="$test_home" ZDOTDIR="$test_home" XDG_CONFIG_HOME= TMPDIR="$test_home/tmp" \
    RUNZSH="$run_zsh_value" TERM=xterm-256color \
    PATH="$test_directory/mock:/usr/bin:/bin:/usr/sbin:/sbin" \
    zpty -b mst-session exec "${(@q)arguments}"
  session_started=1
}

drain_output() {
  local chunk
  while zpty -r mst-session chunk 2>/dev/null; do terminal_output+=$chunk; done
}

read_until() {
  local marker=$1 attempt
  for attempt in {1..200}; do
    drain_output
    if [[ $terminal_output == *"$marker"* ]]; then return 0; fi
    if ! zpty -t mst-session; then fail "伪终端提前退出，等待 $marker"; fi
    zselect -t 5
  done
  fail "等待 $marker 超时"
}

close_session() {
  zpty -d mst-session 2>/dev/null
  session_started=0
  zselect -t 5
  return 0
}

expect_login() {
  local expected_function=$1
  read_until "__MST_SHELL__${expected_function}__"
  read_until '__MST_MANAGER__1__'
  read_until __MST_PROMPT__
  [[ -f "$MST_EXEC_LOG" ]] || fail '未调用新的登录 Zsh'
  (( checks++ ))
}

expect_exit_without_login() {
  local previous=$1 expected_exit=${2:-0}
  read_until "__MST_EXIT__${expected_exit}__"
  [[ $(login_count) == "$previous" ]] || fail '不应启动新的 Zsh'
  (( checks++ ))
  close_session
}

login_count() {
  if [[ -f "$MST_EXEC_LOG" ]]; then
    local -a log_lines=( "${(@f)$(<"$MST_EXEC_LOG")}" )
    print -r -- "$#log_lines"
  else
    print -r -- 0
  fi
}

# 首次只启用 mst；之后在线安装、更新和升级都进入固定配置的新会话。
new_home manager-first
start_command /bin/sh "$MST_INSTALLER"
expect_login 0
[[ ! -e "$test_home/.config/zsh/tools/dsize.zsh" ]] || fail '首次安装启用了工具'
zpty -w mst-session 'mst list; print -r -- __MST_LIST_""OK__'
read_until __MST_LIST_OK__
[[ $terminal_output == *'not installed'* ]] || fail '首次会话无法查询工具'
close_session
online_command='source "$HOME/.zshrc"; export ZDOTDIR="$HOME/unused-zdot"; cd /; mst "$@"'
start_command /bin/zsh -f -c "$online_command" -- install dsize
expect_login 1
[[ ! -e "$test_home/unused-zdot" ]] || fail '在线安装使用了变化后的 ZDOTDIR'
close_session
printf '\n# outdated installed tool\n' >> "$test_home/.config/zsh/tools/dsize.zsh"
start_command /bin/zsh -f -c "$online_command" -- update
expect_login 1
close_session
printf '\n# terminal manager release three\n' >> "$fixture/lib/mst.zsh"
sh "$fixture/scripts/build-installer.sh" > "$test_directory/build-log" || fail '无法构建升级包'
start_command /bin/zsh -f -c "$online_command" -- upgrade
expect_login 1
close_session
previous=$(login_count)
start_command /bin/zsh -f -c "$online_command" -- upgrade
expect_exit_without_login "$previous"

new_home automatic
start_command /bin/sh "$MST_INSTALLER" install dsize
expect_login 1
zpty -w mst-session 'dsize --help; print -r -- __MST_COMMAND_""OK__'
read_until __MST_COMMAND_OK__
[[ $terminal_output == *'--depth'* ]] || fail '新会话中 dsize 不可用'
close_session

# 相同内容、查询、帮助及失败均不得开启额外会话。
for arguments in 'install dsize' list --help 'install missing'; do
  previous=$(login_count)
  start_command /bin/sh "$MST_INSTALLER" ${=arguments}
  expected_exit=0
  if [[ $arguments == 'install missing' ]]; then expected_exit=2; fi
  expect_exit_without_login "$previous" "$expected_exit"
done
printf '\n# stale revision\n' >> "$test_home/.config/zsh/tools/dsize.zsh"
start_command /bin/sh "$MST_INSTALLER" update
expect_login 1
close_session
start_command /bin/sh "$MST_INSTALLER" uninstall dsize
expect_login 0
close_session

for flag in --no-run-zsh --unattended; do
  new_home "$flag"
  previous=$(login_count)
  start_command /bin/sh "$MST_INSTALLER" install dsize "$flag"
  expect_exit_without_login "$previous"
  [[ $terminal_output == *'source '* ]] || fail "$flag 缺少启用说明"
done
new_home environment-disabled
run_zsh_value=no
previous=$(login_count)
start_command /bin/sh "$MST_INSTALLER" install dsize
expect_exit_without_login "$previous"
run_zsh_value=yes

new_home piped-input
previous=$(login_count)
start_command /bin/sh -c 'cat "$MST_INSTALLER" | /bin/sh -s -- install dsize'
expect_exit_without_login "$previous"
[[ $terminal_output == *'source '* ]] || fail '管道安装缺少启用说明'

new_home redirected-output
previous=$(login_count)
start_command /bin/sh -c '/bin/sh "$MST_INSTALLER" install dsize > "$MST_REDIRECT_LOG"'
expect_exit_without_login "$previous"
[[ $(<"$MST_REDIRECT_LOG") == *'source '* ]] || fail '输出重定向缺少启用说明'

# 推荐的 sh -c 下载入口保持终端输入；测试用本地内容模拟下载结果。
new_home shell-c
start_command /bin/sh -c 'code=$(cat "$MST_INSTALLER") && /bin/sh -c "$code"'
expect_login 0
close_session
print -r -- "PASS sessions: $checks 项真实终端启动、禁用及清理检查。"
