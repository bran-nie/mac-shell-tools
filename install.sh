#!/bin/sh
# MIT License
#
# Copyright (c) 2026 bran.nie
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# Package version: 0.1.0-dev+56a073aed4d3
# Source revision: 82ef43f85d25b9d78729e8e3da2e83b0e8cffac5
# Source state: modified
# Source digest: 56a073aed4d33951cb1ce7abf48851241e22baab4a41771192836198d0802533
# mac-shell-tools bootstrap v1
# 自包含引导脚本：先展开共享管理器，再在当前进程中执行。
set -eu

bootstrap_main() {
  bootstrap_directory=$(mktemp -d "${TMPDIR:-/tmp}/mac-shell-tools-bootstrap.XXXXXX") || exit 1
  trap 'rm -rf "$bootstrap_directory"' 0
  trap 'exit 1' HUP INT TERM
  write_manager_payload || {
    printf '%s\n' 'mst: Cannot unpack the manager.' >&2
    exit 1
  }
  /bin/sh -n "$bootstrap_directory/manager-core.sh" || exit 1
  . "$bootstrap_directory/manager-core.sh"
  # 管理器接管自身源码及引导暂存目录，启动新 Zsh 前统一清理。
  main "$bootstrap_directory/manager-core.sh" "$bootstrap_directory" '' '' "$@"
}

write_manager_payload() {
  cat > "$bootstrap_directory/manager-core.sh" <<'MAC_SHELL_TOOLS_MANAGER_7D4C' || return 1
#!/bin/sh
# MIT License
#
# Copyright (c) 2026 bran.nie
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# Shared POSIX sh language helpers. Configuration is read as data, never sourced.
mst_resolve_language() (
  settings=$1
  override=$2
  chosen=en
  if [ -n "$override" ]; then
    chosen=$override
  elif [ -e "$settings" ] || [ -L "$settings" ]; then
    if [ ! -f "$settings" ] || [ -L "$settings" ]; then
      printf 'mst: Invalid language configuration: %s\n' "$settings" >&2
      return 2
    fi
    seen=no
    while IFS= read -r line || [ -n "$line" ]; do
      case $line in
        ''|'#'*) ;;
        language=*)
          if [ "$seen" = yes ]; then printf 'mst: Duplicate language setting: %s\n' "$settings" >&2; return 2; fi
          chosen=${line#language=}; seen=yes ;;
        *) printf 'mst: Invalid language configuration: %s\n' "$settings" >&2; return 2 ;;
      esac
    done < "$settings"
  fi
  case $chosen in
    en|zh-CN) printf '%s\n' "$chosen" ;;
    *) printf 'mst: Unsupported language: %s (use en or zh-CN).\n' "$chosen" >&2; return 2 ;;
  esac
)

# Catalogs return fixed printf formats. Arguments are passed separately, without eval.
mst_print_message() (
  chosen_language=$1
  message_key=$2
  shift 2
  format=$(mst_text_en "$message_key") || {
    printf 'mst: Unknown message key: %s\n' "$message_key" >&2
    return 1
  }
  case $chosen_language in
    en) ;;
    zh-CN)
      if command -v mst_text_zh_CN >/dev/null 2>&1; then
        translated=$(mst_text_zh_CN "$message_key") && format=$translated
      fi
      ;;
  esac
  printf "$format\n" "$@"
)
# mst_text_en message catalog.
mst_text_en() {
  case $1 in
    error.help) printf '%s\n' 'Run mst --help for usage.' ;;
    error.interrupted) printf '%s\n' 'Operation interrupted. Existing backups can be used for recovery.' ;;
    error.runzsh) printf '%s\n' 'RUNZSH must be yes or no.' ;;
    error.option) printf '%s\n' 'Unknown option: %s' ;;
    error.command) printf '%s\n' 'Unknown command: %s' ;;
    error.name) printf '%s\n' 'Invalid tool name: %s' ;;
    error.all_names) printf '%s\n' '--all cannot be combined with tool names.' ;;
    error.no_names) printf '%s\n' '%s does not accept tool names or --all.' ;;
    error.uninstall_names) printf '%s\n' 'Specify tools to uninstall, or use uninstall --all.' ;;
    error.language) printf '%s\n' 'Unsupported language: %s (use en or zh-CN).' ;;
    error.language_value) printf '%s\n' '--lang requires en or zh-CN.' ;;
    error.config) printf '%s\n' 'Usage: mst config language [en|zh-CN]' ;;
    error.absolute) printf '%s\n' '%s must be an absolute path: %s' ;;
    error.symlink) printf '%s\n' 'Symbolic link preserved; refusing to manage: %s' ;;
    error.file_type) printf '%s\n' 'Target is not a regular file: %s' ;;
    error.directory_type) printf '%s\n' 'Target is not a directory: %s' ;;
    error.markers) printf '%s\n' 'Managed markers are broken or duplicated: %s' ;;
    error.unknown_entry) printf '%s\n' 'Existing entry has no recognized managed block: %s' ;;
    error.state) printf '%s\n' 'Invalid or duplicate installed-tool record: %s' ;;
    error.assets) printf '%s\n' 'Invalid owned-file manifest: %s' ;;
    error.available) printf '%s\n' 'Tool is unavailable in this package: %s' ;;
    error.not_installed) printf '%s\n' 'Tool is not installed: %s' ;;
    error.unknown_tool) printf '%s\n' 'Unknown tool: %s' ;;
    error.escape) printf '%s\n' 'Cannot quote configuration path: %s' ;;
    error.syntax) printf '%s\n' 'Shell syntax check failed: %s' ;;
    error.dependency) printf '%s\n' 'Required command is missing: %s' ;;
    error.platform) printf '%s\n' 'Supported systems: macOS and Linux.' ;;
    error.mkdir) printf '%s\n' 'Cannot create directory: %s' ;;
    error.enter) printf '%s\n' 'Cannot enter directory: %s' ;;
    error.lock) printf '%s\n' 'Cannot acquire the installation lock; check for another operation before removing it: %s' ;;
    error.stage) printf '%s\n' 'Cannot create a temporary directory.' ;;
    error.payload) printf '%s\n' 'Cannot prepare embedded files.' ;;
    error.readonly) printf '%s\n' 'File is not writable: %s' ;;
    error.parent) printf '%s\n' 'Directory is not writable or accessible: %s' ;;
    error.backup) printf '%s\n' 'Cannot create a complete backup: %s' ;;
    error.write) printf '%s\n' 'Cannot write or replace file (check permissions and free space): %s' ;;
    error.remove) printf '%s\n' 'Cannot remove file: %s' ;;
    error.download) printf '%s\n' 'Download failed; existing managed files are unchanged.' ;;
    error.empty) printf '%s\n' 'Downloaded package is empty; existing files are unchanged.' ;;
    error.download_syntax) printf '%s\n' 'Downloaded package has invalid shell syntax; existing files are unchanged.' ;;
    error.package) printf '%s\n' 'Downloaded content is not a supported mac-shell-tools package; existing files are unchanged.' ;;
    error.read_release) printf '%s\n' 'Cannot read the downloaded package.' ;;
    error.migration_conflict) printf '%s\n' 'New installation already exists with conflicting legacy state; preserved both locations: %s' ;;
    error.migration_source) printf '%s\n' 'Legacy installation is missing a registered tool: %s' ;;
    info.fetch) printf '%s\n' 'Fetching: %s' ;;
    info.backup) printf '%s\n' 'Backed up: %s' ;;
    info.write) printf '%s\n' 'Written: %s' ;;
    info.remove) printf '%s\n' 'Uninstalled: %s' ;;
    info.unchanged) printf '%s\n' 'No files need changing.' ;;
    info.complete) printf '%s\n' 'Operation complete.' ;;
    info.login) printf '%s\n' 'Starting a new login Zsh in this terminal; exiting may return to the previous session.' ;;
    info.activate) printf '%s\n' 'Start Zsh with zsh -l, or run this in your current Zsh:' ;;
    info.uninstall_activate) printf '%s\n' 'Start a fresh Zsh with exec zsh -l; loaded functions remain in existing sessions.' ;;
    info.empty) printf '%s\n' 'No tools are installed; nothing to update.' ;;
    info.no_tools) printf '%s\n' 'No tools to process. Run mst list to see their status.' ;;
    info.language) printf '%s\n' 'Language: %s' ;;
    info.migrate) printf '%s\n' 'Migrating the registered installation from %s' ;;
    info.migrated) printf '%s\n' 'Migration complete. Personal files and existing backups remain in %s' ;;
    status.not_installed) printf '%s\n' 'not installed' ;;
    status.installed) printf '%s\n' 'installed' ;;
    status.missing) printf '%s\n' 'installed (file missing)' ;;
    status.unavailable) printf '%s\n' 'unavailable in catalog' ;;
    list.header) printf '%s\n' 'TOOL                 STATUS                       INSTALLED VERSION             AVAILABLE VERSION' ;;
    help) printf '%s\n' 'Usage: mst <command> [tool ...] [options]
       sh install.sh [command] [tool ...] [options]

Commands:
  install [tool ...]       Install selected tools; no names means all.
  update [tool ...]        Update installed tools only.
  uninstall tool ...      Uninstall selected tools, with backups.
  uninstall --all         Uninstall all tools; keep mst.
  list                    Show the local catalog, status, and versions.
  upgrade                 Upgrade mst and its catalog; keep tools unchanged.
  version                 Show mst'\''s installed version and source revision.
  config language         Show the saved language (default: en).
  config language en      Save English for mst and tools.
  config language zh-CN   Save Simplified Chinese for mst and tools.

Options:
  --all                   Select all; cannot be combined with tool names.
  --lang en|zh-CN         Use this language for this command only.
  --no-run-zsh            Do not start a new Zsh session.
  --unattended            Non-interactive operation; do not start Zsh.
  -V, --version           Show mst'\''s version.
  -h, --help              Show this help.

