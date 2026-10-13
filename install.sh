#!/bin/sh
# MIT License
#
# Copyright (c) 2026 bran.nie
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# Package version: 0.1.0-dev+a137ab409c60
# Source revision: a1c446b087215773f8c446e21634c3e28bd5f371
# Source state: modified
# Source digest: a137ab409c60911e870b5e13fcf5eae9035cc2eb514a1f26fa15072cf817b917
# mac-shell-tools bootstrap v1
# The v1 marker lets existing managers delegate to this lightweight bootstrap.
set -eu

bootstrap_fail() { printf 'mst: %s\n' "$*" >&2; exit 1; }

bootstrap_main() {
  command -v zsh >/dev/null 2>&1 || bootstrap_fail 'Required command is missing: zsh'
  bootstrap_directory=$(mktemp -d "${TMPDIR:-/tmp}/mac-shell-tools-bootstrap.XXXXXX") || exit 1
  trap 'rm -rf "$bootstrap_directory"' 0
  trap 'exit 1' HUP INT TERM
  source_directory=
  # A checkout is already a complete local distribution. A standalone or piped
  # bootstrap downloads one snapshot so manager and tools come from one revision.
  if [ -f "$0" ]; then
    bootstrap_parent=$(CDPATH= cd -P "$(dirname "$0")" && pwd)
    if [ -f "$bootstrap_parent/package.meta" ] && [ -f "$bootstrap_parent/lib/manager.sh" ]; then
      source_directory=$bootstrap_parent
    fi
  fi
  if [ -z "$source_directory" ]; then
    for bootstrap_dependency in curl tar awk; do
      command -v "$bootstrap_dependency" >/dev/null 2>&1 || bootstrap_fail "Required command is missing: $bootstrap_dependency"
    done
    archive_url='https://codeload.github.com/bran-nie/mac-shell-tools/tar.gz/refs/heads/main'
    printf 'mst: Fetching: %s\n' "$archive_url"
    curl -fsSL --proto '=https' --proto-redir '=https' --connect-timeout 10 --max-time 60 \
      -o "$bootstrap_directory/source.tar.gz" "$archive_url" || bootstrap_fail 'Download failed; existing managed files are unchanged.'
    [ -s "$bootstrap_directory/source.tar.gz" ] || bootstrap_fail 'Downloaded package is empty.'
    tar -tzf "$bootstrap_directory/source.tar.gz" > "$bootstrap_directory/members" || bootstrap_fail 'Invalid source archive.'
    # Reject traversal, multiple roots, links and special files before extraction.
    awk '
      /^\// || /(^|\/)\.\.?($|\/)/ || /\\/ || /[[:cntrl:]]/ {bad=1}
      {split($0, parts, "/"); if (!root) root=parts[1]; if (parts[1] != root) bad=1}
      END {exit bad || !root}
    ' "$bootstrap_directory/members" || bootstrap_fail 'Unsafe source archive paths.'
    tar -tvzf "$bootstrap_directory/source.tar.gz" > "$bootstrap_directory/types" || bootstrap_fail 'Invalid source archive.'
    awk 'substr($0,1,1) != "-" && substr($0,1,1) != "d" {bad=1} END {exit bad}' \
      "$bootstrap_directory/types" || bootstrap_fail 'Source archives must contain only regular files and directories.'
    mkdir "$bootstrap_directory/source"
    tar -xzf "$bootstrap_directory/source.tar.gz" -C "$bootstrap_directory/source" || bootstrap_fail 'Cannot extract source archive.'
    archive_root=$(awk 'NR == 1 {split($0, parts, "/"); print parts[1]; exit}' "$bootstrap_directory/members")
    source_directory="$bootstrap_directory/source/$archive_root"
  fi
  for source_asset in package.meta lib/manager.sh lib/repository.sh lib/i18n.sh locales/en.sh locales/zh-CN.sh tools/init.zsh scripts/tools.list; do
    [ -f "$source_directory/$source_asset" ] && [ ! -L "$source_directory/$source_asset" ] || bootstrap_fail "Incomplete source package: $source_asset"
    case $source_asset in
      *.sh) /bin/sh -n "$source_directory/$source_asset" || bootstrap_fail "Invalid source syntax: $source_asset" ;;
    esac
  done
  awk '$0 == "# mac-shell-tools runtime v2" {found=1} END {exit !found}' "$source_directory/lib/manager.sh" \
    || bootstrap_fail 'Unsupported manager source package.'
  . "$source_directory/lib/manager.sh"
  main "$source_directory/lib/manager.sh" "$bootstrap_directory" '' '' "$source_directory" "$@"
}

bootstrap_main "$@"
