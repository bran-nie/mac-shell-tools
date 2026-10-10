# Extract one archive into a new directory; loading and completion do no I/O on archives.
_mac_shell_tools_extract_language() (
  emulate -L zsh
  local component_directory=${${(%):-%x}:A:h}
  local common="$component_directory/i18n.sh"
  if [[ ! -f $common ]]; then common="$component_directory/../../lib/i18n.sh"; fi
  source "$common" || return 1
  mst_resolve_language "$component_directory/../../config.conf" "${MST_LANG:-}"
)

_mac_shell_tools_extract_message() (
  emulate -L zsh
  local component_directory=${${(%):-%x}:A:h}
  local common="$component_directory/i18n.sh"
  if [[ ! -f $common ]]; then common="$component_directory/../../lib/i18n.sh"; fi
  source "$common" || return 1
  source "$component_directory/locales/en.sh" || return 1
  unfunction mst_text_zh_CN 2>/dev/null || true
  if [[ ${extract_language:-en} == zh-CN && -f "$component_directory/locales/zh-CN.sh" ]]; then
    source "$component_directory/locales/zh-CN.sh" || return 1
  fi
  case $1 in error.*) printf 'extract: ' ;; esac
  mst_print_message "${extract_language:-en}" "$@"
)

_mac_shell_tools_extract_version() {
  local version='@MST_VERSION@' revision='@MST_REVISION@' source_state='@MST_STATE@'
  case $version in @*) version=development; revision=unbuilt; source_state=unknown ;; esac
  print -r -- "extract $version ($revision; $source_state)"
}

