#!/bin/sh
# Deterministic self-contained bootstrap, with explicit source provenance.
set -eu
script_dir=$(CDPATH= cd -P "$(dirname "$0")" && pwd)
project_dir=$(CDPATH= cd -P "$script_dir/.." && pwd)
mode=${1:-build}
case $mode in build|--check|--refresh-revision) ;; *) printf '%s\n' 'Usage: sh scripts/build-installer.sh [--check|--refresh-revision]' >&2; exit 2 ;; esac
[ "$#" -le 1 ] || exit 2
build_directory=$(mktemp -d "${TMPDIR:-/tmp}/mac-shell-tools-build.XXXXXX")
trap 'rm -rf "$build_directory"' 0
trap 'exit 1' HUP INT TERM
manager="$build_directory/manager-core.sh"
generated="$build_directory/install.sh"
payload="$build_directory/payload"
mkdir -p "$payload/manager/locales" "$payload/tools"
base_version=$(cat "$project_dir/VERSION")
printf '%s\n' "$base_version" | awk '/^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$/ {ok=1} END {exit !ok}' || {
  printf 'Invalid VERSION: %s\n' "$base_version" >&2; exit 1;
}
tool_files=
seen_files=' init.zsh mst.zsh '
source_files='VERSION LICENSE lib/i18n.sh lib/mst.zsh locales/en.sh locales/zh-CN.sh tools/init.zsh scripts/tools.list scripts/build-installer.sh scripts/installer.sh.in scripts/bootstrap.sh.in'
for tool_file in $(cat "$script_dir/tools.list"); do
  case $tool_file in
    [!a-z0-9]*|*[!a-z0-9.-]*|.*|*..*|'') printf 'Invalid tool filename: %s\n' "$tool_file" >&2; exit 1 ;;
    *.zsh) ;;
    *) printf 'Expected .zsh: %s\n' "$tool_file" >&2; exit 1 ;;
  esac
  tool_name=${tool_file%.zsh}
  case $tool_name in *[!a-z0-9-]*|'') printf 'Invalid tool id: %s\n' "$tool_name" >&2; exit 1 ;; esac
  case $seen_files in *" $tool_file "*) printf 'Duplicate/reserved tool: %s\n' "$tool_file" >&2; exit 1 ;; esac
  seen_files="$seen_files$tool_file "
  source_component="$project_dir/tools/$tool_name"
  [ -f "$source_component/$tool_file" ] || { printf 'Missing source: %s\n' "$source_component/$tool_file" >&2; exit 1; }
  tool_files="$tool_files $tool_file"
  source_files="$source_files tools/$tool_name/$tool_file"
  for catalog in en zh-CN; do
    if [ -f "$source_component/locales/$catalog.sh" ]; then source_files="$source_files tools/$tool_name/locales/$catalog.sh"; fi
  done
done
source_digest=$(
  CDPATH= cd -P "$project_dir"
  for source_file in $source_files; do shasum -a 256 "$source_file"; done | shasum -a 256 | awk '{print $1}'
)
source_revision=unknown
source_state=unknown
saved_digest=
if [ -f "$project_dir/install.sh" ]; then
  saved_digest=$(awk '/^# Source digest: / {print $4; exit}' "$project_dir/install.sh")
fi
# --check reuses the recorded provenance; comparing with HEAD would invalidate a
# generated artifact merely because its publication commit was created later.
reuse_provenance=no
case $mode in
  --check) reuse_provenance=yes ;;
  build) if [ "$saved_digest" = "$source_digest" ]; then reuse_provenance=yes; fi ;;
  --refresh-revision) ;;
esac
if [ "$reuse_provenance" = yes ] && [ -n "$saved_digest" ]; then
  source_revision=$(awk '/^# Source revision: / {print $4; exit}' "$project_dir/install.sh")
  source_state=$(awk '/^# Source state: / {print $4; exit}' "$project_dir/install.sh")
elif command -v git >/dev/null 2>&1 && git -C "$project_dir" rev-parse --verify HEAD > "$build_directory/revision" 2>/dev/null; then
  source_revision=$(cat "$build_directory/revision")
  source_state=clean
  if [ -n "$(git -C "$project_dir" status --porcelain -- $source_files)" ]; then source_state=modified; fi
fi
case $source_revision in unknown) ;; ''|*[!0-9a-f]*) printf '%s\n' 'Invalid source revision.' >&2; exit 1 ;; esac
case $source_state in clean|modified|unknown) ;; *) printf '%s\n' 'Invalid source state.' >&2; exit 1 ;; esac
package_version=$base_version
case $base_version in *-*) short_digest=$(printf '%.12s' "$source_digest"); package_version="$base_version+$short_digest" ;; esac

with_license() {
  printf '%s\n' '#!/bin/sh'
  sed -e 's/^/# /' -e 's/^# $/#/' "$project_dir/LICENSE"
}
with_license > "$manager"
cat "$project_dir/lib/i18n.sh" "$project_dir/locales/en.sh" "$project_dir/locales/zh-CN.sh" >> "$manager"
printf "\npackage_version='%s'\npackage_revision='%s'\npackage_state='%s'\n" \
  "$package_version" "$source_revision" "$source_state" >> "$manager"
