# Common aliases and an explicitly selected, user-owned Zsh configuration.
function _mac_shell_tools_aliases_language {
  (
    emulate -L zsh
    local component_directory=${${(%):-%x}:A:h}
    local common="$component_directory/i18n.sh"
    if [[ ! -f $common ]]; then common="$component_directory/../../lib/i18n.sh"; fi
    source "$common" || return 1
    mst_resolve_language "$component_directory/../../config.conf" "${MST_LANG:-}"
  )
}

function _mac_shell_tools_aliases_message {
  (
    emulate -L zsh
    local component_directory=${${(%):-%x}:A:h}
    local common="$component_directory/i18n.sh"
    if [[ ! -f $common ]]; then common="$component_directory/../../lib/i18n.sh"; fi
    source "$common" || return 1
    source "$component_directory/locales/en.sh" || return 1
    unfunction mst_text_zh_CN 2>/dev/null || true
    if [[ ${aliases_language:-en} == zh-CN && -f "$component_directory/locales/zh-CN.sh" ]]; then
      source "$component_directory/locales/zh-CN.sh" || return 1
    fi
    case $1 in error.*) printf 'aliases: ' ;; esac
    mst_print_message "${aliases_language:-en}" "$@"
  )
}

function _mac_shell_tools_aliases_version {
  local version='@MST_VERSION@' revision='@MST_REVISION@' source_state='@MST_STATE@'
  case $version in @*) version=development; revision=unbuilt; source_state=unknown ;; esac
  print -r -- "aliases $version ($revision; $source_state)"
}

function _mac_shell_tools_aliases_config_file {
  emulate -L zsh
  local component_directory=${${(%):-%x}:A:h} config_file
  if [[ -f "$component_directory/i18n.sh" ]]; then
    config_file="$component_directory/../../aliases.conf"
  else
    config_file="${XDG_CONFIG_HOME:-$HOME/.config}/zsh/mac-shell-tools/aliases.conf"
  fi
  print -r -- "${config_file:a}"
}

