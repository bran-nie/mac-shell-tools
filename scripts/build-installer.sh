#!/bin/sh
# 从工具唯一源码生成可单独分发的安装器。
# 清单只接受简单文件名，避免生成 shell 代码时混入路径或特殊字符。
set -eu

script_dir=$(CDPATH= cd -P "$(dirname "$0")" && pwd)
project_dir=$(CDPATH= cd -P "$script_dir/.." && pwd)
mode=${1:-build}
case $mode in
  build|--check) ;;
  *) printf '%s\n' '用法：sh scripts/build-installer.sh [--check]' >&2; exit 2 ;;
esac
if [ "$#" -gt 1 ]; then
  printf '%s\n' 'build-installer: 参数过多。' >&2
  exit 2
fi

generated=$(mktemp "${TMPDIR:-/tmp}/mac-shell-tools-build.XXXXXX")
trap 'rm -f "$generated"' 0
trap 'exit 1' HUP INT TERM
cat "$script_dir/installer.sh.in" > "$generated"
printf '\n%s\n' 'write_payload() {' >> "$generated"
tool_files=
seen_files=' '

# init.zsh 固定先打包；工具清单同时决定生成文件和运行时安装列表。
for tool_file in init.zsh $(cat "$script_dir/tools.list"); do
  case $tool_file in
    *[!a-z0-9.-]*|.*|*..*|'')
      printf 'build-installer: 无效工具名：%s\n' "$tool_file" >&2
      exit 1
      ;;
  esac
  case $tool_file in
    *.zsh) ;;
    *) printf 'build-installer: 需要 .zsh 文件：%s\n' "$tool_file" >&2; exit 1 ;;
  esac
  case $seen_files in
    *" $tool_file "*) printf 'build-installer: 重复工具：%s\n' "$tool_file" >&2; exit 1 ;;
  esac
  seen_files="$seen_files$tool_file "
  if [ "$tool_file" != init.zsh ]; then
    tool_files="$tool_files $tool_file"
  fi
  source_file="$project_dir/tools/$tool_file"
  if [ ! -f "$source_file" ]; then
    printf 'build-installer: 缺少源文件：%s\n' "$source_file" >&2
    exit 1
  fi
  if awk '$0 == "MAC_SHELL_TOOLS_EMBEDDED_FILE_7D4C" { found = 1 } END { exit !found }' "$source_file"; then
    printf 'build-installer: 源文件与内嵌分隔符冲突：%s\n' "$source_file" >&2
    exit 1
  fi
  printf '  cat > "$stage/%s" <<\047MAC_SHELL_TOOLS_EMBEDDED_FILE_7D4C\047 || return 1\n' "$tool_file" >> "$generated"
  cat "$source_file" >> "$generated"
  printf '%s\n' 'MAC_SHELL_TOOLS_EMBEDDED_FILE_7D4C' >> "$generated"
done
printf '%s\n' '}' >> "$generated"
printf "\ntool_files='%s'\nmain\n" "$tool_files" >> "$generated"
sh -n "$generated"

case $mode in
  --check)
    if ! cmp -s "$generated" "$project_dir/install.sh"; then
      printf '%s\n' 'install.sh 已过期；请运行 sh scripts/build-installer.sh。' >&2
      exit 1
    fi
    printf '%s\n' 'install.sh 与规范源文件一致。'
    ;;
  build)
    if ! cmp -s "$generated" "$project_dir/install.sh"; then
      cat "$generated" > "$project_dir/install.sh"
    fi
    printf '%s\n' '已生成 install.sh。'
    ;;
esac
