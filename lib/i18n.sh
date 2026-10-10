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
