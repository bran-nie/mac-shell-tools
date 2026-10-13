# Manage npm packages in a shared prefix using the currently active Node/npm.
_mac_shell_tools_npmg_language() (
  emulate -L zsh
  local component_directory=${${(%):-%x}:A:h}
  local common="$component_directory/i18n.sh"
  if [[ ! -f $common ]]; then common="$component_directory/../../lib/i18n.sh"; fi
  source "$common" || return 1
  mst_resolve_language "$component_directory/../../config.conf" "${MST_LANG:-}"
)

_mac_shell_tools_npmg_message() (
  emulate -L zsh
  local component_directory=${${(%):-%x}:A:h}
  local common="$component_directory/i18n.sh"
  if [[ ! -f $common ]]; then common="$component_directory/../../lib/i18n.sh"; fi
  source "$common" || return 1
  source "$component_directory/locales/en.sh" || return 1
  unfunction mst_text_zh_CN 2>/dev/null || true
  if [[ ${npmg_language:-en} == zh-CN && -f "$component_directory/locales/zh-CN.sh" ]]; then
    source "$component_directory/locales/zh-CN.sh" || return 1
  fi
  case $1 in error.*) printf 'npmg: ' ;; esac
  mst_print_message "${npmg_language:-en}" "$@"
)

_mac_shell_tools_npmg_version() {
  local version='@MST_VERSION@' revision='@MST_REVISION@' source_state='@MST_STATE@'
  case $version in @*) version=development; revision=unbuilt; source_state=unknown ;; esac
  print -r -- "npmg $version ($revision; $source_state)"
}

_mac_shell_tools_npmg_config_file() {
  emulate -L zsh
  local component_directory=${${(%):-%x}:A:h} config_file
  if [[ -f "$component_directory/i18n.sh" ]]; then
    config_file="$component_directory/../../npmg.conf"
  else
    config_file="${XDG_CONFIG_HOME:-$HOME/.config}/zsh/mac-shell-tools/npmg.conf"
  fi
  # Normalize .. without resolving a final symlink, which must be rejected.
  print -r -- "${config_file:a}"
}

