#!/bin/sh
# Shared fixture and assertions; only called with isolated test directories.
file_stat() {
  case $(uname -s) in
    Darwin) stat -f '%i:%m:%z' "$@" ;;
    Linux) stat -c '%i:%Y:%s' "$@" ;;
    *) printf '%s\n' 'Unsupported test platform.' >&2; return 1 ;;
  esac
}

copy_package() {
  package_source=$1
  package_target=$2
  mkdir -p "$package_target/scripts" "$package_target/tools" "$package_target/lib"
  cp "$package_source/scripts/build-installer.sh" "$package_source/scripts/installer.sh.in" \
    "$package_source/scripts/bootstrap.sh.in" "$package_source/scripts/tools.list" "$package_target/scripts/"
  cp "$package_source/lib/mst.zsh" "$package_source/lib/i18n.sh" "$package_target/lib/"
  cp "$package_source/tools/init.zsh" "$package_target/tools/"
  for package_tool in $(cat "$package_source/scripts/tools.list"); do
    cp -R "$package_source/tools/${package_tool%.zsh}" "$package_target/tools/"
  done
  cp -R "$package_source/locales" "$package_target/"
  cp "$package_source/LICENSE" "$package_source/VERSION" "$package_target/"
}

render_tool() {
  render_package=$1
  render_name=$2
  render_version=$(awk '/^# Package version: / {print $4; exit}' "$render_package/install.sh")
  render_revision=$(awk '/^# Source revision: / {print $4; exit}' "$render_package/install.sh")
  render_state=$(awk '/^# Source state: / {print $4; exit}' "$render_package/install.sh")
  sed -e "s/@MST_VERSION@/$render_version/g" -e "s/@MST_REVISION@/$render_revision/g" \
    -e "s/@MST_STATE@/$render_state/g" "$render_package/tools/$render_name/$render_name.zsh"
}

state_names() { awk -F '\t' '{print $1}' "$1"; }

tool_matches() {
  render_tool "$1" "$2" > "$test_directory/expected-tool"
  cmp -s "$test_directory/expected-tool" "$3"
}

# Backup directories mirror managed paths; shell globs supply the random suffix.
backup_pattern() {
  case $1 in
    "$install_directory"/*) printf '%s/backups/%s.bak.*\n' "$install_directory" "${1#"$install_directory"/}" ;;
    "$zshrc") printf '%s/backups/zshrc/.zshrc.bak.*\n' "$install_directory" ;;
    *) return 1 ;;
  esac
}
