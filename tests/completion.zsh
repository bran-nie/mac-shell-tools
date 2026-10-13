#!/bin/zsh
# 在隔离的真实交互 Zsh 中按 Tab，检查完成后的编辑缓冲区。
# 使用系统 zpty 模块，不安装额外测试运行时，也不操作用户当前终端。
emulate -R zsh
setopt nounset
project_directory=$1
test_directory=$(mktemp -d "${TMPDIR:-/tmp}/mac-shell-tools-completion-test.XXXXXX") || exit 1
checks=0
session_started=0
terminal_output=
zmodload zsh/zpty || exit 1
zmodload zsh/zselect || exit 1

# 结束测试创建的伪终端，并只删除本用例的临时目录。
cleanup() {
  if (( session_started )); then zpty -d mst-completion 2>/dev/null; fi
  rm -rf "$test_directory"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

# 失败时展示实际终端输出，便于排查补全上下文而非只看退出码。
fail() {
  print -ru2 -- "FAIL completion: $*"
  exit 1
}

# 非阻塞读取，限制等待时间，避免补全故障使 CI 一直挂起。
read_until() {
  local marker=$1 chunk attempt
  for attempt in {1..200}; do
    while zpty -r mst-completion chunk 2>/dev/null; do
      terminal_output+=$chunk
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
  zpty -w -n mst-completion $'\C-U'"$input"$'\t'
  read_until __MST_END__
  for expected in "$@"; do
    if [[ $terminal_output == *"__MST_BUFFER__${expected}__MST_END__"* ]]; then
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
# Bare Zsh must get completion from the shared loader on either platform.
source "$MST_PROJECT/tools/init.zsh"
[[ ${_comps[dsize]-} == _dsize ]] || exit 1
[[ ${_comps[portwho]-} == _portwho && ${_comps[extract]-} == _extract ]] || exit 1
[[ ${_comps[npmg]-} == _npmg ]] || exit 1
cd "$MST_TREE" || exit 1

# 记录真实补全后的命令行；不会执行 BUFFER 中的统计命令。
_mst_test_complete() {
  zle complete-word
  print -r -- "__MST_BUFFER__${BUFFER}__MST_END__"
  # Buffer completion precedes ZLE's candidate-list redraw. Deliberately exceed
  # the former 100 ms grace period so the reader must wait for actual output.
  if [[ $BUFFER == 'dsize -' ]]; then
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
export MST_PROJECT="$project_directory" MST_TREE="$test_directory/tree" MST_SCAN_LOG="$test_directory/scan-log"
# zpty 是 builtin，新增参数必须先带 export 属性才能传入其子进程。
HOME="$test_directory/home" ZDOTDIR="$test_directory/home" XDG_CONFIG_HOME= \
  TERM=xterm-256color PATH="$test_directory/mock:/usr/bin:/bin:/usr/sbin:/sbin" \
  zpty -b mst-completion /bin/zsh -d -i
session_started=1
read_until __MST_READY__
expect_completion 空格目录 'dsize sp' 'dsize space\ directory/'
expect_completion 中文目录 'dsize 中' 'dsize 中文目录/'
expect_completion 选项先于目录 'dsize -n 25 sp' 'dsize -n 25 space\ directory/'
expect_completion 帮助长选项 'dsize --he' 'dsize --help '
expect_completion 帮助短选项 'dsize -h' 'dsize -h '
expect_completion 版本长选项 'dsize --ver' 'dsize --version '
expect_completion 版本短选项 'dsize -V' 'dsize -V '
expect_completion 深度短选项 'dsize -d' 'dsize -d '
expect_completion 条数短选项 'dsize -n' 'dsize -n '
expect_completion 深度长选项 'dsize --dep' 'dsize --depth=' 'dsize --depth '
expect_completion 条数长选项 'dsize --li' 'dsize --lines=' 'dsize --lines '
expect_completion 深度短选项值 'dsize -d 5' 'dsize -d 5 '
expect_completion 条数短选项值 'dsize -n 100' 'dsize -n 100 '
expect_completion 深度等号 'dsize --depth=5' 'dsize --depth=5 '
expect_completion 条数等号 'dsize --lines=100' 'dsize --lines=100 '
expect_completion 长选项独立值 'dsize --depth 5' 'dsize --depth 5 '
expect_completion 目录先于选项 'dsize ordinary --lines=100' 'dsize ordinary --lines=100 '
expect_completion 重复短选项 'dsize -d 2 -d 5' 'dsize -d 2 -d 5 '
expect_completion 重复长选项 'dsize --depth=2 --depth=5' 'dsize --depth=2 --depth=5 '
expect_completion 分隔符目录 'dsize -- -da' 'dsize -- -dashdir/'
expect_completion 数值不当目录 'dsize -d sp' 'dsize -d sp'
expect_completion 不补全第二目录 'dsize ordinary sp' 'dsize ordinary sp'
expect_completion 端口帮助 'portwho --he' 'portwho --help '
expect_completion 端口版本 'portwho --ver' 'portwho --version '
expect_completion 端口数值 'portwho 443' 'portwho 443 '
expect_completion 多个端口 'portwho 80 443' 'portwho 80 443 '
expect_completion 端口不补全目录 'portwho sp' 'portwho sp'
expect_completion 解压帮助 'extract --he' 'extract --help '
expect_completion 解压版本 'extract --ver' 'extract --version '
expect_completion 解压预览 'extract --li' 'extract --list '
expect_completion 空格压缩包 'extract bun' 'extract bundle\ file.zip '
expect_completion 中文压缩包 'extract 归' 'extract 归档.ZIP '
expect_completion 解压目标目录 'extract -C sp' 'extract -C space\ directory/'
expect_completion 解压长目标目录 'extract --directory=sp' 'extract --directory=space\ directory/'
expect_completion 解压分隔符 'extract -- -bun' 'extract -- -bundle.tgz '
expect_completion 不补全第二压缩包 'extract sample.zip bun' 'extract sample.zip bun'
expect_completion npm安装 'npmg ins' 'npmg install '
expect_completion npm更新 'npmg upd' 'npmg update '
expect_completion npm卸载 'npmg unins' 'npmg uninstall '
expect_completion npm列表 'npmg lis' 'npmg list '
expect_completion npm配置 'npmg conf' 'npmg config '
expect_completion npm完整配置命令 'npmg config' 'npmg config '
expect_completion npm配置查看 'npmg config sh' 'npmg config show '
expect_completion npm配置目录 'npmg config pre' 'npmg config prefix '
expect_completion npm配置路径 'npmg config prefix sp' 'npmg config prefix space\ directory/'
expect_completion npm配置重置 'npmg config prefix --re' 'npmg config prefix --reset '
expect_completion npm帮助 'npmg --he' 'npmg --help '
expect_completion npm版本 'npmg --vers' 'npmg --version '
expect_completion npm安装预览 'npmg install live-server --dry' 'npmg install live-server --dry-run '
expect_completion npm目录选项 'npmg install live-server --prefix=sp' 'npmg install live-server --prefix=space\ directory/'
expect_completion npm不查询包名 'npmg install nonexistent-package-xyz' 'npmg install nonexistent-package-xyz'
expect_completion 英文选项列表 'dsize -' 'dsize -'
read_until 'Show help'
read_until 'Maximum lines, default 25'
# Change language in the running shell; the next real Tab must use it immediately.
terminal_output=
# Split the marker in the typed command so terminal echo cannot satisfy it.
zpty -w -n mst-completion $'\C-U''export MST_LANG=zh-CN; print -r -- __MST_LANGUAGE_""READY__'$'\n'
read_until __MST_LANGUAGE_READY__
expect_completion 中文选项列表 'dsize -' 'dsize -'
read_until '显示帮助'
read_until '25'
expect_completion 中文目录补全 'dsize sp' 'dsize space\ directory/'
expect_completion 中文解压选项 'extract -' 'extract -'
read_until '预览压缩包内容'
read_until '新的目标目录'
[[ ! -e "$test_directory/scan-log" ]] || fail '补全触发了工具后端命令'
print -r -- "PASS completion: $checks 项真实 Tab 补全及扫描隔离。"