# A conservative portable check, followed by native tar/unzip path protections.
# Links and special entries are rejected separately, before creating output.
_mac_shell_tools_extract_paths() {
  emulate -L zsh
  local entry normalized
  while IFS= read -r entry || [[ -n $entry ]]; do
    normalized=$entry
    case $archive_kind in
      zip) normalized=${normalized//\\//} ;;
      tar) ;;
    esac
    case $normalized in
      /*|[a-zA-Z]:*|..|../*|*/..|*/../*)
        _mac_shell_tools_extract_message error.path "$entry" >&2
        return 2
        ;;
    esac
    if [[ -z $entry || $entry == *[[:cntrl:]]* ]]; then
      _mac_shell_tools_extract_message error.path "$entry" >&2
      return 2
    fi
  done < "$1"
}

_mac_shell_tools_extract_types() {
  emulate -L zsh
  local entry
  local -a fields
  while IFS= read -r entry || [[ -n $entry ]]; do
    case "$archive_kind:${entry[1]}" in
      tar:-|tar:d|zip:-|zip:d) ;;
      # ZIP writers can omit Unix file-type bits; unzip treats these as files.
      zip:\?) ;;
      *) _mac_shell_tools_extract_message error.type >&2; return 2 ;;
    esac
    case $archive_kind in
      zip)
        # ZipInfo's fifth column uses T/B for encrypted entries and t/b otherwise.
        # Reject before unpacking so an interactive unzip cannot ask for a password.
        fields=( ${=entry} )
        case ${fields[5]-} in
          [TB]*) _mac_shell_tools_extract_message error.encrypted >&2; return 2 ;;
          [tb][-lxX]) ;;
          *) _mac_shell_tools_extract_message error.type >&2; return 2 ;;
        esac
        ;;
      tar) ;;
    esac
  done < "$1"
}

extract() (
  emulate -L zsh
  local extract_language archive='' destination='' archive_kind archive_name base_name lower_name
  local has_archive=0 has_destination=0 list_only=0 parse_options=1
  local dependency temporary_directory snapshot listing_status output_created=0
  local -a dependencies
  extract_language=$(_mac_shell_tools_extract_language) || return 2
  while (( $# )); do
    if (( parse_options )); then
      case $1 in
        -h|--help) _mac_shell_tools_extract_message help; return 0 ;;
        -V|--version) _mac_shell_tools_extract_version; return 0 ;;
        -l|--list) list_only=1; shift; continue ;;
        -C|--directory)
          if (( $# < 2 )) || [[ -z $2 ]]; then
            _mac_shell_tools_extract_message error.value "$1" >&2
            return 2
          fi
          destination=$2; has_destination=1; shift 2; continue
          ;;
        --directory=*)
          destination=${1#*=}; has_destination=1
          if [[ -z $destination ]]; then
            _mac_shell_tools_extract_message error.value --directory >&2
            return 2
          fi
          shift; continue
          ;;
        --) parse_options=0; shift; continue ;;
        -*) _mac_shell_tools_extract_message error.option "$1" >&2; return 2 ;;
      esac
    fi
    if (( has_archive )); then
      _mac_shell_tools_extract_message error.archive_count >&2
      return 2
    fi
    archive=$1; has_archive=1; shift
  done
  if (( ! has_archive )) || [[ -z $archive ]]; then
    _mac_shell_tools_extract_message error.archive_count >&2
    return 2
  fi
  if (( list_only && has_destination )); then
    _mac_shell_tools_extract_message error.list_directory >&2
    return 2
  fi
  if [[ ! -f $archive || ! -r $archive ]]; then
    _mac_shell_tools_extract_message error.archive "$archive" >&2
    return 2
  fi
  archive_name=${archive:t}
  base_name=$archive_name
  lower_name=${(L)base_name}
  case $lower_name in
    *.tar.gz|*.tar.bz2|*.tar.xz) archive_kind=tar; base_name=${base_name%.*}; base_name=${base_name%.*} ;;
    *.tar|*.tgz|*.tbz2|*.txz) archive_kind=tar; base_name=${base_name%.*} ;;
    *.zip) archive_kind=zip; base_name=${base_name%.*} ;;
    *) _mac_shell_tools_extract_message error.format "$archive" >&2; return 2 ;;
  esac
  archive=${archive:A}
  if (( ! has_destination )); then
    # Hidden archive names such as .zip must still produce an ordinary new directory.
    case $base_name in ''|.|..) base_name="$archive_name.extracted" ;; esac
    destination="$PWD/$base_name"
  fi
  destination=${destination:a}
  if (( ! list_only )); then
    if [[ -e $destination || -L $destination ]]; then
      _mac_shell_tools_extract_message error.exists "$destination" >&2
      return 2
    fi
    if [[ ! -d ${destination:h} ]]; then
      _mac_shell_tools_extract_message error.parent "${destination:h}" >&2
      return 2
    fi
  fi
  dependencies=( mktemp cp rm mkdir cat )
  case $archive_kind in
    tar) dependencies+=( tar ) ;;
    zip) dependencies+=( unzip ) ;;
  esac
  for dependency in "${dependencies[@]}"; do
    if ! command -v "$dependency" >/dev/null 2>&1; then
      _mac_shell_tools_extract_message error.dependency "$dependency" >&2
      return 1
    fi
  done
  # Archive backends read option environment variables. Isolate them so a caller's
  # defaults cannot enable absolute paths, overwrite files, or execute tar hooks.
  unset TAR_OPTIONS TAPE GZIP BZIP BZIP2 XZ_OPT XZ_DEFAULTS \
    UNZIP UNZIPOPT ZIPINFO ZIPINFOOPT UNZIP_OPTS ZIPINFO_OPTS
  umask 077
  temporary_directory=$(command mktemp -d "${TMPDIR:-/tmp}/mst-extract.XXXXXX") || {
    _mac_shell_tools_extract_message error.temporary >&2
    return 1
  }
  trap 'command rm -rf -- "$temporary_directory"' EXIT
  trap '_mac_shell_tools_extract_message error.interrupted >&2; if (( output_created )); then _mac_shell_tools_extract_message error.partial "$destination" >&2; fi; exit 1' HUP INT TERM
  snapshot="$temporary_directory/archive.$archive_kind"
  # Inspect and unpack the same bytes; a fixed ZIP name also avoids unzip's globbing.
  if ! command cp -- "$archive" "$snapshot"; then
    _mac_shell_tools_extract_message error.read >&2
    return 1
  fi
  case $archive_kind in
    tar) command tar -tf "$snapshot" > "$temporary_directory/names" 2> "$temporary_directory/err" ;;
    zip) command unzip -Z -1 "$snapshot" > "$temporary_directory/names" 2> "$temporary_directory/err" ;;
  esac
  listing_status=$?
  if (( listing_status )) || [[ -s "$temporary_directory/err" ]]; then
    command cat "$temporary_directory/err" >&2
    _mac_shell_tools_extract_message error.read >&2
    return 1
  fi
  if (( list_only )); then
    command cat "$temporary_directory/names"
    return $?
  fi
  _mac_shell_tools_extract_paths "$temporary_directory/names" || return $?
  case $archive_kind in
    tar) command tar -tvf "$snapshot" > "$temporary_directory/types" 2> "$temporary_directory/err" ;;
    zip) command unzip -Z -l-h-t "$snapshot" > "$temporary_directory/types" 2> "$temporary_directory/err" ;;
  esac
  listing_status=$?
  if (( listing_status )) || [[ -s "$temporary_directory/err" ]]; then
    command cat "$temporary_directory/err" >&2
    _mac_shell_tools_extract_message error.read >&2
    return 1
  fi
  _mac_shell_tools_extract_types "$temporary_directory/types" || return $?
  # mkdir reserves the exact destination atomically, including concurrent calls.
  if ! command mkdir -- "$destination"; then
    _mac_shell_tools_extract_message error.create "$destination" >&2
    return 1
  fi
  output_created=1
  case $archive_kind in
    tar) command tar -xf "$snapshot" -C "$destination" --no-same-owner --no-same-permissions ;;
    zip) command unzip -qq -n -P '' "$snapshot" -d "$destination" </dev/null ;;
  esac
  if (( $? )); then
    _mac_shell_tools_extract_message error.partial "$destination" >&2
    return 1
  fi
  _mac_shell_tools_extract_message success "$destination"
)

_extract() {
  setopt localoptions
  local extract_language help_description version_description list_description directory_description archive_label directory_label
  extract_language=$(_mac_shell_tools_extract_language) || return 2
  help_description=$(_mac_shell_tools_extract_message completion.help)
  version_description=$(_mac_shell_tools_extract_message completion.version)
  list_description=$(_mac_shell_tools_extract_message completion.list)
  directory_description=$(_mac_shell_tools_extract_message completion.directory)
  archive_label=$(_mac_shell_tools_extract_message label.archive)
  directory_label=$(_mac_shell_tools_extract_message label.directory)
  _arguments -S \
    "(-h --help)-h[$help_description]" \
    "(-h --help)--help[$help_description]" \
    "(-V --version)-V[$version_description]" \
    "(-V --version)--version[$version_description]" \
    "(-l --list)-l[$list_description]" \
    "(-l --list)--list[$list_description]" \
    "*-C[$directory_description]:$directory_label:_directories" \
    "*--directory=[$directory_description]:$directory_label:_directories" \
    "1:$archive_label:_files -g '(#i)*.(zip|tar|tar.gz|tgz|tar.bz2|tbz2|tar.xz|txz)'"
}

if (( $+functions[compdef] )); then
  compdef _extract extract
fi