_mac_shell_tools_npmg_prefix() (
  emulate -L zsh
  local config_file line prefix="$HOME/.local/npm" line_count=0
  local is_invalid_saved_prefix=0
  config_file=$(_mac_shell_tools_npmg_config_file) || return 2
  if [[ -L "$config_file" ]]; then
    _mac_shell_tools_npmg_message error.config_file "$config_file" >&2
    return 2
  fi
  if [[ -e "$config_file" ]]; then
    # A present configuration must be a readable regular data file.
    local can_read_config=0
    if [[ -f "$config_file" && -r "$config_file" ]]; then can_read_config=1; fi
    if (( ! can_read_config )); then
      _mac_shell_tools_npmg_message error.config_file "$config_file" >&2
      return 2
    fi
    while IFS= read -r line || [[ -n $line ]]; do
      (( line_count++ ))
      case $line in
        prefix=/*) prefix=${line#prefix=} ;;
        *) _mac_shell_tools_npmg_message error.config_file "$config_file" >&2; return 2 ;;
      esac
    done < "$config_file"
    if (( line_count != 1 )) || [[ $prefix == *:* || $prefix == *$'\r'* ]]; then
      is_invalid_saved_prefix=1
    fi
    if (( is_invalid_saved_prefix )); then
      _mac_shell_tools_npmg_message error.config_file "$config_file" >&2
      return 2
    fi
  fi
  print -r -- "$prefix"
)

_mac_shell_tools_npmg_activate_prefix() {
  emulate -L zsh
  local npmg_bin="${1%/}/bin" previous_bin=${_MAC_SHELL_TOOLS_NPMG_BIN:-} entry
  local -a retained_path
  # Remove only the previous entry added by npmg, preserving user-owned paths.
  local should_replace_managed_bin=0
  if [[ -n $previous_bin && $previous_bin != "$npmg_bin" ]]; then
    should_replace_managed_bin=1
  fi
  if (( should_replace_managed_bin )); then
    for entry in "${path[@]}"; do
      if [[ $entry == "$previous_bin" ]]; then continue; fi
      retained_path+=( "$entry" )
    done
    path=( "${retained_path[@]}" )
    unset _MAC_SHELL_TOOLS_NPMG_BIN
  fi
  if (( ! ${path[(Ie)$npmg_bin]} )); then
    path+=( "$npmg_bin" )
    typeset -g _MAC_SHELL_TOOLS_NPMG_BIN="$npmg_bin"
  fi
  export PATH
}

_mac_shell_tools_npmg_write_prefix() (
  emulate -L zsh
  local config_file=$1 prefix=$2 config_directory=${1:h} temporary_file dependency
  local is_invalid_config_target=0
  # Refuse links and non-files rather than replacing a user-owned resource.
  if [[ -L "$config_file" || ( -e "$config_file" && ! -f "$config_file" ) ]]; then
    is_invalid_config_target=1
  fi
  if (( is_invalid_config_target )); then
    _mac_shell_tools_npmg_message error.config_file "$config_file" >&2
    return 2
  fi
  for dependency in mkdir mktemp mv rm; do
    if ! command -v "$dependency" >/dev/null 2>&1; then
      _mac_shell_tools_npmg_message error.config_dependency "$dependency" >&2
      return 1
    fi
  done
  umask 077
  command mkdir -p -- "$config_directory" || {
    _mac_shell_tools_npmg_message error.config_write "$config_file" >&2; return 1
  }
  temporary_file=$(command mktemp "$config_directory/.npmg.conf.XXXXXX") || {
    _mac_shell_tools_npmg_message error.config_write "$config_file" >&2; return 1
  }
  trap 'command rm -f -- "$temporary_file"' EXIT
  trap 'exit 1' HUP INT TERM
  if ! print -r -- "prefix=$prefix" > "$temporary_file" ||
      ! command mv -f -- "$temporary_file" "$config_file"; then
    _mac_shell_tools_npmg_message error.config_write "$config_file" >&2
    return 1
  fi
)

_mac_shell_tools_npmg_config() {
  emulate -L zsh
  local config_file prefix value source_kind=default
  config_file=$(_mac_shell_tools_npmg_config_file) || return 2
  case ${1-} in
    show)
      if (( $# != 1 )); then _mac_shell_tools_npmg_message error.config_usage >&2; return 2; fi
      prefix=$(_mac_shell_tools_npmg_prefix) || return 2
      if [[ -f "$config_file" ]]; then source_kind=saved; fi
      _mac_shell_tools_npmg_message config.show "$prefix" "$source_kind" "$config_file" "${prefix%/}/bin"
      ;;
    prefix)
      case $# in
        1) _mac_shell_tools_npmg_prefix ;;
        2)
          case $2 in
            --reset)
              local is_invalid_config_target=0
              # Reset can repair malformed data, but never removes links/non-files.
              if [[ -L "$config_file" || ( -e "$config_file" && ! -f "$config_file" ) ]]; then
                is_invalid_config_target=1
              fi
              if (( is_invalid_config_target )); then
                _mac_shell_tools_npmg_message error.config_file "$config_file" >&2; return 2
              fi
              if [[ -f "$config_file" ]]; then
                command rm -f -- "$config_file" || {
                  _mac_shell_tools_npmg_message error.config_write "$config_file" >&2; return 1
                }
              fi
              prefix="$HOME/.local/npm"
              ;;
            *)
              value=$2
              # PATH cannot represent colons, and the data file uses one line.
              local is_invalid_prefix=0
              if [[ -z $value || $value == *:* || $value == *$'\n'* || $value == *$'\r'* ]]; then
                is_invalid_prefix=1
              fi
              if (( is_invalid_prefix )); then
                _mac_shell_tools_npmg_message error.prefix "$value" >&2; return 2
              fi
              case $value in
                '~') value=$HOME ;;
                '~/'*) value="$HOME/${value#\~/}" ;;
              esac
              prefix=${value:a}
              _mac_shell_tools_npmg_write_prefix "$config_file" "$prefix" || return $?
              ;;
          esac
          _mac_shell_tools_npmg_activate_prefix "$prefix"
          _mac_shell_tools_npmg_message config.saved "$prefix"
          ;;
        *) _mac_shell_tools_npmg_message error.config_usage >&2; return 2 ;;
      esac
      ;;
    *) _mac_shell_tools_npmg_message error.config_usage >&2; return 2 ;;
  esac
}

_mac_shell_tools_npmg_run() (
  emulate -L zsh
  local npmg_language npm_command=install dependency prefix
  local -a command_defaults
  npmg_language=$(_mac_shell_tools_npmg_language) || return 2
  if (( ! $# )); then _mac_shell_tools_npmg_message help; return 0; fi
  case $1 in
    -h|--help) _mac_shell_tools_npmg_message help; return 0 ;;
    -V|--version) _mac_shell_tools_npmg_version; return 0 ;;
    install|i) npm_command=install; shift ;;
    update|up) npm_command=update; shift ;;
    uninstall|rm) npm_command=uninstall; shift ;;
    list|ls) npm_command=ls; command_defaults=( --depth=0 ); shift ;;
    # All other arguments, including npm options and --, use shortcut install.
    *) npm_command=install ;;
  esac
  prefix=$(_mac_shell_tools_npmg_prefix) || return 2
  for dependency in node npm; do
    # npm is invoked as an external command; shell aliases/functions are not a runtime.
    if ! whence -p "$dependency" >/dev/null 2>&1; then
      _mac_shell_tools_npmg_message error.dependency "$dependency" >&2
      return 1
    fi
  done
  # Put defaults first so explicit npm flags can override them. Preserve argv,
  # streams and npm's status; package specs never pass through eval or a shell.
  command npm "$npm_command" -g --prefix "$prefix" "${command_defaults[@]}" "$@"
)

npmg() {
  emulate -L zsh
  case ${1-} in
    config)
      local npmg_language
      npmg_language=$(_mac_shell_tools_npmg_language) || return 2
      shift
      _mac_shell_tools_npmg_config "$@"
      ;;
    *) _mac_shell_tools_npmg_run "$@" ;;
  esac
}

_mac_shell_tools_npmg_complete_config() {
  local -a config_actions reset_actions
  case $CURRENT in
    2)
      config_actions=( "config:$(_mac_shell_tools_npmg_message completion.config)" )
      _describe "$command_label" config_actions
      ;;
    3)
      config_actions=(
        "prefix:$prefix_description"
        "show:$(_mac_shell_tools_npmg_message completion.show)"
      )
      _describe "$command_label" config_actions
      ;;
    4)
      case ${words[3]-} in
        prefix)
          # Dispatch before npm option completion so --reset is not discarded.
          case $PREFIX in
            -*)
              reset_actions=( "--reset:$(_mac_shell_tools_npmg_message completion.reset)" )
              _describe -t options "$prefix_description" reset_actions
              ;;
            *) _directories ;;
          esac
          ;;
      esac
      ;;
  esac
}

_npmg() {
  setopt localoptions
  local npmg_language state state_descr line
  local curcontext="$curcontext"
  local -A opt_args
  local help_description version_description command_label package_label
  local prefix_description registry_description depth_description
  local -a actions
  npmg_language=$(_mac_shell_tools_npmg_language) || return 2
  help_description=$(_mac_shell_tools_npmg_message completion.help)
  version_description=$(_mac_shell_tools_npmg_message completion.version)
  # A subcommand's help/version belongs to npm; top-level flags belong to npmg.
  case ${words[2]-} in
    install|i|update|up|uninstall|rm|list|ls)
      help_description=$(_mac_shell_tools_npmg_message completion.npm_help)
      version_description=$(_mac_shell_tools_npmg_message completion.npm_version) ;;
  esac
  command_label=$(_mac_shell_tools_npmg_message completion.command)
  package_label=$(_mac_shell_tools_npmg_message completion.package)
  prefix_description=$(_mac_shell_tools_npmg_message completion.prefix)
  registry_description=$(_mac_shell_tools_npmg_message completion.registry)
  depth_description=$(_mac_shell_tools_npmg_message completion.depth)
  case ${words[2]-} in
    config)
      _mac_shell_tools_npmg_complete_config
      return $?
      ;;
  esac
  actions=(
    "install:$(_mac_shell_tools_npmg_message completion.install)"
    "i:$(_mac_shell_tools_npmg_message completion.install)"
    "update:$(_mac_shell_tools_npmg_message completion.update)"
    "up:$(_mac_shell_tools_npmg_message completion.update)"
    "uninstall:$(_mac_shell_tools_npmg_message completion.uninstall)"
    "rm:$(_mac_shell_tools_npmg_message completion.uninstall)"
    "list:$(_mac_shell_tools_npmg_message completion.list)"
    "ls:$(_mac_shell_tools_npmg_message completion.list)"
    "config:$(_mac_shell_tools_npmg_message completion.config)"
  )
  _arguments -C -S \
    "(-h --help)-h[$help_description]" \
    "(-h --help)--help[$help_description]" \
    "(-V --version)-V[$version_description]" \
    "(-V --version)--version[$version_description]" \
    "--prefix=[$prefix_description]:directory:_directories" \
    "--registry=[$registry_description]:URL:" \
    "--depth=[$depth_description]:depth:" \
    '--verbose' '--dry-run' '--json' \
    "1:$command_label:->command" \
    "*:$package_label:->package"
  case $state in
    command) _describe "$command_label" actions ;;
    # Do not query npm or the registry while completing package names.
    package) _message "$package_label" ;;
  esac
}

# Startup reads the data-only prefix without output. Commands report invalid
# configuration; loading never creates directories or changes Node selection.
() {
  emulate -L zsh
  local prefix
  prefix=$(_mac_shell_tools_npmg_prefix 2>/dev/null) || return 0
  _mac_shell_tools_npmg_activate_prefix "$prefix"
}

if (( $+functions[compdef] )); then
  compdef _npmg npmg
fi
