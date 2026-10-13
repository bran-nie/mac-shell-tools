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
  cp "$package_source/scripts/build-installer.sh" \
    "$package_source/scripts/bootstrap.sh.in" "$package_source/scripts/tools.list" "$package_target/scripts/"
  cp "$package_source/lib/"*.sh "$package_source/lib/mst.zsh" "$package_target/lib/"
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

# Installation checks command availability; no test invokes the real npm.
mock_node_npm() {
  mkdir -p "$1"
  for mock_command in node npm; do
    cat > "$1/$mock_command" <<'MOCK'
#!/bin/sh
case ${1:-} in
  --version) printf 'test-runtime\n'; exit 0 ;;
  *) printf 'Unexpected runtime invocation in installer test.\n' >&2; exit 90 ;;
esac
MOCK
    chmod +x "$1/$mock_command"
  done
}

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


# Mock both the small bootstrap and its source snapshot. No test reaches GitHub.
mock_release_curl() {
  cat > "$1/curl" <<'MOCK'
#!/bin/sh
set -eu
if [ -n "${MST_CURL_LOG:-}" ]; then printf '%s\n' "$*" >> "$MST_CURL_LOG"; fi
output=
url=
while [ "$#" -gt 0 ]; do
  case $1 in
    -o) output=$2; shift 2 ;;
    https://*) url=$1; shift ;;
    *) shift ;;
  esac
done
[ -n "$output" ] || exit 90
case ${MST_DOWNLOAD_MODE:-ok} in
  fail) printf 'simulated HTTP failure\n' >&2; exit 22 ;;
  empty) : > "$output"; exit 0 ;;
  html) printf '<html>not a release</html>\n' > "$output"; exit 0 ;;
  syntax) printf '# mac-shell-tools bootstrap v1\nif (\n' > "$output"; exit 0 ;;
  foreign) printf '#!/bin/sh\nexit 0\n' > "$output"; exit 0 ;;
  ok) ;;
  *) exit 91 ;;
esac
case $url in
  https://raw.githubusercontent.com/bran-nie/mac-shell-tools/main/install.sh)
    cp "$MST_RELEASE" "$output" ;;
  https://codeload.github.com/bran-nie/mac-shell-tools/tar.gz/refs/heads/main)
    if [ -n "${MST_ARCHIVE:-}" ]; then
      cp "$MST_ARCHIVE" "$output"
    else
      release_directory=${MST_RELEASE%/*}
      COPYFILE_DISABLE=1 tar -czf "$output" -C "${release_directory%/*}" "${release_directory##*/}"
    fi ;;
  https://example.invalid/resource)
    cp "$MST_RESOURCE" "$output" ;;
  *) printf 'Unexpected test download: %s\n' "$url" >&2; exit 92 ;;
esac
MOCK
  chmod +x "$1/curl"
}
