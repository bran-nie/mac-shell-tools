#!/bin/sh
# mac-shell-tools runtime v2
# 引导安装与常驻 mst 共用的管理逻辑；工具仓库通过独立文件同步。
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
    if contains_file "$tool_files" "$listed_file"; then
      case $invocation_mode in
        bootstrap) available_version=$package_version ;;
        installed)
          listed_component=$(available_component "$listed_file")
          check_directory "$listed_component"
          read_version_file "$listed_component/version" 3
          available_version=$bundle_version ;;
      esac
    fi
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
    printf 'main %s %s %s %s %s "$@"\n' "$quoted_core" "''" "$quoted_root" "$quoted_rc" "''"
  } > "$stage/mst.sh"
  /bin/sh -n "$stage/mst.sh" || fail error.syntax "$stage/mst.sh"
  zsh -f -n "$stage/payload/manager/mst.zsh" || fail error.syntax "$stage/payload/manager/mst.zsh"
  /bin/sh -n "$manager_source" || fail error.syntax "$manager_source"
  printf '%s\n%s\n%s\n' "$package_version" "$package_revision" "$package_state" > "$stage/manager-version"
}

write_manager() {
  write_file "$manager_source" "$manager_directory/manager-core.sh"
  write_file "$stage/mst.sh" "$manager_directory/mst.sh"
  for manager_asset in mst.zsh i18n.sh repository.sh LICENSE locales/en.sh locales/zh-CN.sh; do
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
  if [ -f "$target" ]; then
    cp -p "$target" "$pending_file" || fail error.write "$target"
  else
    cp -p "$prepared" "$pending_file" || fail error.write "$target"
  fi
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


message() {
  if command -v mst_print_message >/dev/null 2>&1; then
    mst_print_message "$language" "$@"
  else
    printf '%s\n' "$*"
  fi
}

load_manager_catalogs() {
  case $invocation_mode in
    bootstrap)
      runtime_library="$source_directory/lib"
      runtime_locales="$source_directory/locales" ;;
    installed)
      runtime_library=${manager_source%/*}
      runtime_locales="$runtime_library/locales" ;;
  esac
  for runtime_asset in "$runtime_library/i18n.sh" "$runtime_library/repository.sh" "$runtime_locales/en.sh" "$runtime_locales/zh-CN.sh"; do
    check_file "$runtime_asset"
  done
  for runtime_asset in "$runtime_library/i18n.sh" "$runtime_library/repository.sh" "$runtime_locales/en.sh"; do
    [ -f "$runtime_asset" ] || fail error.metadata "$runtime_asset"
    . "$runtime_asset"
  done
  unset -f mst_text_zh_CN
  if [ -f "$runtime_locales/zh-CN.sh" ]; then . "$runtime_locales/zh-CN.sh"; fi
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
  check_directory "$component_target"
  prepare_obsolete_assets
  while IFS= read -r obsolete_asset; do
    check_managed_parents "$component_target/$obsolete_asset"
    check_file "$component_target/$obsolete_asset"
    if [ -f "$component_target/$obsolete_asset" ]; then preflight_target "$component_target/$obsolete_asset"; fi
  done < "$stage/obsolete-assets"
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

prepare_obsolete_assets() {
  : > "$stage/obsolete-assets"
  check_file "$component_target/files.list"
  if [ -f "$component_target/files.list" ]; then
    validate_assets "$component_target/files.list"
    awk 'NR == FNR {keep[$0]=1; next} !($0 in keep)' "$component_source/files.list" \
      "$component_target/files.list" > "$stage/obsolete-assets"
  fi
}

write_component() {
  component_source=$1
  component_target=$2
  prepare_obsolete_assets
  while IFS= read -r obsolete_asset; do remove_file "$component_target/$obsolete_asset"; done < "$stage/obsolete-assets"
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
  repository_directory="$install_directory/repository"
  backup_directory="$install_directory/backups"
  state_file="$tools_directory/installed.list"
  settings_file="$install_directory/config.conf"
  check_directory "$install_directory"
  check_directory "$manager_directory"
  check_directory "$tools_directory"
  check_directory "$repository_directory"
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
  source_directory=$5
  shift 5
  invocation_mode=installed
  if [ -n "$source_directory" ]; then invocation_mode=bootstrap; fi
  load_manager_catalogs
  case $invocation_mode in
    bootstrap) read_version_file "$source_directory/package.meta" 4 ;;
    installed) read_version_file "${manager_source%/*}/version" 3 ;;
  esac
  package_version=$bundle_version
  package_revision=$bundle_revision
  package_state=$bundle_state
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
  parse_arguments "$@"
  if [ "$invocation_mode" = installed ] && [ "$action" = setup ]; then action=help; fi
  case $action in
    help) usage; return 0 ;;
    version) printf 'mst %s (%s; %s)\n' "$package_version" "$package_revision" "$package_state"; return 0 ;;
    config) configure_language; return 0 ;;
    setup|install|update|upgrade|uninstall|list) ;;
  esac
  for dependency in uname zsh mkdir mktemp cat awk sed cmp cp mv date rm rmdir chmod; do
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
  # Upgrade also repairs a missing or damaged local repository. The downloaded
  # source validates installed records before writes, so no cached catalog is needed.
  case "$invocation_mode:$action" in installed:upgrade) fetch_release "$@" ;; esac
  case $invocation_mode in
    bootstrap) load_source_catalog ;;
    installed) load_local_catalog ;;
  esac
  read_installed
  case $invocation_mode in
    installed)
      case $action in
        upgrade) ;;
        update)
          for checked_file in $requested_files; do
            contains_file "$installed_files" "$checked_file" || usage_error error.not_installed "${checked_file%.zsh}"
          done
          if [ -z "$installed_files" ]; then message info.empty; return 0; fi
          fetch_release "$@" ;;
        setup|install|uninstall|list) ;;
      esac ;;
    bootstrap) ;;
  esac
  select_files
  write_manager_runtime=no
  write_repository_runtime=no
  case $action in
    list) list_tools; return 0 ;;
    setup|upgrade|install)
      if [ "$invocation_mode" = bootstrap ]; then
        write_manager_runtime=yes
        write_repository_runtime=yes
      fi ;;
    update)
      if [ -z "$installed_files" ]; then message info.empty; return 0; fi
      if [ "$invocation_mode" = bootstrap ]; then write_repository_runtime=yes; fi ;;
    uninstall)
      if [ -z "$selected_files" ] && [ "$migrating" = no ]; then message info.no_tools; return 0; fi ;;
  esac
  if [ "$migrating" = yes ]; then write_manager_runtime=yes; fi
  ensure_directory "$install_directory"
  ensure_directory "$zdot_directory"
  install_directory=$(CDPATH= cd -P "$install_directory" && pwd) || fail error.enter "$install_directory"
  zdot_directory=$(CDPATH= cd -P "$zdot_directory" && pwd) || fail error.enter "$zdot_directory"
  zshrc="$zdot_directory/.zshrc"
  tools_directory="$install_directory/tools"
  repository_directory="$install_directory/repository"
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
  case $invocation_mode in installed) load_local_catalog ;; bootstrap) ;; esac
  read_installed
  select_files
  ensure_directory "$tools_directory"
  ensure_directory "$backup_directory"
  if [ "$write_manager_runtime" = yes ]; then
    ensure_directory "$manager_directory/locales"
    for manager_file in manager-core.sh mst.sh mst.zsh i18n.sh repository.sh LICENSE locales/en.sh locales/zh-CN.sh version; do check_file "$manager_directory/$manager_file"; done
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
      yes)
        read_version_file "$stage/payload/tools/${recorded_file%.zsh}/version" 3
        printf '%s\t%s\t%s\t%s\n' "$recorded_file" "$bundle_version" "$bundle_revision" "$bundle_state" >> "$stage/next-state" ;;
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
    for manager_asset in mst.zsh i18n.sh repository.sh LICENSE locales/en.sh locales/zh-CN.sh; do
      preflight_write "$stage/payload/manager/$manager_asset" "$manager_directory/$manager_asset"
    done
  fi
  if [ "$write_repository_runtime" = yes ]; then
    prepare_component "$stage/payload/repository" "$repository_directory"
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
  if [ "$write_repository_runtime" = yes ]; then
    write_component "$stage/payload/repository" "$repository_directory"
  fi
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
