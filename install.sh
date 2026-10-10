#!/bin/sh
# mac-shell-tools 单文件安装器，由 scripts/build-installer.sh 生成。
# 工具源码只维护 tools/；本文件的内嵌内容随生成过程同步。
set -eu

stage=
pending_file=
lock_directory=
has_lock=0

# 所有错误指明受影响的位置，避免安静失败或继续写入后续配置。
fail() {
  printf 'mac-shell-tools: %s\n' "$*" >&2
  exit 1
}

# 只清理本进程创建的暂存内容和锁，不清理用户文件或备份。
cleanup() {
  if [ -n "$pending_file" ]; then rm -f "$pending_file"; fi
  if [ -n "$stage" ]; then rm -rf "$stage"; fi
  if [ "$has_lock" -eq 1 ]; then rmdir "$lock_directory"; fi
}
trap cleanup 0
trap 'fail "安装已中断；已生成的备份可用于恢复。"' HUP INT TERM

# 环境路径必须绝对，避免在调用者工作目录里悄悄创建配置。
require_absolute() {
  case $2 in
    /*) ;;
    *) fail "$1 必须是绝对路径：$2" ;;
  esac
}

# 配置文件链接不做原子替换；用户可先自行确认链接的维护方式。
# 父目录的链接允许保留并经 cd -P 定位，不改写链接本身。
check_file() {
  if [ -L "$1" ]; then
    fail "配置是符号链接，已保留，请手动处理后重试：$1"
  fi
  if [ -e "$1" ] && [ ! -f "$1" ]; then
    fail "目标不是普通文件：$1"
  fi
}

# 标记必须唯一、完整且顺序正确；相似但损坏的项目标记也拒绝。
# 结果为 managed 或 absent，由调用者决定是否接受无标记文件。
inspect_region() {
  region_state=$(awk -v begin="$2" -v end="$3" '
    $0 == begin {
      if (begins || ends || inside) invalid = 1
      begins++; inside = 1; next
    }
    $0 == end {
      if (!inside || ends) invalid = 1
      ends++; inside = 0; next
    }
    index($0, "mac-shell-tools") && (index($0, ">>>") || index($0, "<<<")) {
      invalid = 1
    }
    END {
      if (invalid || inside || begins != ends || begins > 1) exit 1
      if (begins == 1) print "managed"; else print "absent"
    }
  ' "$1") || fail "管理标记损坏或重复，请手动处理：$1"
}

# 只更新集中入口的管理区域；保留区域以外的引用、注释及顺序。
merge_init() {
  awk -v begin='# >>> mac-shell-tools managed tools >>>' \
      -v end='# <<< mac-shell-tools managed tools <<<' '
    NR == FNR {
      if ($0 == begin) collecting = 1
      if (collecting) replacement = replacement $0 "\n"
      if ($0 == end) collecting = 0
      next
    }
    $0 == begin { printf "%s", replacement; skipping = 1; next }
    $0 == end { skipping = 0; next }
    !skipping { print }
  ' "$stage/init.zsh" "$install_directory/init.zsh" > "$stage/next-init.zsh" ||
    fail "无法合并入口：$install_directory/init.zsh"
}

# 删除现有项目管理块后再追加新块，保证入口位于主配置末尾。
# 非管理区域原样保留，不猜测其他 source 引用或函数的用途。
prepare_zshrc() {
  awk -v begin='# >>> mac-shell-tools >>>' \
      -v end='# <<< mac-shell-tools <<<' '
    $0 == begin { skipping = 1; next }
    $0 == end { skipping = 0; next }
    skipping { next }
    { print }
  ' "$existing_zshrc" > "$stage/next-zshrc" || fail "无法准备主配置：$zshrc"

  quoted_init=$(zsh -f -c 'print -r -- ${(qq)1}' -- "$install_directory/init.zsh") ||
    fail "无法转义入口路径：$install_directory/init.zsh"
  {
    printf '%s\n' '# >>> mac-shell-tools >>>'
    printf 'if [[ -f %s ]]; then\n' "$quoted_init"
    printf '  source %s\n' "$quoted_init"
    printf '%s\n' 'fi' '# <<< mac-shell-tools <<<'
  } >> "$stage/next-zshrc" || fail "无法准备主配置：$zshrc"
}

# 比较完成后预检所有将变更的目标，尽早发现权限和类型问题。
# 相同内容无需写权限，也不会新增备份或改变修改时间。
preflight_write() {
  check_file "$2"
  if [ -f "$2" ] && cmp -s "$1" "$2"; then return 0; fi
  if [ -f "$2" ] && [ ! -w "$2" ]; then fail "文件不可写：$2"; fi
  target_parent=${2%/*}
  if [ ! -w "$target_parent" ] || [ ! -x "$target_parent" ]; then
    fail "目录不可写或无法进入：$target_parent"
  fi
}

# 用同目录随机暂存文件和 rename 写入；已有文件先备份并保留权限。
# 时间戳加 mktemp 后缀使连续更新也不会覆盖旧备份。
write_file() {
  prepared=$1
  target=$2
  check_file "$target"
  if [ -f "$target" ] && cmp -s "$prepared" "$target"; then return 0; fi
  if [ -f "$target" ]; then
    stamp=$(date '+%Y%m%d-%H%M%S') || fail "无法生成备份时间：$target"
    backup=$(mktemp "$target.bak.$stamp.XXXXXX") || fail "无法创建备份：$target"
    if ! cp -p "$target" "$backup"; then
      rm -f "$backup"
      fail "无法备份：$target"
    fi
    printf '已备份：%s\n' "$backup"
  fi
  pending_file=$(mktemp "${target%/*}/.mac-shell-tools.XXXXXX") ||
    fail "无法创建同目录暂存文件：$target"
  if [ -f "$target" ]; then
    cp -p "$target" "$pending_file" || fail "无法保留文件属性：$target"
  fi
  cat "$prepared" > "$pending_file" || fail "写入失败（请检查权限及剩余空间）：$target"
  check_file "$target"
  mv -f "$pending_file" "$target" || fail "无法替换文件：$target"
  pending_file=
  printf '已安装：%s\n' "$target"
}

# 先验证平台、所有暂存内容和目标，再按工具、入口、主配置顺序落盘。
# 子进程只提供启用命令，不声称改变调用者当前的 Shell。
main() {
  for dependency in uname zsh du sort tail mkdir mktemp cat awk cmp cp mv date rm rmdir; do
    command -v "$dependency" >/dev/null 2>&1 || fail "缺少基础命令：$dependency"
  done
  platform=$(uname -s) || fail '无法识别操作系统。'
  case $platform in
    Darwin) ;;
    *) fail '当前版本仅支持 macOS。' ;;
  esac
  require_absolute HOME "${HOME:-}"
  config_home=${XDG_CONFIG_HOME:-$HOME/.config}
  zdot_directory=${ZDOTDIR:-$HOME}
  require_absolute XDG_CONFIG_HOME "$config_home"
  require_absolute ZDOTDIR "$zdot_directory"
  install_directory="$config_home/zsh/tools"
  zshrc="$zdot_directory/.zshrc"

  if [ -L "$install_directory" ]; then fail "工具目录是符号链接，已保留：$install_directory"; fi
  for target in "$install_directory/init.zsh" "$zshrc"; do check_file "$target"; done
  for tool_file in $tool_files; do check_file "$install_directory/$tool_file"; done
  mkdir -p "$install_directory" "$zdot_directory" ||
    fail "无法创建配置目录：$install_directory 或 $zdot_directory"
  install_directory=$(CDPATH= cd -P "$install_directory" && pwd) || fail "无法进入工具目录：$install_directory"
  zdot_directory=$(CDPATH= cd -P "$zdot_directory" && pwd) || fail "无法进入配置目录：$zdot_directory"
  zshrc="$zdot_directory/.zshrc"
  lock_directory="$install_directory/.mac-shell-tools-install.lock"
  mkdir "$lock_directory" 2>/dev/null ||
    fail "无法取得安装锁（另一个安装可能仍在运行，请确认后手动处理）：$lock_directory"
  has_lock=1
  stage=$(mktemp -d "${TMPDIR:-/tmp}/mac-shell-tools-install.XXXXXX") || fail '无法创建安装暂存目录。'
  write_payload || fail "无法准备内嵌工具：$stage"

  if [ -f "$install_directory/init.zsh" ]; then
    inspect_region "$install_directory/init.zsh" \
      '# >>> mac-shell-tools managed tools >>>' '# <<< mac-shell-tools managed tools <<<'
    if [ "$region_state" = absent ]; then
      fail "入口来源不明，不覆盖现有文件，请手动处理：$install_directory/init.zsh"
    fi
    merge_init
  else
    cp "$stage/init.zsh" "$stage/next-init.zsh" || fail '无法准备集中入口。'
  fi
  if [ -f "$zshrc" ]; then
    inspect_region "$zshrc" '# >>> mac-shell-tools >>>' '# <<< mac-shell-tools <<<'
    existing_zshrc=$zshrc
  else
    : > "$stage/empty-zshrc"
    existing_zshrc="$stage/empty-zshrc"
  fi
  prepare_zshrc
  zsh -f -n "$stage/next-init.zsh" || fail "入口语法检查失败，未写入：$install_directory/init.zsh"
  zsh -f -n "$stage/next-zshrc" || fail "主配置语法检查失败，未写入：$zshrc"
  for tool_file in $tool_files; do
    zsh -f -n "$stage/$tool_file" || fail "工具语法检查失败：$tool_file"
    preflight_write "$stage/$tool_file" "$install_directory/$tool_file"
  done
  preflight_write "$stage/next-init.zsh" "$install_directory/init.zsh"
  preflight_write "$stage/next-zshrc" "$zshrc"

  for tool_file in $tool_files; do write_file "$stage/$tool_file" "$install_directory/$tool_file"; done
  write_file "$stage/next-init.zsh" "$install_directory/init.zsh"
  write_file "$stage/next-zshrc" "$zshrc"

  quoted_zshrc=$(zsh -f -c 'print -r -- ${(qq)1}' -- "$zshrc") || fail '无法生成启用命令。'
  printf '\n%s\n' '安装完成。请重新打开终端，或在当前 Zsh 执行：'
  printf '  source %s\n' "$quoted_zshrc"
  printf '%s\n' '随后可运行 dsize --help。补全需在 Oh My Zsh / compinit 初始化后加载。'
}

write_payload() {
  cat > "$stage/init.zsh" <<'MAC_SHELL_TOOLS_EMBEDDED_FILE_7D4C' || return 1
# mac-shell-tools 集中入口。
# 管理区域显式注册工具；其他区域由用户维护，更新时保留。

# >>> mac-shell-tools managed tools >>>
() {
  emulate -L zsh
  local mac_shell_tools_directory=${${(%):-%x}:A:h}
  if [[ -f "$mac_shell_tools_directory/dsize.zsh" ]]; then
    source "$mac_shell_tools_directory/dsize.zsh"
  fi
}
# <<< mac-shell-tools managed tools <<<

# 用户自定义区域：可在此添加其他工具引用和注释。
# 定位此入口所在目录可使用 ${${(%):-%x}:A:h}，不要依赖当前工作目录。
MAC_SHELL_TOOLS_EMBEDDED_FILE_7D4C
  cat > "$stage/dsize.zsh" <<'MAC_SHELL_TOOLS_EMBEDDED_FILE_7D4C' || return 1
# dsize 的帮助、参数校验和补全与扫描分离。
# 本文件只定义函数；加载和按 Tab 不读取目标目录内容。

# 统一说明默认值、数字边界及统计口径。
# 帮助直接返回成功，方便在尚未安装统计依赖时查看。
_mac_shell_tools_dsize_help() {
  emulate -L zsh
  cat <<'DSIZE_HELP'
用法：dsize [目录] [选项]

查看目录中占用空间最大的条目，按大小升序输出，最大条目在最后。
默认目录为 .，默认深度为 2，默认条数为 25。

  -d N, --depth N, --depth=N  显示深度，十进制整数 0–1000
  -n N, --lines N, --lines=N  最大行数，十进制整数 1–1000000
  -h, --help                 显示帮助
  --                         停止解析选项，后面至多一个目录

目录和选项可交错；同一选项重复时最后一次生效。支持前导零。
深度只限制显示层级，计算总量仍会遍历更深内容。
父目录包含子目录，不能将输出相加；这里只统计磁盘占用，不清理文件。
退出码：0 成功或帮助，2 参数错误，1 扫描不完整或依赖执行失败。
DSIZE_HELP
}

# 先按字符验证，再去掉前导零和限制长度，最后才进入算术比较。
# 通过动态局部变量 REPLY 返回规范十进制值，不影响调用者全局变量。
_mac_shell_tools_dsize_integer() {
  emulate -L zsh
  setopt extendedglob
  local value=$1 minimum=$2 maximum=$3 label=$4
  if [[ -z $value || $value == *[^0-9]* ]]; then
    print -ru2 -- "dsize: ${label}必须是十进制整数（${minimum}–${maximum}）。"
    return 2
  fi
  value=${value##0#}
  value=${value:-0}
  if (( ${#value} > ${#maximum} )); then
    print -ru2 -- "dsize: ${label}范围为 ${minimum}–${maximum}。"
    return 2
  fi
  if (( value < minimum || value > maximum )); then
    print -ru2 -- "dsize: ${label}范围为 ${minimum}–${maximum}。"
    return 2
  fi
  REPLY=$value
}

# 统计使用系统 du 的磁盘占用口径，不修改文件。
# 局部选项和信号处理确保错误、取消及重载不影响交互 Shell。
dsize() {
  emulate -L zsh
  setopt localtraps pipefail
  local directory=. depth=2 lines=25 has_directory=0 REPLY
  local dependency scan_directory interrupted=0
  local -a stage_status

  while (( $# )); do
    case $1 in
      -h|--help)
        _mac_shell_tools_dsize_help
        return 0
        ;;
      -d|--depth|-n|--lines)
        if (( $# < 2 )); then
          print -ru2 -- "dsize: $1 缺少数值。"
          return 2
        fi
        case $1 in
          -d|--depth) depth=$2 ;;
          -n|--lines) lines=$2 ;;
        esac
        shift 2
        ;;
      --depth=*) depth=${1#*=}; shift ;;
      --lines=*) lines=${1#*=}; shift ;;
      --)
        shift
        if (( $# > 1 || (has_directory && $# > 0) )); then
          print -ru2 -- 'dsize: 只允许一个目录。'
          return 2
        fi
        if (( $# == 1 )); then
          directory=$1
          has_directory=1
          shift
        fi
        ;;
      -*)
        print -ru2 -- "dsize: 未知选项 $1。"
        return 2
        ;;
      *)
        if (( has_directory )); then
          print -ru2 -- 'dsize: 只允许一个目录。'
          return 2
        fi
        directory=$1
        has_directory=1
        shift
        ;;
    esac
  done

  _mac_shell_tools_dsize_integer "$depth" 0 1000 深度 || return 2
  depth=$REPLY
  _mac_shell_tools_dsize_integer "$lines" 1 1000000 条数 || return 2
  lines=$REPLY

  if [[ ! -e $directory ]]; then
    print -ru2 -- "dsize: 路径不存在：$directory"
    return 2
  fi
  if [[ ! -d $directory ]]; then
    print -ru2 -- "dsize: 不是目录：$directory"
    return 2
  fi
  for dependency in du sort tail; do
    if ! command -v "$dependency" >/dev/null 2>&1; then
      print -ru2 -- "dsize: 缺少命令 $dependency。"
      return 1
    fi
  done

  # 使用 ./ 前缀保护连字符相对路径，不依赖 du 的额外选项。
  case $directory in
    -*) scan_directory=./$directory ;;
    *) scan_directory=$directory ;;
  esac
  trap 'interrupted=1' HUP INT TERM
  command du -h -d "$depth" "$scan_directory" 2>/dev/null |
    command sort -h |
    command tail -n "$lines"
  stage_status=( "${pipestatus[@]}" )

  if (( interrupted )); then
    print -ru2 -- 'dsize: 扫描已中断，结果可能不完整。'
    return 1
  fi
  if (( stage_status[1] )); then
    print -ru2 -- 'dsize: 不完整扫描；部分目录无法读取或 du 执行失败。'
  fi
  if (( stage_status[2] || stage_status[3] )); then
    print -ru2 -- 'dsize: 排序或截取输出失败。'
  fi
  if (( stage_status[1] || stage_status[2] || stage_status[3] )); then
    return 1
  fi
  return 0
}

# 重复选项可继续补全；数值建议与实际允许范围分离。
# -S 保留 -- 的语义，--name= 同时支持等号和独立数值参数。
_dsize() {
  # 保留补全引擎设置的 extendedglob、rcexpandparam 等前提。
  # emulate 会重置这些选项；这里只建立局部作用域防止选项外泄。
  setopt localoptions
  _arguments -S \
    '*-d[显示深度，默认 2]:深度:(0 1 2 3 4 5)' \
    '*--depth=[显示深度，默认 2]:深度:(0 1 2 3 4 5)' \
    '*-n[最大行数，默认 25]:条数:(10 25 50 100)' \
    '*--lines=[最大行数，默认 25]:条数:(10 25 50 100)' \
    '(-h --help)-h[显示帮助]' \
    '(-h --help)--help[显示帮助]' \
    '1:目录:_directories'
}

# Oh My Zsh 通常已初始化补全；裸 Zsh 仍可直接调用命令。
# 不在加载时执行 compinit，以免重复初始化用户补全配置。
if (( $+functions[compdef] )); then
  compdef _dsize dsize
fi
MAC_SHELL_TOOLS_EMBEDDED_FILE_7D4C
}

tool_files=' dsize.zsh'
main