Running install.sh without a command installs mst only.
Installed mst install/update/upgrade fetch the latest GitHub package.
RUNZSH=no also disables the new login session.
Language changes take effect on the next invocation, without a new session.' ;;
    *) return 1 ;;
  esac
}
# mst_text_zh_CN message catalog.
mst_text_zh_CN() {
  case $1 in
    error.help) printf '%s\n' '运行 mst --help 查看用法。' ;;
    error.interrupted) printf '%s\n' '操作已中断；已生成的备份可用于恢复。' ;;
    error.runzsh) printf '%s\n' 'RUNZSH 只能为 yes 或 no。' ;;
    error.option) printf '%s\n' '未知参数：%s' ;;
    error.command) printf '%s\n' '未知命令：%s' ;;
    error.name) printf '%s\n' '无效工具名：%s' ;;
    error.all_names) printf '%s\n' '--all 不能与工具名同时使用。' ;;
    error.no_names) printf '%s\n' '%s 不接受工具名或 --all。' ;;
    error.uninstall_names) printf '%s\n' '请指定卸载工具，或使用 uninstall --all。' ;;
    error.language) printf '%s\n' '不支持的语言：%s（请使用 en 或 zh-CN）。' ;;
    error.language_value) printf '%s\n' '--lang 需要 en 或 zh-CN。' ;;
    error.config) printf '%s\n' '用法：mst config language [en|zh-CN]' ;;
    error.absolute) printf '%s\n' '%s 必须是绝对路径：%s' ;;
    error.symlink) printf '%s\n' '目标为符号链接，已保留并停止变更：%s' ;;
    error.file_type) printf '%s\n' '目标不是普通文件：%s' ;;
    error.directory_type) printf '%s\n' '目标不是目录：%s' ;;
    error.markers) printf '%s\n' '管理标记损坏或重复：%s' ;;
    error.unknown_entry) printf '%s\n' '已有入口没有可识别的管理块：%s' ;;
    error.state) printf '%s\n' '安装清单记录无效或重复：%s' ;;
    error.assets) printf '%s\n' '工具文件清单无效：%s' ;;
    error.available) printf '%s\n' '当前安装包不提供工具：%s' ;;
    error.not_installed) printf '%s\n' '工具尚未安装：%s' ;;
    error.unknown_tool) printf '%s\n' '未知工具：%s' ;;
    error.escape) printf '%s\n' '无法转义配置路径：%s' ;;
    error.syntax) printf '%s\n' 'Shell 语法检查失败：%s' ;;
    error.dependency) printf '%s\n' '缺少基础命令：%s' ;;
    error.platform) printf '%s\n' '支持的系统：macOS 和 Linux。' ;;
    error.mkdir) printf '%s\n' '无法创建目录：%s' ;;
    error.enter) printf '%s\n' '无法进入目录：%s' ;;
    error.lock) printf '%s\n' '无法取得安装锁；确认没有其他操作运行后再处理：%s' ;;
    error.stage) printf '%s\n' '无法创建暂存目录。' ;;
    error.payload) printf '%s\n' '无法准备内嵌文件。' ;;
    error.readonly) printf '%s\n' '文件不可写：%s' ;;
    error.parent) printf '%s\n' '目录不可写或无法进入：%s' ;;
    error.backup) printf '%s\n' '无法创建完整备份：%s' ;;
    error.write) printf '%s\n' '无法写入或替换文件，请检查权限及剩余空间：%s' ;;
    error.remove) printf '%s\n' '无法删除文件：%s' ;;
    error.download) printf '%s\n' '下载失败；现有管理文件未变更。' ;;
    error.empty) printf '%s\n' '下载内容为空；现有文件未变更。' ;;
    error.download_syntax) printf '%s\n' '下载脚本语法错误；现有文件未变更。' ;;
    error.package) printf '%s\n' '下载内容不是支持的 mac-shell-tools 安装包；现有文件未变更。' ;;
    error.read_release) printf '%s\n' '无法读取下载的安装包。' ;;
    error.migration_conflict) printf '%s\n' '新安装与旧清单冲突，已保留两处内容：%s' ;;
    error.migration_source) printf '%s\n' '旧安装中缺少已登记工具：%s' ;;
    info.fetch) printf '%s\n' '正在获取：%s' ;;
    info.backup) printf '%s\n' '已备份：%s' ;;
    info.write) printf '%s\n' '已写入：%s' ;;
    info.remove) printf '%s\n' '已卸载：%s' ;;
    info.unchanged) printf '%s\n' '没有需要变更的文件。' ;;
    info.complete) printf '%s\n' '操作完成。' ;;
    info.login) printf '%s\n' '即将在当前终端启动新的 Zsh 登录会话；退出后可能回到原会话。' ;;
    info.activate) printf '%s\n' '请执行 zsh -l 进入 Zsh，或在当前 Zsh 执行：' ;;
    info.uninstall_activate) printf '%s\n' '请执行 exec zsh -l 启动全新的 Zsh；已有会话中的函数不会自动清除。' ;;
    info.empty) printf '%s\n' '尚未安装工具，无需更新。' ;;
    info.no_tools) printf '%s\n' '没有可处理的工具；可运行 mst list 查看状态。' ;;
    info.language) printf '%s\n' '语言：%s' ;;
    info.migrate) printf '%s\n' '正在迁移已登记安装：%s' ;;
    info.migrated) printf '%s\n' '迁移完成；个人文件与已有备份保留在 %s' ;;
    status.not_installed) printf '%s\n' '未安装' ;;
    status.installed) printf '%s\n' '已安装' ;;
    status.missing) printf '%s\n' '已安装（文件缺失）' ;;
    status.unavailable) printf '%s\n' '工具目录中已不提供' ;;
    list.header) printf '%s\n' '工具                 状态                         已安装版本                    可用版本' ;;
    help) printf '%s\n' '用法：mst <命令> [工具名 ...] [参数]
      sh install.sh [命令] [工具名 ...] [参数]

命令：
  install [工具名 ...]     安装指定工具；不指定时安装全部工具。
  update [工具名 ...]      仅更新已安装工具。
  uninstall 工具名 ...    卸载指定工具，删除前备份。
  uninstall --all         卸载全部工具，保留 mst。
  list                    查看本地可用工具、安装状态和版本。
  upgrade                 升级 mst 和可用工具目录，保留已安装工具。
  version                 查看 mst 的版本和源码修订。
  config language         查看已保存的语言，默认 en。
  config language en      为 mst 和工具保存英文设置。
  config language zh-CN   为 mst 和工具保存简体中文设置。

参数：
  --all                   选择全部工具，不能与名称混用。
  --lang en|zh-CN         仅本次命令使用指定语言。
  --no-run-zsh            不启动新的 Zsh 会话。
  --unattended            非交互操作，不启动 Zsh。
  -V, --version           查看 mst 版本。
  -h, --help              查看帮助。

不带命令运行 install.sh 时只安装 mst。
安装后的 mst install/update/upgrade 从 GitHub 获取最新安装包。
RUNZSH=no 也可关闭新的登录会话。
语言设置在下次调用时生效，无需启动新会话。' ;;
    *) return 1 ;;
  esac
}

package_version='0.1.0-dev+56a073aed4d3'
package_revision='82ef43f85d25b9d78729e8e3da2e83b0e8cffac5'
package_state='modified'
# mac-shell-tools 共享管理器；引导安装与常驻 mst 共用此实现。
# 由生成脚本打包运行时源码，管理器始终从文件加载。
set -eu

stage=
pending_file=
lock_directory=
has_lock=0
changes_made=0
owned_bootstrap_directory=
has_legacy_lock=0
legacy_lock_directory=
language=en
migration_files=
init_begin='# >>> mac-shell-tools managed tools >>>'
init_end='# <<< mac-shell-tools managed tools <<<'
rc_begin='# >>> mac-shell-tools >>>'
rc_end='# <<< mac-shell-tools <<<'

fail() {
  printf 'mst: ' >&2
  message "$@" >&2
  exit 1
}

usage_error() {
  printf 'mst: ' >&2
  message "$@" >&2
  message error.help >&2
  exit 2
}

usage() { message help; }

cleanup() {
  if [ -n "$pending_file" ]; then rm -f "$pending_file"; pending_file=; fi
  if [ -n "$stage" ]; then rm -rf "$stage"; stage=; fi
  if [ "$has_lock" -eq 1 ]; then
    rmdir "$lock_directory"
    has_lock=0
  fi
  if [ "$has_legacy_lock" -eq 1 ]; then rmdir "$legacy_lock_directory"; has_legacy_lock=0; fi
  if [ -n "$owned_bootstrap_directory" ]; then
    rm -rf "$owned_bootstrap_directory"
    owned_bootstrap_directory=
  fi
}
trap cleanup 0
trap 'fail error.interrupted' HUP INT TERM

contains_file() {
  case " $1 " in *" $2 "*) return 0 ;; *) return 1 ;; esac
}

valid_tool_name() {
  case $1 in ''|[!a-z0-9]*|*[!a-z0-9-]*) return 1 ;; *) return 0 ;; esac
}

parse_arguments() {
  action=setup
  action_seen=no
  requested_files=
  config_arguments=
  all_requested=no
  end_options=no
  language_override=
  run_zsh=${RUNZSH:-yes}
  while [ "$#" -gt 0 ]; do
    argument=$1
    shift
    if [ "$end_options" = no ]; then
      case $argument in
        --lang)
          [ "$#" -gt 0 ] || usage_error error.language_value
          language_override=$1; shift
          case $language_override in en|zh-CN) language=$language_override ;; *) usage_error error.language "$language_override" ;; esac
          continue ;;
        --lang=*)
          language_override=${argument#--lang=}
          case $language_override in en|zh-CN) language=$language_override ;; *) usage_error error.language "$language_override" ;; esac
          continue ;;
        -h|--help) action=help; action_seen=yes; continue ;;
        -V|--version) action=version; action_seen=yes; continue ;;
        --no-run-zsh|--unattended) run_zsh=no; continue ;;
        --all) all_requested=yes; continue ;;
        --) end_options=yes; continue ;;
        -*) usage_error error.option "$argument" ;;
      esac
    fi
    if [ "$action_seen" = no ]; then
      case $argument in
        install|update|uninstall|list|upgrade|version|config) action=$argument; action_seen=yes; continue ;;
        *) usage_error error.command "$argument" ;;
      esac
    fi
    case $action in
      config) config_arguments="$config_arguments $argument" ;;
      *)
        valid_tool_name "$argument" || usage_error error.name "$argument"
        if ! contains_file "$requested_files" "$argument.zsh"; then requested_files="$requested_files $argument.zsh"; fi ;;
    esac
  done
  case $run_zsh in yes|no) ;; *) usage_error error.runzsh ;; esac
  if [ "$all_requested" = yes ] && [ -n "$requested_files" ]; then usage_error error.all_names; fi
  if [ "$action_seen" = no ] && [ "$all_requested" = yes ]; then action=install; fi
  case $action in
    list|upgrade|version|help)
      if [ -n "$requested_files" ] || [ "$all_requested" = yes ]; then usage_error error.no_names "$action"; fi ;;
    uninstall)
      if [ -z "$requested_files" ] && [ "$all_requested" = no ]; then usage_error error.uninstall_names; fi ;;
    config)
      case "$config_arguments" in
        ' language') config_value= ;;
        ' language en') config_value=en ;;
        ' language zh-CN') config_value=zh-CN ;;
        *) usage_error error.config ;;
      esac
      [ "$all_requested" = no ] || usage_error error.config ;;
    setup|install|update) ;;
  esac
}

