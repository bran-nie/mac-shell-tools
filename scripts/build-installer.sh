#!/bin/sh
# Generate only the small bootstrap and data-only source provenance record.
set -eu
script_dir=$(CDPATH= cd -P "$(dirname "$0")" && pwd)
project_dir=$(CDPATH= cd -P "$script_dir/.." && pwd)
mode=${1:-build}
case $mode in build|--check|--refresh-revision) ;; *) printf '%s\n' 'Usage: sh scripts/build-installer.sh [--check|--refresh-revision]' >&2; exit 2 ;; esac
[ "$#" -le 1 ] || exit 2
build_directory=$(mktemp -d "${TMPDIR:-/tmp}/mac-shell-tools-build.XXXXXX")
trap 'rm -rf "$build_directory"' 0
trap 'exit 1' HUP INT TERM
base_version=$(cat "$project_dir/VERSION")
printf '%s\n' "$base_version" | awk '/^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$/ {ok=1} END {exit !ok}' || {
  printf 'Invalid VERSION: %s\n' "$base_version" >&2; exit 1;
}
source_files='VERSION LICENSE lib/i18n.sh lib/mst.zsh lib/manager.sh lib/repository.sh locales/en.sh locales/zh-CN.sh tools/init.zsh scripts/tools.list scripts/build-installer.sh scripts/bootstrap.sh.in'
seen_files=' init.zsh mst.zsh '
for tool_file in $(cat "$script_dir/tools.list"); do
  case $tool_file in *.zsh) ;; *) printf 'Expected .zsh: %s\n' "$tool_file" >&2; exit 1 ;; esac
  tool_name=${tool_file%.zsh}
  case $tool_name in ''|[!a-z0-9]*|*[!a-z0-9-]*) printf 'Invalid tool id: %s\n' "$tool_name" >&2; exit 1 ;; esac
  case $seen_files in *" $tool_file "*) printf 'Duplicate/reserved tool: %s\n' "$tool_file" >&2; exit 1 ;; esac
  seen_files="$seen_files$tool_file "
  component="$project_dir/tools/$tool_name"
  [ -f "$component/$tool_file" ] && [ ! -L "$component" ] && [ ! -L "$component/$tool_file" ] || {
    printf 'Missing or linked source: %s\n' "$component/$tool_file" >&2; exit 1;
  }
  source_files="$source_files tools/$tool_name/$tool_file"
  for asset in locales/en.sh locales/zh-CN.sh install.mode downloads.list; do
    if [ -f "$component/$asset" ]; then source_files="$source_files tools/$tool_name/$asset"; fi
  done
done
if command -v sha256sum >/dev/null 2>&1; then
  sha256() { sha256sum "$@"; }
elif command -v shasum >/dev/null 2>&1; then
  sha256() { shasum -a 256 "$@"; }
else
  printf '%s\n' 'Building requires sha256sum or shasum.' >&2; exit 1
fi
source_digest=$(
  CDPATH= cd -P "$project_dir"
  for source_file in $source_files; do sha256 "$source_file"; done | sha256 | awk '{print $1}'
)
source_revision=unknown
source_state=unknown
saved_digest=
if [ -f "$project_dir/install.sh" ]; then saved_digest=$(awk '/^# Source digest: / {print $4; exit}' "$project_dir/install.sh"); fi
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
{
  printf '%s\n' '#!/bin/sh'
  sed -e 's/^/# /' -e 's/^# $/#/' "$project_dir/LICENSE"
  printf '# Package version: %s\n# Source revision: %s\n# Source state: %s\n# Source digest: %s\n' \
    "$package_version" "$source_revision" "$source_state" "$source_digest"
  sed '1d' "$script_dir/bootstrap.sh.in"
} > "$build_directory/install.sh"
printf '%s\n%s\n%s\n%s\n' "$package_version" "$source_revision" "$source_state" "$source_digest" > "$build_directory/package.meta"
/bin/sh -n "$build_directory/install.sh"
# Validate source metadata using the same parser as installation.
/bin/sh -c '
  . "$1/lib/manager.sh"
  . "$1/lib/i18n.sh"
  . "$1/locales/en.sh"
  . "$1/lib/repository.sh"
  source_directory=$1
  load_source_catalog
' -- "$project_dir"
for generated_file in install.sh package.meta; do
  case $mode in
    --check)
      cmp -s "$build_directory/$generated_file" "$project_dir/$generated_file" || {
        printf '%s is stale; run sh scripts/build-installer.sh.\n' "$generated_file" >&2; exit 1;
      } ;;
    build|--refresh-revision)
      if ! cmp -s "$build_directory/$generated_file" "$project_dir/$generated_file"; then
        cat "$build_directory/$generated_file" > "$project_dir/$generated_file"
      fi ;;
  esac
done
printf 'Bootstrap and source metadata %s (%s).\n' "$mode" "$package_version"