function _mac_shell_tools_aliases_personal_file {
  emulate -L zsh
  local config_file line personal_file='' line_count=0 invalid_config=0
  config_file=$(_mac_shell_tools_aliases_config_file) || return 2
  # A saved path must come from readable data, never an indirect linked target.
  if [[ -L $config_file || ( -e $config_file && ( ! -f $config_file || ! -r $config_file ) ) ]]; then
    invalid_config=1
  fi
  if (( invalid_config )); then
    _mac_shell_tools_aliases_message error.config_file "$config_file" >&2; return 2
  fi
  if [[ -e $config_file ]]; then
    while IFS= read -r line || [[ -n $line ]]; do
      (( line_count++ ))
      case $line in
        file=/*) personal_file=${line#file=} ;;
        *) _mac_shell_tools_aliases_message error.config_file "$config_file" >&2; return 2 ;;
      esac
    done < "$config_file"
    # Exactly one line prevents extra instructions or ambiguous duplicate values.
    if (( line_count != 1 )) || [[ $personal_file == *$'\r'* ]]; then
      _mac_shell_tools_aliases_message error.config_file "$config_file" >&2; return 2
    fi
  fi
  print -r -- "$personal_file"
}

function _mac_shell_tools_aliases_validate_personal {
  emulate -L zsh
  [[ -n $1 ]] || return 0
  # Personal dotfiles may be symlinks. Only the saved, data-only setting refuses them.
  if [[ ! -f $1 || ! -r $1 ]]; then
    _mac_shell_tools_aliases_message error.personal_file "$1" >&2; return 2
  fi
  if ! command zsh -fn -- "$1"; then
    _mac_shell_tools_aliases_message error.personal_syntax "$1" >&2; return 2
  fi
}

function _mac_shell_tools_aliases_write_config {
  (
    emulate -L zsh
    local config_file=$1 value=$2 temporary_file dependency
    # Avoid replacing a resource owned indirectly through a link or directory.
    local invalid_target=0
    if [[ -L $config_file || ( -e $config_file && ! -f $config_file ) ]]; then invalid_target=1; fi
    if (( invalid_target )); then
      _mac_shell_tools_aliases_message error.config_file "$config_file" >&2; return 2
    fi
    for dependency in mkdir mktemp mv rm; do
      if ! whence -p "$dependency" >/dev/null; then
        _mac_shell_tools_aliases_message error.dependency "$dependency" >&2; return 1
      fi
    done
    umask 077
    command mkdir -p -- "${config_file:h}" || return 1
    temporary_file=$(command mktemp "${config_file:h}/.aliases.conf.XXXXXX") || return 1
    trap 'command rm -f -- "$temporary_file"' EXIT
    trap 'exit 1' HUP INT TERM
    if ! print -r -- "file=$value" > "$temporary_file" ||
        ! command mv -f -- "$temporary_file" "$config_file"; then
      _mac_shell_tools_aliases_message error.config_write "$config_file" >&2; return 1
    fi
  )
}

# These helpers exchange associative arrays through Zsh's dynamic local scope.
# Presence is separate from the value: an empty alias is still a definition.
function _mac_shell_tools_aliases_snapshot {
  local mst_alias_name
  mst_alias_snapshot=()
  for mst_alias_name in "${(@k)aliases}"; do
    mst_alias_snapshot[alias:$mst_alias_name]=$aliases[$mst_alias_name]
  done
  for mst_alias_name in "${(@k)functions}"; do
    mst_alias_snapshot[function:$mst_alias_name]=$functions[$mst_alias_name]
  done
}

function _mac_shell_tools_aliases_set_definition {
  local mst_alias_name=${1#*:}
  case ${1%%:*} in
    alias)
      case $2 in
        present) aliases[$mst_alias_name]=$3 ;;
        absent) unset "aliases[$mst_alias_name]" ;;
      esac ;;
    function)
      case $2 in
        present) functions[$mst_alias_name]=$3 ;;
        absent) unset "functions[$mst_alias_name]" ;;
      esac ;;
  esac
}

function _mac_shell_tools_aliases_restore {
  local mst_alias_key same_definition
  local -aU mst_alias_keys=( "${(@k)mst_alias_snapshot}" "${(@k)mst_alias_restore}" )
  for mst_alias_key in "${mst_alias_keys[@]}"; do
    same_definition=0
    if [[ ${+mst_alias_snapshot[$mst_alias_key]} == ${+mst_alias_restore[$mst_alias_key]} &&
          ${mst_alias_snapshot[$mst_alias_key]-} == "${mst_alias_restore[$mst_alias_key]-}" ]]; then
      same_definition=1
    fi
    (( same_definition )) && continue
    if (( ${+mst_alias_restore[$mst_alias_key]} )); then
      _mac_shell_tools_aliases_set_definition "$mst_alias_key" present "$mst_alias_restore[$mst_alias_key]"
    else
      _mac_shell_tools_aliases_set_definition "$mst_alias_key" absent
    fi
  done
}

function _mac_shell_tools_aliases_load {
  emulate -L zsh
  local mst_alias_file mst_alias_key mst_alias_name same_definition load_result
  local -A mst_alias_snapshot mst_alias_restore mst_alias_before mst_alias_baseline
  local -A mst_alias_rows mst_alias_owned mst_alias_applied mst_alias_previous
  local -A mst_alias_released=( "${(@kv)_MAC_SHELL_TOOLS_ALIASES_RELEASED}" )
  local -A mst_alias_defaults=( ll 'ls -alh' duls 'du -h -d 1 -c' )
  local -aU mst_alias_keys
  mst_alias_file=$(_mac_shell_tools_aliases_personal_file) || return 2
  _mac_shell_tools_aliases_validate_personal "$mst_alias_file" || return $?
  _mac_shell_tools_aliases_snapshot
  mst_alias_before=( "${(@kv)mst_alias_snapshot}" )
  mst_alias_restore=( "${(@kv)mst_alias_snapshot}" )

  # A later manual change releases the whole command name, including a switch
  # from alias to function. Keep that name untouched for the rest of this session.
  for mst_alias_key in "${(@k)_MAC_SHELL_TOOLS_ALIASES_OWNED}"; do
    if [[ ${+mst_alias_snapshot[$mst_alias_key]} != ${+_MAC_SHELL_TOOLS_ALIASES_APPLIED[$mst_alias_key]} ||
          ${mst_alias_snapshot[$mst_alias_key]-} != "${_MAC_SHELL_TOOLS_ALIASES_APPLIED[$mst_alias_key]-}" ]]; then
      mst_alias_released[${mst_alias_key#*:}]=1
    fi
  done
  for mst_alias_key in "${(@k)_MAC_SHELL_TOOLS_ALIASES_OWNED}"; do
    (( ${+mst_alias_released[${mst_alias_key#*:}]} )) && continue
    if (( ${+_MAC_SHELL_TOOLS_ALIASES_PREVIOUS[$mst_alias_key]} )); then
      mst_alias_restore[$mst_alias_key]=$_MAC_SHELL_TOOLS_ALIASES_PREVIOUS[$mst_alias_key]
    else
      unset "mst_alias_restore[$mst_alias_key]"
    fi
  done
  _mac_shell_tools_aliases_restore
  mst_alias_baseline=( "${(@kv)mst_alias_restore}" )

  # This is an explicitly trusted Zsh file, unlike aliases.conf. Source it once
  # per load, before defaults, so a personal function named ll is not shadowed.
  load_result=0
  if [[ -n $mst_alias_file ]]; then
    source "$mst_alias_file" || load_result=$?
  fi
  _mac_shell_tools_aliases_snapshot
  if (( load_result )); then
    mst_alias_restore=( "${(@kv)mst_alias_before}" )
    _mac_shell_tools_aliases_restore
    _mac_shell_tools_aliases_message error.personal_load "$mst_alias_file" "$load_result" >&2
    return 1
  fi
  mst_alias_keys=( "${(@k)mst_alias_baseline}" "${(@k)mst_alias_snapshot}" )
  for mst_alias_key in "${mst_alias_keys[@]}"; do
    same_definition=0
    if [[ ${+mst_alias_baseline[$mst_alias_key]} == ${+mst_alias_snapshot[$mst_alias_key]} &&
          ${mst_alias_baseline[$mst_alias_key]-} == "${mst_alias_snapshot[$mst_alias_key]-}" ]]; then
      same_definition=1
    fi
    (( same_definition )) && continue
    mst_alias_rows[$mst_alias_key]=personal
    mst_alias_owned[$mst_alias_key]=1
  done
  for mst_alias_name in "${(@k)mst_alias_defaults}"; do
    mst_alias_key=alias:$mst_alias_name
    # Explicit personal changes, including removals, take priority over defaults.
    (( ${+mst_alias_rows[$mst_alias_key]} )) && continue
    mst_alias_rows[$mst_alias_key]=builtin
    if (( ! ${+aliases[$mst_alias_name]} && ! ${+functions[$mst_alias_name]} &&
          ! ${+mst_alias_released[$mst_alias_name]} )); then
      aliases[$mst_alias_name]=$mst_alias_defaults[$mst_alias_name]
      mst_alias_owned[$mst_alias_key]=1
    fi
  done
  _mac_shell_tools_aliases_snapshot
  for mst_alias_key in "${(@k)mst_alias_owned}"; do
    if (( ${+mst_alias_snapshot[$mst_alias_key]} )); then
      mst_alias_applied[$mst_alias_key]=$mst_alias_snapshot[$mst_alias_key]
    fi
    if (( ${+mst_alias_baseline[$mst_alias_key]} )); then
      mst_alias_previous[$mst_alias_key]=$mst_alias_baseline[$mst_alias_key]
    fi
  done
  mst_alias_restore=( "${(@kv)mst_alias_snapshot}" )
  for mst_alias_name in "${(@k)mst_alias_released}"; do
    for mst_alias_key in alias:$mst_alias_name function:$mst_alias_name; do
      if (( ${+mst_alias_before[$mst_alias_key]} )); then
        mst_alias_restore[$mst_alias_key]=$mst_alias_before[$mst_alias_key]
      else
        unset "mst_alias_restore[$mst_alias_key]"
      fi
    done
  done
  _mac_shell_tools_aliases_restore
  _MAC_SHELL_TOOLS_ALIASES_ROWS=( "${(@kv)mst_alias_rows}" )
  _MAC_SHELL_TOOLS_ALIASES_OWNED=( "${(@kv)mst_alias_owned}" )
  _MAC_SHELL_TOOLS_ALIASES_APPLIED=( "${(@kv)mst_alias_applied}" )
  _MAC_SHELL_TOOLS_ALIASES_PREVIOUS=( "${(@kv)mst_alias_previous}" )
  _MAC_SHELL_TOOLS_ALIASES_RELEASED=( "${(@kv)mst_alias_released}" )
  typeset -g _MAC_SHELL_TOOLS_ALIASES_LOADED_FILE=$mst_alias_file
  return 0
}

function _mac_shell_tools_aliases_reload {
  local load_result=0
  if (( ${_MAC_SHELL_TOOLS_ALIASES_LOADING:-0} )); then
    _mac_shell_tools_aliases_message error.recursive >&2; return 2
  fi
  local _MAC_SHELL_TOOLS_ALIASES_LOADING=1
  _mac_shell_tools_aliases_load || load_result=$?
  typeset -g _MAC_SHELL_TOOLS_ALIASES_LAST_RESULT=$load_result
  return $load_result
}

function _mac_shell_tools_aliases_row_state {
  local key=$1 name=${1#*:}
  # Both existence and content matter: a removed alias differs from an empty one.
  if (( ${+_MAC_SHELL_TOOLS_ALIASES_RELEASED[$name]} )); then
    print -r -- overridden
  elif (( ! ${+_MAC_SHELL_TOOLS_ALIASES_OWNED[$key]} )); then
    print -r -- skipped
  elif [[ ${+mst_alias_snapshot[$key]} != ${+_MAC_SHELL_TOOLS_ALIASES_APPLIED[$key]} ||
          ${mst_alias_snapshot[$key]-} != "${_MAC_SHELL_TOOLS_ALIASES_APPLIED[$key]-}" ]]; then
    print -r -- overridden
  elif (( ! ${+mst_alias_snapshot[$key]} )); then
    print -r -- removed
  elif [[ $key == function:* ]] && (( ${+aliases[$name]} )); then
    print -r -- shadowed
  else
    print -r -- active
  fi
}

function _mac_shell_tools_aliases_list {
  local key name kind row_state definition found=0
  local -A mst_alias_snapshot
  _mac_shell_tools_aliases_snapshot
  if (( ! $# )); then _mac_shell_tools_aliases_message list.header; fi
  for key in "${(@ok)_MAC_SHELL_TOOLS_ALIASES_ROWS}"; do
    name=${key#*:}; kind=${key%%:*}
    if (( $# )) && [[ $name != "$1" ]]; then continue; fi
    found=1
    row_state=$(_mac_shell_tools_aliases_row_state "$key")
    definition=${mst_alias_snapshot[$key]-}
    if (( $# )); then
      _mac_shell_tools_aliases_message show.header "$name" "$kind" \
        "$(_mac_shell_tools_aliases_message source.$_MAC_SHELL_TOOLS_ALIASES_ROWS[$key])" \
        "$(_mac_shell_tools_aliases_message state.$row_state)"
      if (( ! ${+mst_alias_snapshot[$key]} )); then
        _mac_shell_tools_aliases_message show.absent
        continue
      fi
      case $kind in
        alias) print -r -- "alias ${(q)name}=${(qq)definition}" ;;
        function) print -r -- "function ${(q)name} {"$'\n'"$definition"$'\n}' ;;
      esac
    else
      # Display control characters visibly while keeping ordinary spaces readable.
      printf '%-18s %-9s %-12s %-14s %s\n' "$name" "$kind" \
        "$(_mac_shell_tools_aliases_message source.$_MAC_SHELL_TOOLS_ALIASES_ROWS[$key])" \
        "$(_mac_shell_tools_aliases_message state.$row_state)" "${(V)definition}"
    fi
  done
  if (( $# && ! found )); then
    _mac_shell_tools_aliases_message error.unknown "$1" >&2; return 2
  fi
  if (( ${_MAC_SHELL_TOOLS_ALIASES_LAST_RESULT:-0} )); then
    _mac_shell_tools_aliases_message error.last_load >&2; return 1
  fi
  return 0
}

function _mac_shell_tools_aliases_config {
  local config_file personal_file value invalid_target=0
  config_file=$(_mac_shell_tools_aliases_config_file) || return 2
  case ${1-}:$# in
    show:1)
      personal_file=$(_mac_shell_tools_aliases_personal_file) || return 2
      _mac_shell_tools_aliases_message config.show "$config_file" "${personal_file:--}" \
        "${_MAC_SHELL_TOOLS_ALIASES_LOADED_FILE:--}" "${_MAC_SHELL_TOOLS_ALIASES_LAST_RESULT:-0}"
      ;;
    file:1) _mac_shell_tools_aliases_personal_file ;;
    file:2)
      case $2 in
        --reset)
          # Reset repairs malformed contents, but must not remove a linked resource.
          if [[ -L $config_file || ( -e $config_file && ! -f $config_file ) ]]; then
            invalid_target=1
          fi
          if (( invalid_target )); then
            _mac_shell_tools_aliases_message error.config_file "$config_file" >&2; return 2
          fi
          if [[ -e $config_file ]]; then
            command rm -f -- "$config_file" || return 1
          fi
          ;;
        *)
          value=$2
          # The saved pointer occupies one data record; line breaks cannot round-trip.
          if [[ -z $value || $value == *$'\n'* || $value == *$'\r'* ]]; then
            _mac_shell_tools_aliases_message error.path "$value" >&2; return 2
          fi
          case $value in '~') value=$HOME ;; '~/'*) value="$HOME/${value#\~/}" ;; esac
          value=${value:a}
          _mac_shell_tools_aliases_validate_personal "$value" || return $?
          _mac_shell_tools_aliases_write_config "$config_file" "$value" || return $?
          ;;
      esac
      _mac_shell_tools_aliases_message config.saved
      ;;
    *) _mac_shell_tools_aliases_message error.config_usage >&2; return 2 ;;
  esac
}

function aliases {
  emulate -L zsh
  local aliases_language
  aliases_language=$(_mac_shell_tools_aliases_language) || return 2
  case ${1-}:$# in
    :0|-h:1|--help:1) _mac_shell_tools_aliases_message help ;;
    -V:1|--version:1) _mac_shell_tools_aliases_version ;;
    list:1) _mac_shell_tools_aliases_list ;;
    show:2) _mac_shell_tools_aliases_list "$2" ;;
    reload:1)
      _mac_shell_tools_aliases_reload || return $?
      _mac_shell_tools_aliases_message reloaded
      ;;
    config:*) shift; _mac_shell_tools_aliases_config "$@" ;;
    *) _mac_shell_tools_aliases_message error.usage >&2; return 2 ;;
  esac
}

function _aliases {
  setopt localoptions
  local aliases_language key action command_label
  local -a actions names
  aliases_language=$(_mac_shell_tools_aliases_language) || return 2
  command_label=$(_mac_shell_tools_aliases_message completion.command)
  case $CURRENT in
    2)
      for action in list show reload config; do
        actions+=( "$action:$(_mac_shell_tools_aliases_message completion.$action)" )
      done
      actions+=( "--help:$(_mac_shell_tools_aliases_message completion.help)"
                 "--version:$(_mac_shell_tools_aliases_message completion.version)" )
      _describe "$command_label" actions
      ;;
    3)
      case ${words[2]-} in
        show)
          for key in "${(@k)_MAC_SHELL_TOOLS_ALIASES_ROWS}"; do names+=( "${key#*:}" ); done
          compadd -- "${names[@]}"
          ;;
        config)
          actions=( "file:$(_mac_shell_tools_aliases_message completion.file)"
                    "show:$(_mac_shell_tools_aliases_message completion.config_show)" )
          _describe "$command_label" actions
          ;;
      esac ;;
    4)
      case ${words[2]-}:${words[3]-} in
        config:file)
          case $PREFIX in
            -*) actions=( "--reset:$(_mac_shell_tools_aliases_message completion.reset)" ); _describe "$command_label" actions ;;
            *) _files ;;
          esac ;;
      esac ;;
  esac
}

# Preserve ownership between repeated source/reload calls in the same shell.
typeset -gA _MAC_SHELL_TOOLS_ALIASES_ROWS _MAC_SHELL_TOOLS_ALIASES_OWNED
typeset -gA _MAC_SHELL_TOOLS_ALIASES_APPLIED _MAC_SHELL_TOOLS_ALIASES_PREVIOUS
typeset -gA _MAC_SHELL_TOOLS_ALIASES_RELEASED
() {
  emulate -L zsh
  _mac_shell_tools_aliases_reload >/dev/null 2>&1 || true
}
if (( $+functions[compdef] )); then
  compdef _aliases aliases
fi
