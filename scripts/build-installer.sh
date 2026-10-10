#!/bin/sh
# 从规范源码生成自包含引导脚本及其共享管理器载荷。
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

build_directory=$(mktemp -d "${TMPDIR:-/tmp}/mac-shell-tools-build.XXXXXX")
trap 'rm -rf "$build_directory"' 0
trap 'exit 1' HUP INT TERM
generated="$build_directory/install.sh"
manager="$build_directory/manager-core.sh"

# 引导脚本和可独立保存的管理器都包含完整 MIT 声明。
with_license() {
  printf '%s\n' '#!/bin/sh'
  sed -e 's/^/# /' -e 's/^# $/#/' "$project_dir/LICENSE"
  sed '1d' "$1"
}
with_license "$script_dir/installer.sh.in" > "$manager"
printf '\n%s\n' 'write_payload() {' >> "$manager"
tool_files=
seen_files=' '

for tool_file in init.zsh mst.zsh $(cat "$script_dir/tools.list"); do
  case $tool_file in
    [!a-z0-9]*|*[!a-z0-9.-]*|.*|*..*|'')
      printf 'build-installer: 无效工具名：%s\n' "$tool_file" >&2
      exit 1
      ;;
  esac
  case $tool_file in
    *.zsh) ;;
    *) printf 'build-installer: 需要 .zsh 文件：%s\n' "$tool_file" >&2; exit 1 ;;
  esac
  tool_name=${tool_file%.zsh}
  case $tool_name in
    *[!a-z0-9-]*|'') printf 'build-installer: 无效工具标识：%s\n' "$tool_name" >&2; exit 1 ;;
  esac
  case $seen_files in
    *" $tool_file "*) printf 'build-installer: 重复工具：%s\n' "$tool_file" >&2; exit 1 ;;
  esac
  seen_files="$seen_files$tool_file "
  case $tool_file in
    init.zsh) source_file="$project_dir/tools/init.zsh" ;;
    mst.zsh) source_file="$project_dir/lib/mst.zsh" ;;
    *) source_file="$project_dir/tools/$tool_file"; tool_files="$tool_files $tool_file" ;;
  esac
  if [ ! -f "$source_file" ]; then
    printf 'build-installer: 缺少源文件：%s\n' "$source_file" >&2
    exit 1
  fi
  if awk '$0 == "MAC_SHELL_TOOLS_EMBEDDED_FILE_7D4C" { found = 1 } END { exit !found }' "$source_file"; then
    printf 'build-installer: 源文件与内嵌分隔符冲突：%s\n' "$source_file" >&2
    exit 1
  fi
  printf '  cat > "$stage/%s" <<\047MAC_SHELL_TOOLS_EMBEDDED_FILE_7D4C\047 || return 1\n' "$tool_file" >> "$manager"
  cat "$source_file" >> "$manager"
  printf '%s\n' 'MAC_SHELL_TOOLS_EMBEDDED_FILE_7D4C' >> "$manager"
done
printf '%s\n' '}' >> "$manager"
printf "\ntool_files='%s'\n" "$tool_files" >> "$manager"
/bin/sh -n "$manager"
if awk '$0 == "MAC_SHELL_TOOLS_MANAGER_7D4C" { found = 1 } END { exit !found }' "$manager"; then
  printf '%s\n' 'build-installer: 管理器与引导分隔符冲突。' >&2
  exit 1
fi

with_license "$script_dir/bootstrap.sh.in" > "$generated"
printf '\n%s\n' 'write_manager_payload() {' >> "$generated"
printf '%s\n' '  cat > "$bootstrap_directory/manager-core.sh" <<'\''MAC_SHELL_TOOLS_MANAGER_7D4C'\'' || return 1' >> "$generated"
cat "$manager" >> "$generated"
printf '%s\n' 'MAC_SHELL_TOOLS_MANAGER_7D4C' '}' 'bootstrap_main "$@"' >> "$generated"
/bin/sh -n "$generated"

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
