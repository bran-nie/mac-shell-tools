#!/bin/sh
# 统一的本地及 CI 门禁；所有行为检查运行在临时 HOME 中。
# 不读取或改写维护者的 Zsh 主配置，不需要额外测试框架。
set -eu
project_dir=$(CDPATH= cd -P "$(dirname "$0")/.." && pwd)
cd "$project_dir"
platform=$(uname -s)
case $platform in
  Darwin|Linux) ;;
  *) printf '%s\n' '完整验证需要 macOS 或 Linux。' >&2; exit 1 ;;
esac
for script in install.sh scripts/*.sh scripts/*.sh.in tests/*.sh lib/*.sh locales/*.sh tools/*/locales/*.sh; do
  sh -n "$script"
done
for script in tools/*.zsh tools/*/*.zsh lib/*.zsh tests/*.zsh; do
  zsh -n "$script"
done
sh scripts/build-installer.sh --check

test_root=$(mktemp -d "${TMPDIR:-/tmp}/mac-shell-tools-check.XXXXXX")
trap 'rm -rf "$test_root"' 0
trap 'exit 1' HUP INT TERM
mkdir -p "$test_root/home" "$test_root/tmp"
for suite in dsize.zsh portwho.zsh extract.zsh install.sh management.sh mst.sh catalog.sh versions-language.sh migration.sh platform.sh completion.zsh sessions.zsh; do
  case $suite in
    *.zsh)
      env HOME="$test_root/home" XDG_CONFIG_HOME= ZDOTDIR= MST_LANG= TMPDIR="$test_root/tmp" \
        zsh -f "$project_dir/tests/$suite" "$project_dir"
      ;;
    *.sh)
      env HOME="$test_root/home" XDG_CONFIG_HOME= ZDOTDIR= MST_LANG= TMPDIR="$test_root/tmp" \
        sh "$project_dir/tests/$suite" "$project_dir"
      ;;
  esac
done
printf '全部 %s 检查通过。\n' "$platform"