require_absolute() {
  case $2 in /*) ;; *) fail error.absolute "$1" "$2" ;; esac
}

# 父目录链接经 cd -P 定位；文件及最终工具目录的链接不做替换。
check_file() {
  if [ -L "$1" ]; then fail error.symlink "$1"; fi
  if [ -e "$1" ] && [ ! -f "$1" ]; then fail error.file_type "$1"; fi
}

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
  ' "$1") || fail error.markers "$1"
}

strip_region() {
  awk -v begin="$2" -v end="$3" '
    $0 == begin { skipping = 1; next }
    $0 == end { skipping = 0; next }
    !skipping { print }
  ' "$1"
}

read_installed() {
  installed_files=
  installed_records=
  source_state_file=$state_file
  state_kind=current
  check_file "$state_file"
  if [ ! -f "$state_file" ] && [ "$migrating" = yes ]; then
    source_state_file="$legacy_directory/.mac-shell-tools-installed"
    state_kind=legacy
    check_file "$source_state_file"
  fi
  if [ -f "$source_state_file" ]; then
    if [ "$state_kind" = current ]; then
      awk -F '\t' 'NF != 4 { exit 1 }' "$source_state_file" || fail error.state "$source_state_file"
      while IFS="$(printf '\t')" read -r record_file record_version record_revision record_dirty || [ -n "$record_file" ]; do
        validate_record "$record_file" "$record_version" "$record_revision" "$record_dirty"
      done < "$source_state_file"
    else
      while IFS= read -r record_file || [ -n "$record_file" ]; do
        validate_record "$record_file" unknown unknown unknown
      done < "$source_state_file"
    fi
  else
    inference_entry="$install_directory/init.zsh"
    inference_prefix='tools/'
    if [ "$migrating" = yes ]; then inference_entry="$legacy_directory/init.zsh"; inference_prefix=; fi
    if [ -f "$inference_entry" ]; then
      inspect_region "$inference_entry" "$init_begin" "$init_end"
      [ "$region_state" = managed ] || fail error.unknown_entry "$inference_entry"
      for inferred_file in $tool_files; do
        case $inference_prefix in
          'tools/') registration='    source "$mac_shell_tools_directory/tools/'"${inferred_file%.zsh}/$inferred_file"'"' ;;
          '') registration='    source "$mac_shell_tools_directory/'"$inferred_file"'"' ;;
        esac
        if awk -v begin="$init_begin" -v end="$init_end" -v line="$registration" '
          $0 == begin { inside = 1; next }
          $0 == end { inside = 0 }
          inside && $0 == line { found = 1 }
          END { exit !found }
        ' "$inference_entry"; then
          validate_record "$inferred_file" unknown unknown unknown
        fi
      done
    fi
  fi
}

select_files() {
  selected_files=
  next_files=$installed_files
  case $action in
    install)
      selection=$tool_files
      if [ -n "$requested_files" ]; then selection=$requested_files; fi
      for selected_file in $selection; do
        contains_file "$tool_files" "$selected_file" || usage_error error.available "${selected_file%.zsh}"
        selected_files="$selected_files $selected_file"
        if ! contains_file "$next_files" "$selected_file"; then next_files="$next_files $selected_file"; fi
      done
      ;;
    update)
      selection=$installed_files
      if [ -n "$requested_files" ]; then selection=$requested_files; fi
      for selected_file in $selection; do
        contains_file "$installed_files" "$selected_file" || usage_error error.not_installed "${selected_file%.zsh}"
        if contains_file "$tool_files" "$selected_file"; then
          selected_files="$selected_files $selected_file"
        elif [ -n "$requested_files" ]; then
          usage_error error.available "${selected_file%.zsh}"
        fi
      done
      ;;
    uninstall)
      selection=$installed_files
      if [ -n "$requested_files" ]; then selection=$requested_files; fi
      for selected_file in $selection; do
        if ! contains_file "$installed_files" "$selected_file" && ! contains_file "$tool_files" "$selected_file"; then
          usage_error error.unknown_tool "${selected_file%.zsh}"
        fi
        if contains_file "$installed_files" "$selected_file"; then selected_files="$selected_files $selected_file"; fi
      done
      next_files=
      for retained_file in $installed_files; do
        if ! contains_file "$selected_files" "$retained_file"; then next_files="$next_files $retained_file"; fi
      done
      ;;
    setup|upgrade|list) ;;
  esac
}

list_tools() {
  message list.header
  listed_files=$tool_files
  for listed_file in $installed_files; do
    if ! contains_file "$listed_files" "$listed_file"; then listed_files="$listed_files $listed_file"; fi
  done
  for listed_file in $listed_files; do
    tool_status=$(message status.not_installed)
    installed_version=-
    available_version=-
    if contains_file "$tool_files" "$listed_file"; then available_version=$package_version; fi
    if contains_file "$installed_files" "$listed_file"; then
      tool_status=$(message status.installed)
      tool_target="$tools_directory/${listed_file%.zsh}/$listed_file"
      if [ "$migrating" = yes ] && [ ! -f "$tool_target" ]; then tool_target="$legacy_directory/$listed_file"; fi
      if [ ! -f "$tool_target" ]; then tool_status=$(message status.missing); fi
      if ! contains_file "$tool_files" "$listed_file"; then tool_status="$tool_status ($(message status.unavailable))"; fi
      installed_version=$(record_for "$listed_file" | awk -F '\t' '{print $2}')
    fi
    printf '%-20s %-28s %-29s %s\n' "${listed_file%.zsh}" "$tool_status" "$installed_version" "$available_version"
  done
}

# 将下一份清单渲染为集中入口，只替换项目管理区域。
prepare_init() {
  {
    printf '%s\n' "$init_begin" 'if [ -z "${ZSH_VERSION-}" ]; then return 0; fi' '() {' '  emulate -L zsh'
    # Frameworks may already provide completion. Check the live shell instead
    # of guessing from an Oh My Zsh directory or executing the user's config.
    printf '%s\n' '  if [[ -o interactive ]] && (( ! $+functions[compdef] )); then' \
      '    autoload -Uz compinit' '    compinit' '  fi'
    printf '%s\n' '  local mac_shell_tools_directory=${${(%):-%x}:A:h}'
    printf '%s\n' '  if [[ -f "$mac_shell_tools_directory/manager/mst.zsh" ]]; then' \
      '    source "$mac_shell_tools_directory/manager/mst.zsh"' '  fi'
    for registered_file in $next_files; do
      printf '  if [[ -f "$mac_shell_tools_directory/tools/%s/%s" ]]; then\n' "${registered_file%.zsh}" "$registered_file"
      printf '    source "$mac_shell_tools_directory/tools/%s/%s"\n' "${registered_file%.zsh}" "$registered_file"
      printf '%s\n' '  fi'
    done
    printf '%s\n' '}' "$init_end"
  } > "$stage/managed-init"
  init_source="$stage/payload/init.zsh"
  if [ -f "$install_directory/init.zsh" ]; then init_source="$install_directory/init.zsh"; fi
  remove_init=no
  entry_needed=yes
  awk -v begin="$init_begin" -v end="$init_end" '
    NR == FNR { replacement = replacement $0 "\n"; next }
    $0 == begin { printf "%s", replacement; skipping = 1; next }
    $0 == end { skipping = 0; next }
    !skipping { print }
  ' "$stage/managed-init" "$init_source" > "$stage/next-init.zsh" || fail error.write "$install_directory/init.zsh"
  if [ "$migrating" = yes ] && [ ! -f "$manager_directory/migration-complete" ]; then
    quoted_legacy=$(quote_path "$legacy_directory/init.zsh")
    legacy_reference="  source $quoted_legacy"
    if ! awk -v line="$legacy_reference" '$0 == line {found=1} END {exit !found}' "$stage/next-init.zsh"; then
      printf '\n# Personal content stays at its original location after migration.\nif [[ -f %s ]]; then\n%s\nfi\n' \
        "$quoted_legacy" "$legacy_reference" >> "$stage/next-init.zsh"
    fi
  fi
}

prepare_zshrc() {
  write_zshrc=no
  existing_zshrc="$stage/empty-zshrc"
  : > "$existing_zshrc"
  rc_state=absent
  if [ -f "$zshrc" ]; then
    existing_zshrc=$zshrc
    inspect_region "$zshrc" "$rc_begin" "$rc_end"
    rc_state=$region_state
  fi
  # 管理器及个人工具仍需要入口；卸载工具不能使 mst 入口失效。
  if [ "$entry_needed" = yes ]; then
    write_zshrc=yes
  elif [ "$remove_init" = yes ] && [ "$rc_state" = managed ]; then
    write_zshrc=yes
  else
    return 0
  fi
  strip_region "$existing_zshrc" "$rc_begin" "$rc_end" > "$stage/next-zshrc" ||
    fail error.write "$zshrc"
  if [ "$entry_needed" = yes ]; then
    quoted_init=$(zsh -f -c 'print -r -- ${(qq)1}' -- "$install_directory/init.zsh") ||
      fail error.escape "$install_directory/init.zsh"
    {
      printf '%s\n' "$rc_begin"
      printf 'if [ -n "${ZSH_VERSION-}" ] && [ -f %s ]; then\n' "$quoted_init"
      printf '  source %s\n' "$quoted_init"
      printf '%s\n' 'fi' "$rc_end"
    } >> "$stage/next-zshrc" || fail error.write "$zshrc"
  fi
}

# 启动器固定工具及主配置的实际位置，不受当前目录或后续环境变化影响。
prepare_manager() {
  quoted_core=$(quote_path "$manager_directory/manager-core.sh")
  quoted_root=$(quote_path "$install_directory")
  quoted_rc=$(quote_path "$zshrc")
  {
    printf '%s\n' '#!/bin/sh' '# mac-shell-tools managed launcher' 'set -eu'
    printf 'if [ ! -f %s ] || [ -L %s ]; then\n' "$quoted_core" "$quoted_core"
    printf '%s\n' '  printf "%s\n" "mst: Manager is missing or linked; re-run the GitHub installation command." >&2' '  exit 1' 'fi'
    printf '. %s\n' "$quoted_core"
    printf '%s\n' 'if [ "$#" -eq 0 ]; then set -- --help; fi'
    printf 'main %s %s %s %s "$@"\n' "$quoted_core" "''" "$quoted_root" "$quoted_rc"
  } > "$stage/mst.sh"
  /bin/sh -n "$stage/mst.sh" || fail error.syntax "$stage/mst.sh"
  zsh -f -n "$stage/payload/manager/mst.zsh" || fail error.syntax "$stage/payload/manager/mst.zsh"
  /bin/sh -n "$manager_source" || fail error.syntax "$manager_source"
  printf '%s\n%s\n%s\n' "$package_version" "$package_revision" "$package_state" > "$stage/manager-version"
}

write_manager() {
  write_file "$manager_source" "$manager_directory/manager-core.sh"
  write_file "$stage/mst.sh" "$manager_directory/mst.sh"
  for manager_asset in mst.zsh i18n.sh locales/en.sh locales/zh-CN.sh; do
    write_file "$stage/payload/manager/$manager_asset" "$manager_directory/$manager_asset"
  done
  write_file "$stage/manager-version" "$manager_directory/version"
}

# 下载、校验完成前不写配置；清理下载暂存后 exec，避免新会话持有旧锁/文件。
fetch_release() {
  command -v curl >/dev/null 2>&1 || fail error.dependency curl
  stage=$(mktemp -d "${TMPDIR:-/tmp}/mac-shell-tools-download.XXXXXX") || fail error.stage
  release_url='https://raw.githubusercontent.com/bran-nie/mac-shell-tools/main/install.sh'
  message info.fetch "$release_url"
  curl -fsSL --proto '=https' --proto-redir '=https' --connect-timeout 10 --max-time 60 \
    -o "$stage/release.sh" "$release_url" || fail error.download
  if [ ! -s "$stage/release.sh" ]; then fail error.empty; fi
  /bin/sh -n "$stage/release.sh" || fail error.download_syntax
  if ! awk '$0 == "# mac-shell-tools bootstrap v1" { found = 1 } END { exit !found }' "$stage/release.sh"; then
    fail error.package
  fi
  release_code=$(cat "$stage/release.sh") || fail error.read_release
  cleanup
  trap - 0 HUP INT TERM
  MAC_SHELL_TOOLS_TARGET_DIRECTORY="$install_directory" MAC_SHELL_TOOLS_TARGET_ZSHRC="$zshrc" \
    RUNZSH="$run_zsh" exec /bin/sh -c "$release_code" -- "$@"
}

preflight_target() {
  check_file "$1"
  if [ -f "$1" ] && [ ! -w "$1" ]; then fail error.readonly "$1"; fi
  target_parent=${1%/*}
  if [ ! -w "$target_parent" ] || [ ! -x "$target_parent" ]; then fail error.parent "$target_parent"; fi
}

preflight_write() {
  check_file "$2"
  if [ -f "$2" ] && cmp -s "$1" "$2"; then return; fi
  preflight_target "$2"
}

backup_file() {
  if [ ! -f "$1" ]; then return 0; fi
  case $1 in
    "$install_directory"/*) backup_relative=${1#"$install_directory"/} ;;
    "$zshrc") backup_relative=zshrc/.zshrc ;;
    "$legacy_directory"/*) backup_relative="legacy/${1#"$legacy_directory"/}" ;;
    *) fail error.backup "$1" ;;
  esac
  backup_parent="$backup_directory/${backup_relative%/*}"
  if [ "$backup_parent" = "$backup_directory/$backup_relative" ]; then backup_parent=$backup_directory; fi
  ensure_directory "$backup_parent"
  stamp=$(date '+%Y%m%d-%H%M%S') || fail error.backup "$1"
  backup=$(mktemp "$backup_directory/$backup_relative.bak.$stamp.XXXXXX") || fail error.backup "$1"
  if ! cp -p "$1" "$backup"; then rm -f "$backup"; fail error.backup "$1"; fi
  message info.backup "$backup"
}

write_file() {
  prepared=$1
  target=$2
  check_file "$target"
  if [ -f "$target" ] && cmp -s "$prepared" "$target"; then return; fi
  backup_file "$target"
  pending_file=$(mktemp "${target%/*}/.mac-shell-tools.XXXXXX") || fail error.write "$target"
  if [ -f "$target" ]; then cp -p "$target" "$pending_file" || fail error.write "$target"; fi
  cat "$prepared" > "$pending_file" || fail error.write "$target"
  check_file "$target"
  mv -f "$pending_file" "$target" || fail error.write "$target"
  pending_file=
  changes_made=1
  message info.write "$target"
}

remove_file() {
  check_file "$1"
  if [ ! -f "$1" ]; then return; fi
  backup_file "$1"
  rm "$1" || fail error.remove "$1"
  changes_made=1
  message info.remove "$1"
}

finish() {
  cleanup
  trap - 0 HUP INT TERM
  if [ "$changes_made" -eq 0 ]; then message info.unchanged; return 0; fi
  message info.complete
  case $action in config) return 0 ;; esac
  should_start_zsh=no
  if [ "$run_zsh" = yes ] && [ -t 0 ] && [ -t 1 ]; then should_start_zsh=yes; fi
  case $should_start_zsh in
    yes)
      message info.login
      ZDOTDIR="$zdot_directory" exec zsh -l ;;
    no)
      case $action in
        setup|install|update|upgrade)
          quoted_init=$(quote_path "$install_directory/init.zsh")
          message info.activate
          printf '  source %s\n' "$quoted_init" ;;
        uninstall) message info.uninstall_activate ;;
      esac ;;
  esac
}


message() { mst_print_message "$language" "$@"; }

load_manager_catalogs() {
  # Bootstrap uses embedded catalogs. The installed manager loads its own files
  # so a missing translation can fall back to the English catalog.
  if [ "$invocation_mode" = bootstrap ]; then return 0; fi
  for catalog_asset in i18n.sh locales/en.sh locales/zh-CN.sh; do check_file "$manager_directory/$catalog_asset"; done
  if [ -f "$manager_directory/i18n.sh" ]; then . "$manager_directory/i18n.sh"; fi
  if [ -f "$manager_directory/locales/en.sh" ]; then . "$manager_directory/locales/en.sh"; fi
  unset -f mst_text_zh_CN
  if [ -f "$manager_directory/locales/zh-CN.sh" ]; then . "$manager_directory/locales/zh-CN.sh"; fi
}

quote_path() {
  zsh -f -c 'print -r -- ${(qq)1}' -- "$1" || fail error.escape "$1"
}

check_directory() {
  if [ -L "$1" ]; then fail error.symlink "$1"; fi
  if [ -e "$1" ] && [ ! -d "$1" ]; then fail error.directory_type "$1"; fi
}

# Check every managed subdirectory, while allowing pre-existing parent-directory links.
ensure_directory() {
  directory_to_create=$1
  case $directory_to_create in
    "$install_directory"/*)
      directory_tail=${directory_to_create#"$install_directory"/}
      directory_cursor=$install_directory
      while [ -n "$directory_tail" ]; do
        directory_piece=${directory_tail%%/*}
        directory_cursor="$directory_cursor/$directory_piece"
        check_directory "$directory_cursor"
        case $directory_tail in */*) directory_tail=${directory_tail#*/} ;; *) directory_tail= ;; esac
      done ;;
    *) check_directory "$directory_to_create" ;;
  esac
  mkdir -p "$directory_to_create" || fail error.mkdir "$directory_to_create"
}

