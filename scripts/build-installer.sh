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
read_base_version() {
  [ -f "$1" ] && [ ! -L "$1" ] || { printf 'Missing or linked VERSION: %s\n' "$1" >&2; exit 1; }
  awk 'NR != 1 || !/^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$/ {bad=1} END {exit bad || NR != 1}' "$1" || {
    printf 'Invalid VERSION: %s\n' "$1" >&2; exit 1;
  }
  cat "$1"
}
base_version=$(read_base_version "$project_dir/VERSION")
source_files='VERSION LICENSE lib/i18n.sh lib/mst.zsh lib/manager.sh lib/repository.sh locales/en.sh locales/zh-CN.sh tools/init.zsh scripts/tools.list scripts/build-installer.sh scripts/bootstrap.sh.in'
generated_files='install.sh package.meta'
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
  read_base_version "$component/VERSION" > /dev/null
  source_files="$source_files tools/$tool_name/VERSION tools/$tool_name/$tool_file"
  # Hash exactly the tool's own source and shipped shared runtime, never mst,
  # another tool, the global release version, docs or generated metadata.
  tool_sources="LICENSE tools/$tool_name/VERSION tools/$tool_name/$tool_file"
  if [ -d "$component/locales" ]; then tool_sources="$tool_sources lib/i18n.sh"; fi
  for asset in locales/en.sh locales/zh-CN.sh install.mode downloads.list dependencies.list; do
    if [ -f "$component/$asset" ]; then
      source_files="$source_files tools/$tool_name/$asset"
      tool_sources="$tool_sources tools/$tool_name/$asset"
    fi
  done
  printf '%s\n' "$tool_sources" > "$build_directory/$tool_name.sources"
  generated_files="$generated_files tools/$tool_name/package.meta"
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
for tool_file in $(cat "$script_dir/tools.list"); do
  tool_name=${tool_file%.zsh}
  tool_sources=$(cat "$build_directory/$tool_name.sources")
  tool_base_version=$(read_base_version "$project_dir/tools/$tool_name/VERSION")
  tool_digest=$(
    CDPATH= cd -P "$project_dir"
    for tool_source in $tool_sources; do sha256 "$tool_source"; done | sha256 | awk '{print $1}'
  )
  tool_metadata="$project_dir/tools/$tool_name/package.meta"
  [ ! -L "$tool_metadata" ] || { printf 'Linked metadata: %s\n' "$tool_metadata" >&2; exit 1; }
  tool_revision=unknown
  tool_state=unknown
  saved_tool_digest=
  saved_tool_state=
  if [ -f "$tool_metadata" ]; then
    saved_tool_digest=$(sed -n '4p' "$tool_metadata")
    saved_tool_state=$(sed -n '3p' "$tool_metadata")
  fi
  reuse_tool_provenance=no
  case $mode in
    --check) reuse_tool_provenance=yes ;;
    build) if [ "$saved_tool_digest" = "$tool_digest" ]; then reuse_tool_provenance=yes; fi ;;
    --refresh-revision)
      # A clean unchanged tool keeps its original source snapshot even when
      # another component is published. Refresh only new/uncommitted records.
      if [ "$saved_tool_digest" = "$tool_digest" ] && [ "$saved_tool_state" = clean ]; then
        reuse_tool_provenance=yes
      fi ;;
  esac
  if [ "$reuse_tool_provenance" = yes ] && [ -n "$saved_tool_digest" ]; then
    tool_revision=$(sed -n '2p' "$tool_metadata")
    tool_state=$saved_tool_state
  elif command -v git >/dev/null 2>&1 && git -C "$project_dir" rev-parse --verify HEAD > "$build_directory/revision" 2>/dev/null; then
    tool_revision=$(cat "$build_directory/revision")
    tool_state=clean
    if [ -n "$(git -C "$project_dir" status --porcelain -- $tool_sources)" ]; then tool_state=modified; fi
  fi
  tool_version=$tool_base_version
  case $tool_base_version in *-*) tool_version="$tool_base_version+$(printf '%.12s' "$tool_digest")" ;; esac
  mkdir -p "$build_directory/tools/$tool_name"
  printf '%s\n%s\n%s\n%s\n' "$tool_version" "$tool_revision" "$tool_state" "$tool_digest" \
    > "$build_directory/tools/$tool_name/package.meta"
done
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
  load_source_catalog "$2"
' -- "$project_dir" "$build_directory"
for generated_file in $generated_files; do
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