sed '1d' "$script_dir/installer.sh.in" >> "$manager"
cp "$project_dir/tools/init.zsh" "$payload/init.zsh"
cp "$project_dir/lib/mst.zsh" "$payload/manager/mst.zsh"
cp "$project_dir/lib/i18n.sh" "$payload/manager/i18n.sh"
cp "$project_dir/locales/"*.sh "$payload/manager/locales/"
for tool_file in $tool_files; do
  tool_name=${tool_file%.zsh}
  destination="$payload/tools/$tool_name"
  mkdir -p "$destination"
  sed -e "s/@MST_VERSION@/$package_version/g" -e "s/@MST_REVISION@/$source_revision/g" \
    -e "s/@MST_STATE@/$source_state/g" "$project_dir/tools/$tool_name/$tool_file" > "$destination/$tool_file"
  printf '%s\n%s\n%s\n' "$package_version" "$source_revision" "$source_state" > "$destination/version"
  printf '%s\n' "$tool_file" version > "$destination/files.list"
  if [ -d "$project_dir/tools/$tool_name/locales" ]; then
    mkdir "$destination/locales"
    cp "$project_dir/lib/i18n.sh" "$destination/i18n.sh"
    printf '%s\n' i18n.sh >> "$destination/files.list"
    for catalog in en zh-CN; do
      if [ -f "$project_dir/tools/$tool_name/locales/$catalog.sh" ]; then
        cp "$project_dir/tools/$tool_name/locales/$catalog.sh" "$destination/locales/$catalog.sh"
        printf 'locales/%s.sh\n' "$catalog" >> "$destination/files.list"
      fi
    done
  fi
done
printf '\n%s\n' 'write_payload() {' >> "$manager"
emit_file() {
  relative=$1
  source_file="$payload/$relative"
  if awk '$0 == "MAC_SHELL_TOOLS_EMBEDDED_FILE_7D4C" {found=1} END {exit !found}' "$source_file"; then
    printf 'Embedded delimiter collision: %s\n' "$relative" >&2; exit 1
  fi
  parent=${relative%/*}
  if [ "$parent" != "$relative" ]; then printf '  mkdir -p "$stage/payload/%s" || return 1\n' "$parent" >> "$manager"; fi
  printf '  cat > "$stage/payload/%s" <<\047MAC_SHELL_TOOLS_EMBEDDED_FILE_7D4C\047 || return 1\n' "$relative" >> "$manager"
  cat "$source_file" >> "$manager"
  printf '%s\n' 'MAC_SHELL_TOOLS_EMBEDDED_FILE_7D4C' >> "$manager"
}
printf '%s\n' '  mkdir -p "$stage/payload" || return 1' >> "$manager"
for relative in init.zsh manager/mst.zsh manager/i18n.sh manager/locales/en.sh manager/locales/zh-CN.sh; do emit_file "$relative"; done
for tool_file in $tool_files; do
  tool_name=${tool_file%.zsh}
  while IFS= read -r relative; do emit_file "tools/$tool_name/$relative"; done < "$payload/tools/$tool_name/files.list"
  emit_file "tools/$tool_name/files.list"
done
printf '%s\n' '}' >> "$manager"
printf "\ntool_files='%s'\n" "$tool_files" >> "$manager"
/bin/sh -n "$manager"
if awk '$0 == "MAC_SHELL_TOOLS_MANAGER_7D4C" {found=1} END {exit !found}' "$manager"; then
  printf '%s\n' 'Bootstrap delimiter collision.' >&2; exit 1
fi
with_license > "$generated"
printf '# Package version: %s\n# Source revision: %s\n# Source state: %s\n# Source digest: %s\n' \
  "$package_version" "$source_revision" "$source_state" "$source_digest" >> "$generated"
sed '1d' "$script_dir/bootstrap.sh.in" >> "$generated"
printf '\n%s\n' 'write_manager_payload() {' >> "$generated"
printf '%s\n' '  cat > "$bootstrap_directory/manager-core.sh" <<'\''MAC_SHELL_TOOLS_MANAGER_7D4C'\'' || return 1' >> "$generated"
cat "$manager" >> "$generated"
printf '%s\n' 'MAC_SHELL_TOOLS_MANAGER_7D4C' '}' 'bootstrap_main "$@"' >> "$generated"
/bin/sh -n "$generated"
case $mode in
  --check)
    cmp -s "$generated" "$project_dir/install.sh" || { printf '%s\n' 'install.sh is stale; run sh scripts/build-installer.sh.' >&2; exit 1; }
    printf '%s\n' 'install.sh matches its canonical sources.' ;;
  build|--refresh-revision)
    if ! cmp -s "$generated" "$project_dir/install.sh"; then cat "$generated" > "$project_dir/install.sh"; fi
    printf 'Generated install.sh (%s).\n' "$package_version" ;;
esac