# Removal must inspect parent directories too: a linked locales/ directory must
# never redirect backups or deletion into somebody else's files.
check_managed_parents() {
  managed_tail=${1#"$install_directory"/}
  managed_cursor=$install_directory
  check_directory "$managed_cursor"
  while :; do
    case $managed_tail in
      */*)
        managed_cursor="$managed_cursor/${managed_tail%%/*}"
        check_directory "$managed_cursor"
        managed_tail=${managed_tail#*/} ;;
      *) break ;;
    esac
  done
}

valid_version() {
  case $1 in unknown) return 0 ;; esac
  printf '%s\n' "$1" | awk '/^[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.+-]+)?$/ {ok=1} END {exit !ok}'
}

validate_record() {
  case $1 in
    init.zsh|mst.zsh) fail error.state "$source_state_file" ;;
    *.zsh) valid_tool_name "${1%.zsh}" || fail error.state "$source_state_file" ;;
    *) fail error.state "$source_state_file" ;;
  esac
  valid_version "$2" || fail error.state "$source_state_file"
  case $3 in
    unknown) ;;
    ''|*[!0-9a-f]*) fail error.state "$source_state_file" ;;
    *) [ "${#3}" -ge 7 ] && [ "${#3}" -le 64 ] || fail error.state "$source_state_file" ;;
  esac
  case $4 in clean|modified|unknown) ;; *) fail error.state "$source_state_file" ;; esac
  contains_file "$installed_files" "$1" && fail error.state "$source_state_file"
  installed_files="$installed_files $1"
  new_record=$(printf '%s\t%s\t%s\t%s' "$1" "$2" "$3" "$4")
  installed_records="${installed_records}${new_record}
"
}

record_for() {
  printf '%s' "$installed_records" | awk -F '\t' -v name="$1" '$1 == name {print; exit}'
}

component_path() { printf '%s/%s\n' "$tools_directory" "${1%.zsh}"; }

validate_assets() {
  check_file "$1"
  if [ ! -f "$1" ]; then fail error.assets "$1"; fi
  asset_seen=' '
  while IFS= read -r owned_asset || [ -n "$owned_asset" ]; do
    case $owned_asset in
      ''|/*|.*|*/.*|*..*|*[!a-zA-Z0-9./-]*|files.list) fail error.assets "$1" ;;
    esac
    case $asset_seen in *" $owned_asset "*) fail error.assets "$1" ;; esac
    asset_seen="$asset_seen$owned_asset "
  done < "$1"
}

