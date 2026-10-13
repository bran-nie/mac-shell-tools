#!/bin/zsh
# 在隔离的真实交互 Zsh 中按 Tab，检查完成后的编辑缓冲区。
# 使用系统 zpty 模块，不安装额外测试运行时，也不操作用户当前终端。
emulate -R zsh
setopt nounset
project_directory=$1
component_name=$2
case_file=$3
completion_sequence=0
terminal_transcript=
test_directory=$(mktemp -d "${TMPDIR:-/tmp}/mac-shell-tools-completion-test.XXXXXX") || exit 1
checks=0
session_started=0
terminal_output=
zmodload zsh/zpty || exit 1
zmodload zsh/zselect || exit 1

# 结束测试创建的伪终端，并只删除本用例的临时目录。
cleanup() {
  if (( session_started )); then zpty -d mst-completion 2>/dev/null; fi
  if [[ -n ${MST_TEST_ARTIFACT_DIR:-} ]]; then
    print -rn -- "$terminal_transcript" > "$MST_TEST_ARTIFACT_DIR/terminal.log"
  fi
  rm -rf "$test_directory"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

# 失败时展示实际终端输出，便于排查补全上下文而非只看退出码。
fail() {
  print -ru2 -- "FAIL completion ($component_name): $*: ${(V)terminal_output}"
  exit 1
}

# 非阻塞读取，限制等待时间，避免补全故障使 CI 一直挂起。
read_until() {
  local marker=$1 chunk attempt
  for attempt in {1..200}; do
    while zpty -r mst-completion chunk 2>/dev/null; do
      terminal_output+=$chunk
      terminal_transcript+=$chunk
    done
    if [[ $terminal_output == *"$marker"* ]]; then return 0; fi
    if ! zpty -t mst-completion; then fail "伪终端已退出：${(V)terminal_output}"; fi
    zselect -t 5
  done
  fail "等待 $marker 超时：${(V)terminal_output}"
}

# 控制字符只操作伪终端；widget 内实际调用系统 complete-word。
expect_completion() {
  local label=$1 input=$2 expected
  shift 2
  terminal_output=
  (( completion_sequence++ ))
  zpty -w -n mst-completion $'\C-U'"$input"$'\t'
  read_until "__MST_END_${completion_sequence}__"
  for expected in "$@"; do
    if [[ $terminal_output == *"__MST_BUFFER_${completion_sequence}__${expected}__MST_END_${completion_sequence}__"* ]]; then
      (( checks++ ))
      return 0
    fi
  done
  fail "$label: ${(V)terminal_output}"
}

mkdir -p "$test_directory/home" "$test_directory/tree/space directory" \
  "$test_directory/tree/中文目录" "$test_directory/tree/ordinary" \
  "$test_directory/tree/-dashdir" "$test_directory/mock"
cat > "$test_directory/mock/du" <<'MOCK'
#!/bin/sh
printf 'unexpected scan\n' >> "$MST_SCAN_LOG"
exit 1
MOCK
chmod +x "$test_directory/mock/du"
for backend in lsof tar unzip npm node; do
  cp "$test_directory/mock/du" "$test_directory/mock/$backend"
done
touch "$test_directory/tree/bundle file.zip" "$test_directory/tree/归档.ZIP" \
  "$test_directory/tree/-bundle.tgz" "$test_directory/tree/bundle-other.rar"

cat > "$test_directory/home/.zshrc" <<'RC'
emulate -R zsh
PS1='MST> '
RPROMPT=''
LISTMAX=0
COLUMNS=160
LINES=40
setopt no_beep
setopt auto_list
unsetopt list_ambiguous
zstyle ':completion:*' verbose yes
bindkey -e
autoload -Uz compinit
compinit
source "$MST_COMPONENT_SOURCE"
[[ ${_comps[$MST_COMPONENT]-} == _$MST_COMPONENT ]] || exit 1
# Completion must not execute the public command, even just its help path.
functions[$MST_COMPONENT]='print -r -- "unexpected command" >> "$MST_SCAN_LOG"; return 1'
_mst_test_sequence=0
cd "$MST_TREE" || exit 1

# 记录真实补全后的命令行；不会执行 BUFFER 中的统计命令。
_mst_test_complete() {
  zle complete-word
  (( _mst_test_sequence++ ))
  print -r -- "__MST_BUFFER_${_mst_test_sequence}__${BUFFER}__MST_END_${_mst_test_sequence}__"
  # Buffer completion precedes ZLE's candidate-list redraw. Deliberately exceed
  # the former 100 ms grace period so the reader must wait for actual output.
  if [[ $BUFFER == *' -' ]]; then
    zmodload zsh/zselect
    zselect -t 30
  fi
  zle redisplay
}
zle -N _mst_test_complete
bindkey '^I' _mst_test_complete
print -r -- __MST_READY__
RC

# 环境通过调用作用域传递，不拼接进 zpty 会再次解析的命令字符串。
# 因此含空格的路径不需要经过第二层 Shell 转义。
export MST_COMPONENT="$component_name"
case $component_name in
  mst) export MST_COMPONENT_SOURCE="$project_directory/lib/mst.zsh" ;;
  *) export MST_COMPONENT_SOURCE="$project_directory/tools/$component_name/$component_name.zsh" ;;
esac
export MST_TREE="$test_directory/tree" MST_SCAN_LOG="$test_directory/scan-log"
# zpty 是 builtin，新增参数必须先带 export 属性才能传入其子进程。
HOME="$test_directory/home" ZDOTDIR="$test_directory/home" XDG_CONFIG_HOME= \
  TERM=xterm-256color PATH="$test_directory/mock:/usr/bin:/bin:/usr/sbin:/sbin" \
  zpty -b mst-completion /bin/zsh -d -i
session_started=1
read_until __MST_READY__

set_language() {
  terminal_output=
  zpty -w -n mst-completion $'\C-U'"export MST_LANG=$1; print -r -- __MST_LANGUAGE_\"\"READY__"$'\n'
  read_until __MST_LANGUAGE_READY__
}
source "$case_file"
[[ ! -e "$test_directory/scan-log" ]] || fail '补全触发了工具后端命令'
print -r -- "PASS completion ($component_name): $checks real Tab and isolation checks."
