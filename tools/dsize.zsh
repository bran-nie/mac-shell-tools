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
