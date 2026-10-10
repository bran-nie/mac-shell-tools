# Query visible TCP listeners without changing processes or the caller's shell.
_mac_shell_tools_portwho_language() (
  emulate -L zsh
  local component_directory=${${(%):-%x}:A:h}
  local common="$component_directory/i18n.sh"
  if [[ ! -f $common ]]; then common="$component_directory/../../lib/i18n.sh"; fi
  source "$common" || return 1
  mst_resolve_language "$component_directory/../../config.conf" "${MST_LANG:-}"
)

_mac_shell_tools_portwho_message() (
  emulate -L zsh
  local component_directory=${${(%):-%x}:A:h}
  local common="$component_directory/i18n.sh"
  if [[ ! -f $common ]]; then common="$component_directory/../../lib/i18n.sh"; fi
  source "$common" || return 1
  source "$component_directory/locales/en.sh" || return 1
  unfunction mst_text_zh_CN 2>/dev/null || true
  if [[ ${portwho_language:-en} == zh-CN && -f "$component_directory/locales/zh-CN.sh" ]]; then
    source "$component_directory/locales/zh-CN.sh" || return 1
  fi
  case $1 in error.*) printf 'portwho: ' ;; esac
  mst_print_message "${portwho_language:-en}" "$@"
)

_mac_shell_tools_portwho_version() {
  local version='@MST_VERSION@' revision='@MST_REVISION@' source_state='@MST_STATE@'
  case $version in @*) version=development; revision=unbuilt; source_state=unknown ;; esac
  print -r -- "portwho $version ($revision; $source_state)"
}

portwho() (
  emulate -L zsh
  setopt extendedglob
  local portwho_language value dependency query_directory query_status selector=-iTCP
  local parse_options=1
  local -a ports
  portwho_language=$(_mac_shell_tools_portwho_language) || return 2
  while (( $# )); do
    if (( parse_options )); then
      case $1 in
        -h|--help) _mac_shell_tools_portwho_message help; return 0 ;;
        -V|--version) _mac_shell_tools_portwho_version; return 0 ;;
        --) parse_options=0; shift; continue ;;
        -*) _mac_shell_tools_portwho_message error.option "$1" >&2; return 2 ;;
      esac
    fi
    value=$1
    if [[ -z $value || $value == *[^0-9]* ]]; then
      _mac_shell_tools_portwho_message error.port "$value" >&2
      return 2
    fi
    # Bound the normalized decimal string before arithmetic to avoid overflow.
    value=${value##0#}
    value=${value:-0}
    if (( ${#value} > 5 )) || (( value < 1 || value > 65535 )); then
      _mac_shell_tools_portwho_message error.port "$1" >&2
      return 2
    fi
    ports+=( "$value" )
    shift
  done
  ports=( "${(@u)ports}" )
  if (( ${#ports} )); then selector="-iTCP:${(j:,:)ports}"; fi
  for dependency in lsof mktemp rm cat; do
    if ! command -v "$dependency" >/dev/null 2>&1; then
      _mac_shell_tools_portwho_message error.dependency "$dependency" >&2
      return 1
    fi
  done
  umask 077
  query_directory=$(command mktemp -d "${TMPDIR:-/tmp}/mst-portwho.XXXXXX") || {
    _mac_shell_tools_portwho_message error.temporary >&2
    return 1
  }
  trap 'command rm -rf -- "$query_directory"' EXIT
  trap '_mac_shell_tools_portwho_message error.interrupted >&2; exit 1' HUP INT TERM
  # lsof selections are OR by default; -a keeps both TCP and LISTEN required.
  command lsof -nP +c 0 -a "$selector" -sTCP:LISTEN \
    > "$query_directory/out" 2> "$query_directory/err"
  query_status=$?
  if [[ -s "$query_directory/out" ]]; then command cat "$query_directory/out"; fi
  if [[ -s "$query_directory/err" ]]; then
    command cat "$query_directory/err" >&2
    _mac_shell_tools_portwho_message error.query >&2
    return 1
  fi
  case $query_status in
    0)
      if [[ ! -s "$query_directory/out" ]]; then _mac_shell_tools_portwho_message empty; fi
      ;;
    1)
      # lsof uses 1 for an empty selection too. Do not declare the port free.
      if [[ -s "$query_directory/out" ]]; then
        _mac_shell_tools_portwho_message error.query >&2
        return 1
      fi
      _mac_shell_tools_portwho_message empty
      ;;
    *) _mac_shell_tools_portwho_message error.query >&2; return 1 ;;
  esac
)

_portwho() {
  setopt localoptions
  local portwho_language help_description version_description port_label
  portwho_language=$(_mac_shell_tools_portwho_language) || return 2
  help_description=$(_mac_shell_tools_portwho_message completion.help)
  version_description=$(_mac_shell_tools_portwho_message completion.version)
  port_label=$(_mac_shell_tools_portwho_message completion.port)
  _arguments -S \
    "(-h --help)-h[$help_description]" \
    "(-h --help)--help[$help_description]" \
    "(-V --version)-V[$version_description]" \
    "(-V --version)--version[$version_description]" \
    "*:$port_label:(22 80 443 3000 5432 6379 8000 8080 9000)"
}

if (( $+functions[compdef] )); then
  compdef _portwho portwho
fi
