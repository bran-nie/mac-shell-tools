# dsize 的帮助、参数校验和补全与扫描分离。
# 本文件只定义函数；加载和按 Tab 不读取目标目录内容。

# 统一说明默认值、数字边界及统计口径。
# 帮助直接返回成功，方便在尚未安装统计依赖时查看。
# Message lookup is isolated so source/calls do not change the caller's variables.
_mac_shell_tools_dsize_language() (
  emulate -L zsh
  local component_directory=${${(%):-%x}:A:h}
  local common="$component_directory/i18n.sh"
  if [[ ! -f $common ]]; then common="$component_directory/../../lib/i18n.sh"; fi
  source "$common" || return 1
  mst_resolve_language "$component_directory/../../config.conf" "${MST_LANG:-}"
)

_mac_shell_tools_dsize_message() (
  emulate -L zsh
  local component_directory=${${(%):-%x}:A:h}
  local common="$component_directory/i18n.sh"
  if [[ ! -f $common ]]; then common="$component_directory/../../lib/i18n.sh"; fi
  source "$common" || return 1
  source "$component_directory/locales/en.sh" || return 1
  unfunction mst_text_zh_CN 2>/dev/null || true
  if [[ ${dsize_language:-en} == zh-CN && -f "$component_directory/locales/zh-CN.sh" ]]; then
    source "$component_directory/locales/zh-CN.sh" || return 1
  fi
  case $1 in error.*) printf 'dsize: ' ;; esac
  mst_print_message "${dsize_language:-en}" "$@"
)

_mac_shell_tools_dsize_help() {
  _mac_shell_tools_dsize_message help
}

# Values are embedded when building the package, so --version describes the
# function actually loaded in this session even if its on-disk file was updated.
_mac_shell_tools_dsize_version() {
  local version='@MST_VERSION@' revision='@MST_REVISION@' source_state='@MST_STATE@'
  case $version in @*) version=development; revision=unbuilt; source_state=unknown ;; esac
  print -r -- "dsize $version ($revision; $source_state)"
}

# 先按字符验证，再去掉前导零和限制长度，最后才进入算术比较。
# 通过动态局部变量 REPLY 返回规范十进制值，不影响调用者全局变量。
_mac_shell_tools_dsize_integer() {
  emulate -L zsh
  setopt extendedglob
  local value=$1 minimum=$2 maximum=$3 label
  label=$(_mac_shell_tools_dsize_message "label.$4")
  if [[ -z $value || $value == *[^0-9]* ]]; then
    _mac_shell_tools_dsize_message error.integer "$label" "$minimum" "$maximum" >&2
    return 2
  fi
  value=${value##0#}
  value=${value:-0}
  if (( ${#value} > ${#maximum} )); then
    _mac_shell_tools_dsize_message error.range "$label" "$minimum" "$maximum" >&2
    return 2
  fi
  if (( value < minimum || value > maximum )); then
    _mac_shell_tools_dsize_message error.range "$label" "$minimum" "$maximum" >&2
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
  local dsize_language
  dsize_language=$(_mac_shell_tools_dsize_language) || return 2

  while (( $# )); do
    case $1 in
      -V|--version)
        _mac_shell_tools_dsize_version
        return 0
        ;;
      -h|--help)
        _mac_shell_tools_dsize_help
        return 0
        ;;
      -d|--depth|-n|--lines)
        if (( $# < 2 )); then
          _mac_shell_tools_dsize_message error.value "$1" >&2
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
          _mac_shell_tools_dsize_message error.directory_count >&2
          return 2
        fi
        if (( $# == 1 )); then
          directory=$1
          has_directory=1
          shift
        fi
        ;;
      -*)
        _mac_shell_tools_dsize_message error.option "$1" >&2
        return 2
        ;;
      *)
        if (( has_directory )); then
          _mac_shell_tools_dsize_message error.directory_count >&2
          return 2
        fi
        directory=$1
        has_directory=1
        shift
        ;;
    esac
  done

  _mac_shell_tools_dsize_integer "$depth" 0 1000 depth || return 2
  depth=$REPLY
  _mac_shell_tools_dsize_integer "$lines" 1 1000000 lines || return 2
  lines=$REPLY

  if [[ ! -e $directory ]]; then
    _mac_shell_tools_dsize_message error.missing "$directory" >&2
    return 2
  fi
  if [[ ! -d $directory ]]; then
    _mac_shell_tools_dsize_message error.directory "$directory" >&2
    return 2
  fi
  for dependency in du sort tail; do
    if ! command -v "$dependency" >/dev/null 2>&1; then
      _mac_shell_tools_dsize_message error.dependency "$dependency" >&2
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
    _mac_shell_tools_dsize_message error.interrupted >&2
    return 1
  fi
  if (( stage_status[1] )); then
    _mac_shell_tools_dsize_message error.partial >&2
  fi
  if (( stage_status[2] || stage_status[3] )); then
    _mac_shell_tools_dsize_message error.pipeline >&2
  fi
  if (( stage_status[1] || stage_status[2] || stage_status[3] )); then
    return 1
  fi
  return 0
}

# 重复选项可继续补全；数值建议与实际允许范围分离。
# -S 保留 -- 的语义，--name= 同时支持等号和独立数值参数。
_dsize() {
  setopt localoptions
  local dsize_language depth_description lines_description help_description version_description
  local depth_label lines_label directory_label
  dsize_language=$(_mac_shell_tools_dsize_language) || return 2
  depth_description=$(_mac_shell_tools_dsize_message completion.depth)
  lines_description=$(_mac_shell_tools_dsize_message completion.lines)
  help_description=$(_mac_shell_tools_dsize_message completion.help)
  version_description=$(_mac_shell_tools_dsize_message completion.version)
  depth_label=$(_mac_shell_tools_dsize_message label.depth)
  lines_label=$(_mac_shell_tools_dsize_message label.lines)
  directory_label=$(_mac_shell_tools_dsize_message completion.directory)
  _arguments -S \
    "*-d[$depth_description]:$depth_label:(0 1 2 3 4 5)" \
    "*--depth=[$depth_description]:$depth_label:(0 1 2 3 4 5)" \
    "*-n[$lines_description]:$lines_label:(10 25 50 100)" \
    "*--lines=[$lines_description]:$lines_label:(10 25 50 100)" \
    "(-h --help)-h[$help_description]" \
    "(-h --help)--help[$help_description]" \
    "(-V --version)-V[$version_description]" \
    "(-V --version)--version[$version_description]" \
    "1:$directory_label:_directories"
}

# Oh My Zsh 通常已初始化补全；裸 Zsh 仍可直接调用命令。
# 不在加载时执行 compinit，以免重复初始化用户补全配置。
if (( $+functions[compdef] )); then
  compdef _dsize dsize
fi