prepare_component() {
  component_source=$1
  component_target=$2
  validate_assets "$component_source/files.list"
  ensure_directory "$component_target"
  while IFS= read -r owned_asset; do
    asset_parent=${owned_asset%/*}
    if [ "$asset_parent" != "$owned_asset" ]; then ensure_directory "$component_target/$asset_parent"; fi
    case $owned_asset in *.zsh) zsh -f -n "$component_source/$owned_asset" || fail error.syntax "$owned_asset" ;;
      *.sh) /bin/sh -n "$component_source/$owned_asset" || fail error.syntax "$owned_asset" ;; esac
    preflight_write "$component_source/$owned_asset" "$component_target/$owned_asset"
  done < "$component_source/files.list"
  preflight_write "$component_source/files.list" "$component_target/files.list"
}

write_component() {
  component_source=$1
  component_target=$2
  while IFS= read -r owned_asset; do
    write_file "$component_source/$owned_asset" "$component_target/$owned_asset"
  done < "$component_source/files.list"
  write_file "$component_source/files.list" "$component_target/files.list"
}

uninstall_manifest() {
  component_target=$(component_path "$1")
  check_directory "$component_target"
  check_file "$component_target/files.list"
  if [ -f "$component_target/files.list" ]; then
    validate_assets "$component_target/files.list"
    cat "$component_target/files.list"
  else
    printf '%s\n' "$1" version i18n.sh locales/en.sh locales/zh-CN.sh
  fi
}

preflight_uninstall() {
  component_target=$(component_path "$1")
  uninstall_manifest "$1" > "$stage/uninstall-$1"
  while IFS= read -r owned_asset; do
    check_managed_parents "$component_target/$owned_asset"
    check_file "$component_target/$owned_asset"
    if [ -f "$component_target/$owned_asset" ]; then preflight_target "$component_target/$owned_asset"; fi
  done < "$stage/uninstall-$1"
  if [ -f "$component_target/files.list" ]; then preflight_target "$component_target/files.list"; fi
}

remove_component() {
  component_target=$(component_path "$1")
  while IFS= read -r owned_asset; do remove_file "$component_target/$owned_asset"; done < "$stage/uninstall-$1"
  remove_file "$component_target/files.list"
  rmdir "$component_target/locales" 2>/dev/null || :
  rmdir "$component_target" 2>/dev/null || :
}

# v1 pins the old tools directory. Its sibling is independent of the caller's XDG.
resolve_locations() {
  legacy_directory=
  migrating=no
  if [ -z "$pinned_root" ]; then
    pinned_root=${MAC_SHELL_TOOLS_TARGET_DIRECTORY:-}
    pinned_rc=${MAC_SHELL_TOOLS_TARGET_ZSHRC:-}
  fi
  if [ -n "$pinned_root" ] || [ -n "$pinned_rc" ]; then
    require_absolute installation "$pinned_root"
    require_absolute .zshrc "$pinned_rc"
    install_directory=$pinned_root
    zshrc=$pinned_rc
    case $pinned_root in
      */tools)
        if [ -f "$pinned_root/.mac-shell-tools/manager-core.sh" ]; then
          legacy_directory=$pinned_root
          install_directory="${pinned_root%/*}/mac-shell-tools"
        fi ;;
    esac
  else
    config_home=${XDG_CONFIG_HOME:-$HOME/.config}
    zdot_directory=${ZDOTDIR:-$HOME}
    require_absolute XDG_CONFIG_HOME "$config_home"
    require_absolute ZDOTDIR "$zdot_directory"
    install_directory="$config_home/zsh/mac-shell-tools"
    zshrc="$zdot_directory/.zshrc"
    if [ -f "$config_home/zsh/tools/.mac-shell-tools/manager-core.sh" ]; then legacy_directory="$config_home/zsh/tools"; fi
  fi
  zdot_directory=${zshrc%/*}
  manager_directory="$install_directory/manager"
  tools_directory="$install_directory/tools"
  backup_directory="$install_directory/backups"
  state_file="$tools_directory/installed.list"
  settings_file="$install_directory/config.conf"
  check_directory "$install_directory"
  check_directory "$manager_directory"
  check_directory "$tools_directory"
  check_directory "$backup_directory"
  check_file "$manager_directory/legacy-root"
  check_file "$manager_directory/migration-complete"
  if [ -f "$manager_directory/legacy-root" ] && [ ! -f "$manager_directory/migration-complete" ]; then
    check_file "$manager_directory/legacy-root"
    legacy_directory=$(cat "$manager_directory/legacy-root")
    require_absolute legacy "$legacy_directory"
  fi
  if [ -n "$legacy_directory" ]; then
    check_directory "$legacy_directory"
    check_directory "$legacy_directory/.mac-shell-tools"
    if [ -f "$manager_directory/manager-core.sh" ] && [ ! -f "$manager_directory/legacy-root" ]; then
      fail error.migration_conflict "$legacy_directory"
    fi
    if [ -f "$manager_directory/legacy-root" ] && [ "$(cat "$manager_directory/legacy-root")" != "$legacy_directory" ]; then
      fail error.migration_conflict "$legacy_directory"
    fi
    if [ ! -f "$manager_directory/manager-core.sh" ] || {
      [ -f "$manager_directory/legacy-root" ] && [ ! -f "$manager_directory/migration-complete" ];
    }; then
      migrating=yes
      check_directory "$legacy_directory"
      check_file "$legacy_directory/init.zsh"
      inspect_region "$legacy_directory/init.zsh" "$init_begin" "$init_end"
      [ "$region_state" = managed ] || fail error.unknown_entry "$legacy_directory/init.zsh"
    fi
  fi
}

prepare_migration() {
  migration_files=
  if [ "$migrating" = no ]; then return 0; fi
  message info.migrate "$legacy_directory"
  printf '%s\n' "$legacy_directory" > "$stage/legacy-root"
  for legacy_file in $next_files; do
    if contains_file "$selected_files" "$legacy_file"; then
      case $action in install|update) continue ;; esac
    fi
    target_component=$(component_path "$legacy_file")
    check_file "$legacy_directory/$legacy_file"
    [ -f "$legacy_directory/$legacy_file" ] || fail error.migration_source "$legacy_file"
    check_directory "$target_component"
    check_file "$target_component/$legacy_file"
    if [ -f "$target_component/$legacy_file" ]; then
      # A completed component from an interrupted migration may be reused. A
      # partial copy of the original bytes is completed below; other files are
      # left for the user to resolve instead of silently adopting ownership.
      if [ -f "$manager_directory/legacy-root" ] && [ -f "$target_component/files.list" ] && [ -f "$target_component/version" ]; then
        validate_assets "$target_component/files.list"
        continue
      fi
      cmp -s "$target_component/$legacy_file" "$legacy_directory/$legacy_file" || fail error.migration_conflict "$target_component"
    fi
    migration_files="$migration_files $legacy_file"
    source_component="$stage/migration/${legacy_file%.zsh}"
    mkdir -p "$source_component" || fail error.stage
    cp -p "$legacy_directory/$legacy_file" "$source_component/$legacy_file" || fail error.write "$legacy_file"
    printf '%s\n' unknown unknown unknown > "$source_component/version"
    printf '%s\n' "$legacy_file" version > "$source_component/files.list"
    prepare_component "$source_component" "$target_component"
  done
  awk -v begin="$init_begin" -v end="$init_end" '
    $0 == begin {print begin; print end; inside=1; next}
    $0 == end {inside=0; next}
    !inside {print}
  ' "$legacy_directory/init.zsh" > "$stage/legacy-init.zsh"
  zsh -f -n "$stage/legacy-init.zsh" || fail error.syntax "$legacy_directory/init.zsh"
  preflight_write "$stage/legacy-init.zsh" "$legacy_directory/init.zsh"
  quote_new_launcher=$(quote_path "$manager_directory/mst.sh")
  printf '#!/bin/sh\n# mac-shell-tools compatibility launcher\nexec /bin/sh %s "$@"\n' "$quote_new_launcher" > "$stage/legacy-launcher.sh"
  /bin/sh -n "$stage/legacy-launcher.sh" || fail error.syntax "$stage/legacy-launcher.sh"
  preflight_write "$stage/legacy-launcher.sh" "$legacy_directory/.mac-shell-tools/mst.sh"
  preflight_write "$stage/legacy-root" "$manager_directory/legacy-root"
  preflight_write "$stage/legacy-root" "$manager_directory/migration-complete"
}

configure_language() {
  if [ -z "$config_value" ]; then
    saved_language=$(mst_resolve_language "$settings_file" '') || exit 2
    message info.language "$saved_language"
    return 0
  fi
  check_file "$settings_file"
  ensure_directory "$install_directory"
  ensure_directory "$backup_directory"
  lock_directory="$install_directory/.mac-shell-tools-install.lock"
  mkdir "$lock_directory" 2>/dev/null || fail error.lock "$lock_directory"
  has_lock=1
  stage=$(mktemp -d "${TMPDIR:-/tmp}/mac-shell-tools-install.XXXXXX") || fail error.stage
  printf 'language=%s\n' "$config_value" > "$stage/config.conf"
  preflight_write "$stage/config.conf" "$settings_file"
  if [ -z "$language_override" ] && [ -z "${MST_LANG:-}" ]; then language=$config_value; fi
  write_file "$stage/config.conf" "$settings_file"
  message info.language "$config_value"
  finish
}

main() {
  manager_source=$1
  owned_bootstrap_directory=$2
  pinned_root=$3
  pinned_rc=$4
  shift 4
  invocation_mode=installed
  if [ -n "$owned_bootstrap_directory" ]; then invocation_mode=bootstrap; fi
  # Resolve the display language before parsing so argument errors use the saved
  # preference too. An explicit --lang can also repair an invalid config file.
  language_override=
  expect_language=no
  for initial_argument do
    if [ "$expect_language" = yes ]; then
      language_override=$initial_argument; expect_language=no; continue
    fi
    case $initial_argument in
      --) break ;;
      --lang) expect_language=yes ;;
      --lang=*) language_override=${initial_argument#--lang=} ;;
    esac
  done
  case $language_override in en|zh-CN) language=$language_override ;; esac
  require_absolute HOME "${HOME:-}"
  resolve_locations
  language=$(mst_resolve_language "$settings_file" "${language_override:-${MST_LANG:-}}") || exit 2
  load_manager_catalogs
  parse_arguments "$@"
  if [ "$invocation_mode" = installed ] && [ "$action" = setup ]; then action=help; fi
  case $action in
    help) usage; return 0 ;;
    version) printf 'mst %s (%s; %s)\n' "$package_version" "$package_revision" "$package_state"; return 0 ;;
    config) configure_language; return 0 ;;
    setup|install|update|upgrade|uninstall|list) ;;
  esac
  for dependency in uname zsh mkdir mktemp cat awk cmp cp mv date rm rmdir; do
    command -v "$dependency" >/dev/null 2>&1 || fail error.dependency "$dependency"
  done
  platform=$(uname -s) || fail error.platform
  case $platform in Darwin|Linux) ;; *) fail error.platform ;; esac
  check_file "$install_directory/init.zsh"
  check_file "$zshrc"
  if [ -f "$install_directory/init.zsh" ]; then
    inspect_region "$install_directory/init.zsh" "$init_begin" "$init_end"
    [ "$region_state" = managed ] || fail error.unknown_entry "$install_directory/init.zsh"
  fi
  read_installed
  case $invocation_mode in
    installed)
      case $action in
        install|upgrade) fetch_release "$@" ;;
        update)
          for checked_file in $requested_files; do
            contains_file "$installed_files" "$checked_file" || usage_error error.not_installed "${checked_file%.zsh}"
          done
          if [ -z "$installed_files" ]; then message info.empty; return 0; fi
          fetch_release "$@" ;;
        setup|uninstall|list) ;;
      esac ;;
    bootstrap) ;;
  esac
  select_files
  write_manager_runtime=no
  case $action in
    list) list_tools; return 0 ;;
    setup|upgrade|install) write_manager_runtime=yes ;;
    update|uninstall)
      if [ -z "$selected_files" ] && [ "$migrating" = no ]; then message info.no_tools; return 0; fi ;;
  esac
  if [ "$migrating" = yes ]; then write_manager_runtime=yes; fi
  ensure_directory "$install_directory"
  ensure_directory "$zdot_directory"
  install_directory=$(CDPATH= cd -P "$install_directory" && pwd) || fail error.enter "$install_directory"
  zdot_directory=$(CDPATH= cd -P "$zdot_directory" && pwd) || fail error.enter "$zdot_directory"
  zshrc="$zdot_directory/.zshrc"
  tools_directory="$install_directory/tools"
  manager_directory="$install_directory/manager"
  backup_directory="$install_directory/backups"
  state_file="$tools_directory/installed.list"
  settings_file="$install_directory/config.conf"
  lock_directory="$install_directory/.mac-shell-tools-install.lock"
  mkdir "$lock_directory" 2>/dev/null || fail error.lock "$lock_directory"
  has_lock=1
  if [ "$migrating" = yes ]; then
    legacy_lock_directory="$legacy_directory/.mac-shell-tools-install.lock"
    mkdir "$legacy_lock_directory" 2>/dev/null || fail error.lock "$legacy_lock_directory"
    has_legacy_lock=1
  fi
  read_installed
  select_files
  ensure_directory "$tools_directory"
  ensure_directory "$backup_directory"
  if [ "$write_manager_runtime" = yes ]; then
    ensure_directory "$manager_directory/locales"
    for manager_file in manager-core.sh mst.sh mst.zsh i18n.sh locales/en.sh locales/zh-CN.sh version; do check_file "$manager_directory/$manager_file"; done
  fi
  stage=$(mktemp -d "${TMPDIR:-/tmp}/mac-shell-tools-install.XXXXXX") || fail error.stage
  write_payload || fail error.payload
  if [ "$write_manager_runtime" = yes ]; then prepare_manager; fi
  prepare_init
  prepare_zshrc
  write_state=no
  case $action in install|update|uninstall) write_state=yes ;; setup|upgrade) ;; esac
  if [ "$migrating" = yes ]; then write_state=yes; fi
  : > "$stage/next-state"
  for recorded_file in $next_files; do
    use_package_record=no
    case $action in install|update)
      if contains_file "$selected_files" "$recorded_file"; then use_package_record=yes; fi ;;
    esac
    case $use_package_record in
      yes) printf '%s\t%s\t%s\t%s\n' "$recorded_file" "$package_version" "$package_revision" "$package_state" >> "$stage/next-state" ;;
      no) record_for "$recorded_file" >> "$stage/next-state" ;;
    esac
  done
  zsh -f -n "$stage/next-init.zsh" || fail error.syntax "$install_directory/init.zsh"
  preflight_write "$stage/next-init.zsh" "$install_directory/init.zsh"
  if [ "$write_zshrc" = yes ]; then
    zsh -f -n "$stage/next-zshrc" || fail error.syntax "$zshrc"
    preflight_write "$stage/next-zshrc" "$zshrc"
  fi
  if [ "$write_manager_runtime" = yes ]; then
    preflight_write "$manager_source" "$manager_directory/manager-core.sh"
    preflight_write "$stage/mst.sh" "$manager_directory/mst.sh"
    preflight_write "$stage/manager-version" "$manager_directory/version"
    for manager_asset in mst.zsh i18n.sh locales/en.sh locales/zh-CN.sh; do
      preflight_write "$stage/payload/manager/$manager_asset" "$manager_directory/$manager_asset"
    done
  fi
  if [ "$write_state" = yes ]; then
    if [ -n "$next_files" ]; then preflight_write "$stage/next-state" "$state_file"; else preflight_target "$state_file"; fi
  fi
  case $action in
    install|update)
      for selected_file in $selected_files; do
        prepare_component "$stage/payload/tools/${selected_file%.zsh}" "$(component_path "$selected_file")"
      done ;;
    uninstall) for selected_file in $selected_files; do preflight_uninstall "$selected_file"; done ;;
    setup|upgrade) ;;
  esac
  prepare_migration
  # Journal comes first so an interrupted migration can be resumed safely.
  if [ "$migrating" = yes ]; then write_file "$stage/legacy-root" "$manager_directory/legacy-root"; fi
  if [ "$write_manager_runtime" = yes ]; then write_manager; fi
  for legacy_file in $migration_files; do
    write_component "$stage/migration/${legacy_file%.zsh}" "$(component_path "$legacy_file")"
  done
  case $action in
    install|update)
      for selected_file in $selected_files; do
        write_component "$stage/payload/tools/${selected_file%.zsh}" "$(component_path "$selected_file")"
      done ;;
    setup|upgrade|uninstall) ;;
  esac
  write_file "$stage/next-init.zsh" "$install_directory/init.zsh"
  if [ "$write_zshrc" = yes ]; then write_file "$stage/next-zshrc" "$zshrc"; fi
  case $action in uninstall) for selected_file in $selected_files; do remove_component "$selected_file"; done ;; esac
  if [ "$write_state" = yes ]; then
    if [ -n "$next_files" ]; then write_file "$stage/next-state" "$state_file"; else remove_file "$state_file"; fi
  fi
  if [ "$migrating" = yes ]; then
    write_file "$stage/legacy-launcher.sh" "$legacy_directory/.mac-shell-tools/mst.sh"
    write_file "$stage/legacy-init.zsh" "$legacy_directory/init.zsh"
    write_file "$stage/legacy-root" "$manager_directory/migration-complete"
    message info.migrated "$legacy_directory"
  fi
  finish
}

write_payload() {
  mkdir -p "$stage/payload" || return 1
  cat > "$stage/payload/init.zsh" <<'MAC_SHELL_TOOLS_EMBEDDED_FILE_7D4C' || return 1
# mac-shell-tools 集中入口。
# 管理区域显式注册工具；其他区域由用户维护，更新时保留。

# >>> mac-shell-tools managed tools >>>
if [ -z "${ZSH_VERSION-}" ]; then return 0; fi
() {
  emulate -L zsh
  # Reuse completion initialized by Oh My Zsh or another Zsh configuration.
  if [[ -o interactive ]] && (( ! $+functions[compdef] )); then
    autoload -Uz compinit
    compinit
  fi
  local mac_shell_tools_directory=${${(%):-%x}:A:h}
  if [[ -f "$mac_shell_tools_directory/manager/mst.zsh" ]]; then
    source "$mac_shell_tools_directory/manager/mst.zsh"
  fi
  if [[ -f "$mac_shell_tools_directory/tools/dsize/dsize.zsh" ]]; then
    source "$mac_shell_tools_directory/tools/dsize/dsize.zsh"
  elif [[ -f "$mac_shell_tools_directory/dsize/dsize.zsh" ]]; then
    source "$mac_shell_tools_directory/dsize/dsize.zsh"
  fi
}
# <<< mac-shell-tools managed tools <<<

# 用户自定义区域：可在此添加其他工具引用和注释。
# 定位此入口所在目录可使用 ${${(%):-%x}:A:h}，不要依赖当前工作目录。
MAC_SHELL_TOOLS_EMBEDDED_FILE_7D4C
  mkdir -p "$stage/payload/manager" || return 1
  cat > "$stage/payload/manager/mst.zsh" <<'MAC_SHELL_TOOLS_EMBEDDED_FILE_7D4C' || return 1
# mac-shell-tools 常驻管理入口，由集中入口加载。
# 根据函数定义文件定位管理器，不依赖调用目录或后续环境变量变化。
mst() {
  emulate -L zsh
  local manager_directory=${${(%):-%x}:A:h}
  local manager_launcher="$manager_directory/mst.sh"
  if [[ ! -f "$manager_launcher" || -L "$manager_launcher" ]]; then
    print -ru2 -- "mst: Manager launcher is missing or linked; re-run the installation command: $manager_launcher"
    return 1
  fi
  command /bin/sh "$manager_launcher" "$@"
}
MAC_SHELL_TOOLS_EMBEDDED_FILE_7D4C
  mkdir -p "$stage/payload/manager" || return 1
  cat > "$stage/payload/manager/i18n.sh" <<'MAC_SHELL_TOOLS_EMBEDDED_FILE_7D4C' || return 1
# Shared POSIX sh language helpers. Configuration is read as data, never sourced.
mst_resolve_language() (
  settings=$1
  override=$2
  chosen=en
  if [ -n "$override" ]; then
    chosen=$override
  elif [ -e "$settings" ] || [ -L "$settings" ]; then
    if [ ! -f "$settings" ] || [ -L "$settings" ]; then
      printf 'mst: Invalid language configuration: %s\n' "$settings" >&2
      return 2
    fi
    seen=no
    while IFS= read -r line || [ -n "$line" ]; do
      case $line in
        ''|'#'*) ;;
        language=*)
          if [ "$seen" = yes ]; then printf 'mst: Duplicate language setting: %s\n' "$settings" >&2; return 2; fi
          chosen=${line#language=}; seen=yes ;;
        *) printf 'mst: Invalid language configuration: %s\n' "$settings" >&2; return 2 ;;
      esac
    done < "$settings"
  fi
  case $chosen in
    en|zh-CN) printf '%s\n' "$chosen" ;;
    *) printf 'mst: Unsupported language: %s (use en or zh-CN).\n' "$chosen" >&2; return 2 ;;
  esac
)

# Catalogs return fixed printf formats. Arguments are passed separately, without eval.
mst_print_message() (
  chosen_language=$1
  message_key=$2
  shift 2
  format=$(mst_text_en "$message_key") || {
    printf 'mst: Unknown message key: %s\n' "$message_key" >&2
    return 1
  }
  case $chosen_language in
    en) ;;
    zh-CN)
      if command -v mst_text_zh_CN >/dev/null 2>&1; then
        translated=$(mst_text_zh_CN "$message_key") && format=$translated
      fi
      ;;
  esac
  printf "$format\n" "$@"
)
MAC_SHELL_TOOLS_EMBEDDED_FILE_7D4C
  mkdir -p "$stage/payload/manager/locales" || return 1
  cat > "$stage/payload/manager/locales/en.sh" <<'MAC_SHELL_TOOLS_EMBEDDED_FILE_7D4C' || return 1
# mst_text_en message catalog.
mst_text_en() {
  case $1 in
    error.help) printf '%s\n' 'Run mst --help for usage.' ;;
    error.interrupted) printf '%s\n' 'Operation interrupted. Existing backups can be used for recovery.' ;;
    error.runzsh) printf '%s\n' 'RUNZSH must be yes or no.' ;;
    error.option) printf '%s\n' 'Unknown option: %s' ;;
    error.command) printf '%s\n' 'Unknown command: %s' ;;
    error.name) printf '%s\n' 'Invalid tool name: %s' ;;
    error.all_names) printf '%s\n' '--all cannot be combined with tool names.' ;;
    error.no_names) printf '%s\n' '%s does not accept tool names or --all.' ;;
    error.uninstall_names) printf '%s\n' 'Specify tools to uninstall, or use uninstall --all.' ;;
    error.language) printf '%s\n' 'Unsupported language: %s (use en or zh-CN).' ;;
    error.language_value) printf '%s\n' '--lang requires en or zh-CN.' ;;
    error.config) printf '%s\n' 'Usage: mst config language [en|zh-CN]' ;;
    error.absolute) printf '%s\n' '%s must be an absolute path: %s' ;;
    error.symlink) printf '%s\n' 'Symbolic link preserved; refusing to manage: %s' ;;
    error.file_type) printf '%s\n' 'Target is not a regular file: %s' ;;
    error.directory_type) printf '%s\n' 'Target is not a directory: %s' ;;
    error.markers) printf '%s\n' 'Managed markers are broken or duplicated: %s' ;;
    error.unknown_entry) printf '%s\n' 'Existing entry has no recognized managed block: %s' ;;
    error.state) printf '%s\n' 'Invalid or duplicate installed-tool record: %s' ;;
    error.assets) printf '%s\n' 'Invalid owned-file manifest: %s' ;;
    error.available) printf '%s\n' 'Tool is unavailable in this package: %s' ;;
    error.not_installed) printf '%s\n' 'Tool is not installed: %s' ;;
    error.unknown_tool) printf '%s\n' 'Unknown tool: %s' ;;
    error.escape) printf '%s\n' 'Cannot quote configuration path: %s' ;;
    error.syntax) printf '%s\n' 'Shell syntax check failed: %s' ;;
    error.dependency) printf '%s\n' 'Required command is missing: %s' ;;
    error.platform) printf '%s\n' 'Supported systems: macOS and Linux.' ;;
    error.mkdir) printf '%s\n' 'Cannot create directory: %s' ;;
    error.enter) printf '%s\n' 'Cannot enter directory: %s' ;;
    error.lock) printf '%s\n' 'Cannot acquire the installation lock; check for another operation before removing it: %s' ;;
    error.stage) printf '%s\n' 'Cannot create a temporary directory.' ;;
    error.payload) printf '%s\n' 'Cannot prepare embedded files.' ;;
    error.readonly) printf '%s\n' 'File is not writable: %s' ;;
    error.parent) printf '%s\n' 'Directory is not writable or accessible: %s' ;;
    error.backup) printf '%s\n' 'Cannot create a complete backup: %s' ;;
    error.write) printf '%s\n' 'Cannot write or replace file (check permissions and free space): %s' ;;
    error.remove) printf '%s\n' 'Cannot remove file: %s' ;;
    error.download) printf '%s\n' 'Download failed; existing managed files are unchanged.' ;;
    error.empty) printf '%s\n' 'Downloaded package is empty; existing files are unchanged.' ;;
    error.download_syntax) printf '%s\n' 'Downloaded package has invalid shell syntax; existing files are unchanged.' ;;
    error.package) printf '%s\n' 'Downloaded content is not a supported mac-shell-tools package; existing files are unchanged.' ;;
    error.read_release) printf '%s\n' 'Cannot read the downloaded package.' ;;
    error.migration_conflict) printf '%s\n' 'New installation already exists with conflicting legacy state; preserved both locations: %s' ;;
    error.migration_source) printf '%s\n' 'Legacy installation is missing a registered tool: %s' ;;
    info.fetch) printf '%s\n' 'Fetching: %s' ;;
    info.backup) printf '%s\n' 'Backed up: %s' ;;
    info.write) printf '%s\n' 'Written: %s' ;;
    info.remove) printf '%s\n' 'Uninstalled: %s' ;;
    info.unchanged) printf '%s\n' 'No files need changing.' ;;
    info.complete) printf '%s\n' 'Operation complete.' ;;
    info.login) printf '%s\n' 'Starting a new login Zsh in this terminal; exiting may return to the previous session.' ;;
    info.activate) printf '%s\n' 'Start Zsh with zsh -l, or run this in your current Zsh:' ;;
    info.uninstall_activate) printf '%s\n' 'Start a fresh Zsh with exec zsh -l; loaded functions remain in existing sessions.' ;;
    info.empty) printf '%s\n' 'No tools are installed; nothing to update.' ;;
    info.no_tools) printf '%s\n' 'No tools to process. Run mst list to see their status.' ;;
    info.language) printf '%s\n' 'Language: %s' ;;
    info.migrate) printf '%s\n' 'Migrating the registered installation from %s' ;;
    info.migrated) printf '%s\n' 'Migration complete. Personal files and existing backups remain in %s' ;;
    status.not_installed) printf '%s\n' 'not installed' ;;
    status.installed) printf '%s\n' 'installed' ;;
    status.missing) printf '%s\n' 'installed (file missing)' ;;
    status.unavailable) printf '%s\n' 'unavailable in catalog' ;;
    list.header) printf '%s\n' 'TOOL                 STATUS                       INSTALLED VERSION             AVAILABLE VERSION' ;;
    help) printf '%s\n' 'Usage: mst <command> [tool ...] [options]
       sh install.sh [command] [tool ...] [options]

Commands:
  install [tool ...]       Install selected tools; no names means all.
  update [tool ...]        Update installed tools only.
  uninstall tool ...      Uninstall selected tools, with backups.
  uninstall --all         Uninstall all tools; keep mst.
  list                    Show the local catalog, status, and versions.
  upgrade                 Upgrade mst and its catalog; keep tools unchanged.
  version                 Show mst'\''s installed version and source revision.
  config language         Show the saved language (default: en).
  config language en      Save English for mst and tools.
  config language zh-CN   Save Simplified Chinese for mst and tools.

Options:
  --all                   Select all; cannot be combined with tool names.
  --lang en|zh-CN         Use this language for this command only.
  --no-run-zsh            Do not start a new Zsh session.
  --unattended            Non-interactive operation; do not start Zsh.
  -V, --version           Show mst'\''s version.
  -h, --help              Show this help.

Running install.sh without a command installs mst only.
Installed mst install/update/upgrade fetch the latest GitHub package.
RUNZSH=no also disables the new login session.
Language changes take effect on the next invocation, without a new session.' ;;
    *) return 1 ;;
  esac
}
MAC_SHELL_TOOLS_EMBEDDED_FILE_7D4C
  mkdir -p "$stage/payload/manager/locales" || return 1
  cat > "$stage/payload/manager/locales/zh-CN.sh" <<'MAC_SHELL_TOOLS_EMBEDDED_FILE_7D4C' || return 1
# mst_text_zh_CN message catalog.
mst_text_zh_CN() {
  case $1 in
    error.help) printf '%s\n' '运行 mst --help 查看用法。' ;;
    error.interrupted) printf '%s\n' '操作已中断；已生成的备份可用于恢复。' ;;
    error.runzsh) printf '%s\n' 'RUNZSH 只能为 yes 或 no。' ;;
    error.option) printf '%s\n' '未知参数：%s' ;;
    error.command) printf '%s\n' '未知命令：%s' ;;
    error.name) printf '%s\n' '无效工具名：%s' ;;
    error.all_names) printf '%s\n' '--all 不能与工具名同时使用。' ;;
    error.no_names) printf '%s\n' '%s 不接受工具名或 --all。' ;;
    error.uninstall_names) printf '%s\n' '请指定卸载工具，或使用 uninstall --all。' ;;
    error.language) printf '%s\n' '不支持的语言：%s（请使用 en 或 zh-CN）。' ;;
    error.language_value) printf '%s\n' '--lang 需要 en 或 zh-CN。' ;;
    error.config) printf '%s\n' '用法：mst config language [en|zh-CN]' ;;
    error.absolute) printf '%s\n' '%s 必须是绝对路径：%s' ;;
    error.symlink) printf '%s\n' '目标为符号链接，已保留并停止变更：%s' ;;
    error.file_type) printf '%s\n' '目标不是普通文件：%s' ;;
    error.directory_type) printf '%s\n' '目标不是目录：%s' ;;
    error.markers) printf '%s\n' '管理标记损坏或重复：%s' ;;
    error.unknown_entry) printf '%s\n' '已有入口没有可识别的管理块：%s' ;;
    error.state) printf '%s\n' '安装清单记录无效或重复：%s' ;;
    error.assets) printf '%s\n' '工具文件清单无效：%s' ;;
    error.available) printf '%s\n' '当前安装包不提供工具：%s' ;;
    error.not_installed) printf '%s\n' '工具尚未安装：%s' ;;
    error.unknown_tool) printf '%s\n' '未知工具：%s' ;;
    error.escape) printf '%s\n' '无法转义配置路径：%s' ;;
    error.syntax) printf '%s\n' 'Shell 语法检查失败：%s' ;;
    error.dependency) printf '%s\n' '缺少基础命令：%s' ;;
    error.platform) printf '%s\n' '支持的系统：macOS 和 Linux。' ;;
    error.mkdir) printf '%s\n' '无法创建目录：%s' ;;
    error.enter) printf '%s\n' '无法进入目录：%s' ;;
    error.lock) printf '%s\n' '无法取得安装锁；确认没有其他操作运行后再处理：%s' ;;
    error.stage) printf '%s\n' '无法创建暂存目录。' ;;
    error.payload) printf '%s\n' '无法准备内嵌文件。' ;;
    error.readonly) printf '%s\n' '文件不可写：%s' ;;
    error.parent) printf '%s\n' '目录不可写或无法进入：%s' ;;
    error.backup) printf '%s\n' '无法创建完整备份：%s' ;;
    error.write) printf '%s\n' '无法写入或替换文件，请检查权限及剩余空间：%s' ;;
    error.remove) printf '%s\n' '无法删除文件：%s' ;;
    error.download) printf '%s\n' '下载失败；现有管理文件未变更。' ;;
    error.empty) printf '%s\n' '下载内容为空；现有文件未变更。' ;;
    error.download_syntax) printf '%s\n' '下载脚本语法错误；现有文件未变更。' ;;
    error.package) printf '%s\n' '下载内容不是支持的 mac-shell-tools 安装包；现有文件未变更。' ;;
    error.read_release) printf '%s\n' '无法读取下载的安装包。' ;;
    error.migration_conflict) printf '%s\n' '新安装与旧清单冲突，已保留两处内容：%s' ;;
    error.migration_source) printf '%s\n' '旧安装中缺少已登记工具：%s' ;;
    info.fetch) printf '%s\n' '正在获取：%s' ;;
    info.backup) printf '%s\n' '已备份：%s' ;;
    info.write) printf '%s\n' '已写入：%s' ;;
    info.remove) printf '%s\n' '已卸载：%s' ;;
    info.unchanged) printf '%s\n' '没有需要变更的文件。' ;;
    info.complete) printf '%s\n' '操作完成。' ;;
    info.login) printf '%s\n' '即将在当前终端启动新的 Zsh 登录会话；退出后可能回到原会话。' ;;
    info.activate) printf '%s\n' '请执行 zsh -l 进入 Zsh，或在当前 Zsh 执行：' ;;
    info.uninstall_activate) printf '%s\n' '请执行 exec zsh -l 启动全新的 Zsh；已有会话中的函数不会自动清除。' ;;
    info.empty) printf '%s\n' '尚未安装工具，无需更新。' ;;
    info.no_tools) printf '%s\n' '没有可处理的工具；可运行 mst list 查看状态。' ;;
    info.language) printf '%s\n' '语言：%s' ;;
    info.migrate) printf '%s\n' '正在迁移已登记安装：%s' ;;
    info.migrated) printf '%s\n' '迁移完成；个人文件与已有备份保留在 %s' ;;
    status.not_installed) printf '%s\n' '未安装' ;;
    status.installed) printf '%s\n' '已安装' ;;
    status.missing) printf '%s\n' '已安装（文件缺失）' ;;
    status.unavailable) printf '%s\n' '工具目录中已不提供' ;;
    list.header) printf '%s\n' '工具                 状态                         已安装版本                    可用版本' ;;
    help) printf '%s\n' '用法：mst <命令> [工具名 ...] [参数]
      sh install.sh [命令] [工具名 ...] [参数]

命令：
  install [工具名 ...]     安装指定工具；不指定时安装全部工具。
  update [工具名 ...]      仅更新已安装工具。
  uninstall 工具名 ...    卸载指定工具，删除前备份。
  uninstall --all         卸载全部工具，保留 mst。
  list                    查看本地可用工具、安装状态和版本。
  upgrade                 升级 mst 和可用工具目录，保留已安装工具。
  version                 查看 mst 的版本和源码修订。
  config language         查看已保存的语言，默认 en。
  config language en      为 mst 和工具保存英文设置。
  config language zh-CN   为 mst 和工具保存简体中文设置。

参数：
  --all                   选择全部工具，不能与名称混用。
  --lang en|zh-CN         仅本次命令使用指定语言。
  --no-run-zsh            不启动新的 Zsh 会话。
  --unattended            非交互操作，不启动 Zsh。
  -V, --version           查看 mst 版本。
  -h, --help              查看帮助。

不带命令运行 install.sh 时只安装 mst。
安装后的 mst install/update/upgrade 从 GitHub 获取最新安装包。
RUNZSH=no 也可关闭新的登录会话。
语言设置在下次调用时生效，无需启动新会话。' ;;
    *) return 1 ;;
  esac
}
MAC_SHELL_TOOLS_EMBEDDED_FILE_7D4C
  mkdir -p "$stage/payload/tools/dsize" || return 1
  cat > "$stage/payload/tools/dsize/dsize.zsh" <<'MAC_SHELL_TOOLS_EMBEDDED_FILE_7D4C' || return 1
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
  local version='0.1.0-dev+56a073aed4d3' revision='82ef43f85d25b9d78729e8e3da2e83b0e8cffac5' source_state='modified'
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
MAC_SHELL_TOOLS_EMBEDDED_FILE_7D4C
  mkdir -p "$stage/payload/tools/dsize" || return 1
  cat > "$stage/payload/tools/dsize/version" <<'MAC_SHELL_TOOLS_EMBEDDED_FILE_7D4C' || return 1
0.1.0-dev+56a073aed4d3
82ef43f85d25b9d78729e8e3da2e83b0e8cffac5
modified
MAC_SHELL_TOOLS_EMBEDDED_FILE_7D4C
  mkdir -p "$stage/payload/tools/dsize" || return 1
  cat > "$stage/payload/tools/dsize/i18n.sh" <<'MAC_SHELL_TOOLS_EMBEDDED_FILE_7D4C' || return 1
# Shared POSIX sh language helpers. Configuration is read as data, never sourced.
mst_resolve_language() (
  settings=$1
  override=$2
  chosen=en
  if [ -n "$override" ]; then
    chosen=$override
  elif [ -e "$settings" ] || [ -L "$settings" ]; then
    if [ ! -f "$settings" ] || [ -L "$settings" ]; then
      printf 'mst: Invalid language configuration: %s\n' "$settings" >&2
      return 2
    fi
    seen=no
    while IFS= read -r line || [ -n "$line" ]; do
      case $line in
        ''|'#'*) ;;
        language=*)
          if [ "$seen" = yes ]; then printf 'mst: Duplicate language setting: %s\n' "$settings" >&2; return 2; fi
          chosen=${line#language=}; seen=yes ;;
        *) printf 'mst: Invalid language configuration: %s\n' "$settings" >&2; return 2 ;;
      esac
    done < "$settings"
  fi
  case $chosen in
    en|zh-CN) printf '%s\n' "$chosen" ;;
    *) printf 'mst: Unsupported language: %s (use en or zh-CN).\n' "$chosen" >&2; return 2 ;;
  esac
)

# Catalogs return fixed printf formats. Arguments are passed separately, without eval.
mst_print_message() (
  chosen_language=$1
  message_key=$2
  shift 2
  format=$(mst_text_en "$message_key") || {
    printf 'mst: Unknown message key: %s\n' "$message_key" >&2
    return 1
  }
  case $chosen_language in
    en) ;;
    zh-CN)
      if command -v mst_text_zh_CN >/dev/null 2>&1; then
        translated=$(mst_text_zh_CN "$message_key") && format=$translated
      fi
      ;;
  esac
  printf "$format\n" "$@"
)
MAC_SHELL_TOOLS_EMBEDDED_FILE_7D4C
  mkdir -p "$stage/payload/tools/dsize/locales" || return 1
  cat > "$stage/payload/tools/dsize/locales/en.sh" <<'MAC_SHELL_TOOLS_EMBEDDED_FILE_7D4C' || return 1
# mst_text_en message catalog.
mst_text_en() {
  case $1 in
    help) printf '%s\n' 'Usage: dsize [directory] [options]

Show the largest directory disk-usage totals, in ascending size order.
The largest entry is last. Defaults: directory ., depth 2, up to 25 lines.

  -d N, --depth N, --depth=N  Display depth, decimal integer 0–1000
  -n N, --lines N, --lines=N  Maximum lines, decimal integer 1–1000000
  -V, --version              Show the loaded tool'\''s version
  -h, --help                 Show help
  --                         Stop options; at most one directory may follow

Directory and options may be interleaved; the last repeated option wins.
Leading zeros are decimal. Depth limits display, not traversal.
Results are directory totals; file usage is included in its containing directory.
Parent totals include children and cannot be added together. No files are deleted.
Exit codes: 0 success/help, 2 invalid input, 1 incomplete scan or command failure.' ;;
    error.integer) printf '%s\n' '%s must be a decimal integer (%s–%s).' ;;
    error.range) printf '%s\n' '%s must be in the range %s–%s.' ;;
    error.value) printf '%s\n' '%s requires a value.' ;;
    error.directory_count) printf '%s\n' 'Only one directory is allowed.' ;;
    error.option) printf '%s\n' 'Unknown option: %s' ;;
    error.missing) printf '%s\n' 'Path does not exist: %s' ;;
    error.directory) printf '%s\n' 'Not a directory: %s' ;;
    error.dependency) printf '%s\n' 'Required command is missing: %s' ;;
    error.interrupted) printf '%s\n' 'Scan interrupted; results may be incomplete.' ;;
    error.partial) printf '%s\n' 'Incomplete scan; some directories could not be read or du failed.' ;;
    error.pipeline) printf '%s\n' 'Sorting or truncating output failed.' ;;
    label.depth) printf '%s\n' 'depth' ;;
    label.lines) printf '%s\n' 'line count' ;;
    completion.depth) printf '%s\n' 'Display depth, default 2' ;;
    completion.lines) printf '%s\n' 'Maximum lines, default 25' ;;
    completion.help) printf '%s\n' 'Show help' ;;
    completion.version) printf '%s\n' 'Show version' ;;
    completion.directory) printf '%s\n' 'directory' ;;
    *) return 1 ;;
  esac
}
MAC_SHELL_TOOLS_EMBEDDED_FILE_7D4C
  mkdir -p "$stage/payload/tools/dsize/locales" || return 1
  cat > "$stage/payload/tools/dsize/locales/zh-CN.sh" <<'MAC_SHELL_TOOLS_EMBEDDED_FILE_7D4C' || return 1
# mst_text_zh_CN message catalog.
mst_text_zh_CN() {
  case $1 in
    help) printf '%s\n' '用法：dsize [目录] [选项]

查看目录占用汇总中最大的条目，按大小升序输出，最大条目在最后。
默认目录为 .，默认深度为 2，默认最多显示 25 条。

  -d N, --depth N, --depth=N  显示深度，十进制整数 0–1000
  -n N, --lines N, --lines=N  最大行数，十进制整数 1–1000000
  -V, --version              查看已加载工具的版本
  -h, --help                 显示帮助
  --                         停止解析选项，后面至多一个目录

目录和选项可交错；同一选项重复时最后一次生效。支持前导零。
深度只限制显示层级，计算总量仍会遍历更深内容。
结果是目录占用汇总，文件大小计入所属目录，不逐个列出文件。
父目录包含子目录，不能将输出相加；这里只统计磁盘占用，不清理文件。
退出码：0 成功或帮助，2 参数错误，1 扫描不完整或依赖执行失败。' ;;
    error.integer) printf '%s\n' '%s必须是十进制整数（%s–%s）。' ;;
    error.range) printf '%s\n' '%s范围为 %s–%s。' ;;
    error.value) printf '%s\n' '%s 缺少数值。' ;;
    error.directory_count) printf '%s\n' '只允许一个目录。' ;;
    error.option) printf '%s\n' '未知选项 %s。' ;;
    error.missing) printf '%s\n' '路径不存在：%s' ;;
    error.directory) printf '%s\n' '不是目录：%s' ;;
    error.dependency) printf '%s\n' '缺少命令 %s。' ;;
    error.interrupted) printf '%s\n' '扫描已中断，结果可能不完整。' ;;
    error.partial) printf '%s\n' '不完整扫描；部分目录无法读取或 du 执行失败。' ;;
    error.pipeline) printf '%s\n' '排序或截取输出失败。' ;;
    label.depth) printf '%s\n' '深度' ;;
    label.lines) printf '%s\n' '条数' ;;
    completion.depth) printf '%s\n' '显示深度，默认 2' ;;
    completion.lines) printf '%s\n' '最大行数，默认 25' ;;
    completion.help) printf '%s\n' '显示帮助' ;;
    completion.version) printf '%s\n' '显示版本' ;;
    completion.directory) printf '%s\n' '目录' ;;
    *) return 1 ;;
  esac
}
MAC_SHELL_TOOLS_EMBEDDED_FILE_7D4C
  mkdir -p "$stage/payload/tools/dsize" || return 1
  cat > "$stage/payload/tools/dsize/files.list" <<'MAC_SHELL_TOOLS_EMBEDDED_FILE_7D4C' || return 1
dsize.zsh
version
i18n.sh
locales/en.sh
locales/zh-CN.sh
MAC_SHELL_TOOLS_EMBEDDED_FILE_7D4C
}

tool_files=' dsize.zsh'
MAC_SHELL_TOOLS_MANAGER_7D4C
}
bootstrap_main "$@"
