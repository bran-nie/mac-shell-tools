#!/bin/sh
# mst 常驻入口及在线操作测试：curl 完全由本地替身提供，绝不下载或安装远端代码。
set -eu
project_dir=$1
. "$project_dir/tests/common.sh"
test_directory=$(mktemp -d "${TMPDIR:-/tmp}/mac-shell-tools-mst-test.XXXXXX")
trap 'chmod -R u+rwX "$test_directory"; rm -rf "$test_directory"' 0
trap 'exit 1' HUP INT TERM
checks=0
fixture="$test_directory/release"
copy_package "$project_dir" "$fixture"
mkdir -p "$test_directory/mock" "$test_directory/tmp"
printf '%s\n' dsize.zsh other.zsh > "$fixture/scripts/tools.list"
mkdir -p "$fixture/tools/other"
printf '%s\n' 0.1.0-dev > "$fixture/tools/other/VERSION"
printf '%s\n' 'other() { print -r -- other-ready; }' > "$fixture/tools/other/other.zsh"
printf '\n# release two\n' >> "$fixture/tools/dsize/dsize.zsh"
printf '\n# manager release two\n' >> "$fixture/lib/mst.zsh"
sh "$fixture/scripts/build-installer.sh" > "$test_directory/build"

mock_release_curl "$test_directory/mock"
chmod +x "$test_directory/mock/curl"
download_mode=ok

fail() {
  printf 'FAIL mst: %s\n' "$*" >&2
  cat "$test_directory/out" "$test_directory/err" >&2
  exit 1
}

new_home() {
  test_home="$test_directory/$1/home"
  test_config=
  test_zdot=
  install_directory="$test_home/.config/zsh/mac-shell-tools"
  manager_directory="$install_directory/manager"
  zshrc="$test_home/.zshrc"
  mkdir -p "$test_home"
}

assert_status() {
  [ "$actual" -eq "$expected" ] || fail "$*: 预期 ${expected}，实际 $actual"
  if [ "$expected" -ne 0 ] && [ ! -s "$test_directory/err" ]; then fail '失败缺少诊断'; fi
  checks=$((checks + 1))
}

run_bootstrap() {
  expected=$1
  shift
  if env HOME="$test_home" XDG_CONFIG_HOME="$test_config" ZDOTDIR="$test_zdot" RUNZSH=no \
      TMPDIR="$test_directory/tmp" /bin/sh "$project_dir/install.sh" "$@" \
      > "$test_directory/out" 2> "$test_directory/err"; then actual=0; else actual=$?; fi
  assert_status "$@"
}

# 刻意换 cwd 和配置环境，验证函数及下载委托仍管理原安装位置。
run_mst() {
  expected=$1
  shift
  if env HOME="$test_home" XDG_CONFIG_HOME="$test_directory/unexpected-config" \
      ZDOTDIR="$test_directory/unexpected-zdot" RUNZSH=no TMPDIR="$test_directory/tmp" \
      PATH="$test_directory/mock:/usr/bin:/bin:/usr/sbin:/sbin" \
      MST_CURL_LOG="$test_directory/curl-log" MST_RELEASE="$fixture/install.sh" MST_DOWNLOAD_MODE="$download_mode" \
      /bin/zsh -f -c 'source "$1"; shift; cd /; mst "$@"' -- "$zshrc" "$@" \
      > "$test_directory/out" 2> "$test_directory/err"; then actual=0; else actual=$?; fi
  assert_status "$@"
  [ ! -e "$test_directory/unexpected-config" ] && [ ! -e "$test_directory/unexpected-zdot" ] ||
    fail '管理命令忽略固定配置位置'
}

assert_functions() {
  env HOME="$test_home" /bin/zsh -f -c '
    source "$1"
    (( $+functions[mst] && $+functions[dsize] == $2 && $+functions[other] == $3 ))
  ' -- "$zshrc" "$1" "$2" || fail '管理器或工具加载状态错误'
}

download_count() {
  if [ -f "$test_directory/curl-log" ]; then wc -l < "$test_directory/curl-log" | tr -d ' '; else printf 0; fi
}

backup_count() {
  find "$test_home" -type f -name '*.bak.*' | wc -l | tr -d ' '
}

managed_identity() {
  for file in "$manager_directory/manager-core.sh" "$manager_directory/mst.sh" "$manager_directory/mst.zsh" \
      "$install_directory/init.zsh" "$zshrc" "$install_directory/tools/dsize/dsize.zsh" "$install_directory/tools/installed.list"; do
    if [ -f "$file" ]; then file_stat "$file"; cksum "$file"; fi
  done
}

new_home initial
run_bootstrap 0
assert_functions 0 0
[ ! -e "$install_directory/tools/dsize/dsize.zsh" ] && [ ! -e "$install_directory/tools/installed.list" ] ||
  fail '默认引导安装了具体工具'
identity=$(managed_identity)
run_bootstrap 0 --unattended
[ "$(managed_identity)" = "$identity" ] && [ "$(backup_count)" -eq 0 ] || fail '重复引导不幂等'
run_mst 0
grep -Fq 'Usage: mst' "$test_directory/out" || fail 'mst 无参数未显示帮助'
run_mst 0 list
grep -Eq '^dsize[[:space:]]+not installed[[:space:]]+' "$test_directory/out" || fail '初始工具列表错误'
run_mst 0 update
run_mst 2 upgrade dsize
run_mst 2 upgrade --all
[ "$(download_count)" -eq 0 ] || fail '本地查询或无效参数触发联网'

# 管理器升级刷新目录，不安装或更新任何具体工具。
run_mst 0 upgrade
assert_functions 0 0
[ ! -e "$install_directory/tools/installed.list" ] || fail '纯管理器升级修改工具清单'
run_mst 0 list
grep -Eq '^other[[:space:]]+not installed[[:space:]]+' "$test_directory/out" || fail '升级未发现新工具'
run_mst 0 install dsize
assert_functions 1 0
tool_matches "$fixture" dsize "$install_directory/tools/dsize/dsize.zsh" || fail '在线安装未使用新版本'
manager_identity=$(file_stat "$manager_directory/mst.zsh")
state_identity=$(file_stat "$install_directory/tools/installed.list")

# update 下载最新工具，但不会隐式升级管理器或安装新工具。
printf '\n# release three\n' >> "$fixture/tools/dsize/dsize.zsh"
printf '\n# manager release three\n' >> "$fixture/lib/mst.zsh"
sh "$fixture/scripts/build-installer.sh" > "$test_directory/build"
run_mst 0 update
tool_matches "$fixture" dsize "$install_directory/tools/dsize/dsize.zsh" || fail 'update 未获取最新工具'
[ "$(file_stat "$manager_directory/mst.zsh")" = "$manager_identity" ] || fail 'update 隐式升级管理器'
[ "$(file_stat "$install_directory/tools/installed.list")" != "$state_identity" ] || fail 'update 未记录新的工具版本'
state_identity=$(file_stat "$install_directory/tools/installed.list")
[ ! -e "$install_directory/tools/other/other.zsh" ] || fail 'update 安装新工具'
tool_identity=$(file_stat "$install_directory/tools/dsize/dsize.zsh")
run_mst 0 upgrade --no-run-zsh
[ "$(file_stat "$manager_directory/mst.zsh")" != "$manager_identity" ] || fail 'upgrade 未升级管理器'
[ "$(file_stat "$install_directory/tools/dsize/dsize.zsh")" = "$tool_identity" ] || fail 'upgrade 修改已安装工具'
[ "$(file_stat "$install_directory/tools/installed.list")" = "$state_identity" ] || fail 'upgrade 修改已安装清单'
run_mst 0 upgrade
[ "$(file_stat "$install_directory/tools/dsize/dsize.zsh")" = "$tool_identity" ] || fail '重复 upgrade 修改工具'

printf '\n# keep my existing dsize\n' >> "$install_directory/tools/dsize/dsize.zsh"
cp "$install_directory/tools/dsize/dsize.zsh" "$test_directory/kept-dsize"
run_mst 0 install other
assert_functions 1 1
cmp -s "$install_directory/tools/dsize/dsize.zsh" "$test_directory/kept-dsize" || fail '选择安装更新无关工具'

# 查询及卸载完全离线；卸载全部工具后 mst 仍可使用、更新及重新安装。
downloads=$(download_count)
download_mode=fail
run_mst 0 list
run_mst 0 uninstall dsize
assert_functions 0 1
run_mst 2 update dsize
run_mst 0 uninstall --all
assert_functions 0 0
run_mst 0 list
[ "$(download_count)" -eq "$downloads" ] || fail '离线命令触发联网'
download_mode=ok
run_mst 0 upgrade
run_mst 0 install dsize
assert_functions 1 0

# 下载失败、空文件、HTML、语法错误和其他脚本都在写配置前被拒绝。
identity=$(managed_identity)
backups=$(backup_count)
for download_mode in fail empty html syntax foreign; do
  run_mst 1 upgrade
  [ "$(managed_identity)" = "$identity" ] || fail '无效下载修改现有文件'
  [ "$(backup_count)" = "$backups" ] || fail '无效下载新增配置备份'
  [ ! -d "$install_directory/.mac-shell-tools-install.lock" ] || fail '下载失败残留锁'
  for temporary in "$test_directory/tmp"/mac-shell-tools-*; do
    [ ! -e "$temporary" ] || fail '下载失败残留暂存'
  done
done
download_mode=ok
grep -Fq 'https://raw.githubusercontent.com/bran-nie/mac-shell-tools/main/install.sh' "$test_directory/curl-log" ||
  fail '在线更新未使用官方仓库地址'

# 自定义路径包含空格、中文和引号；联网安装后的启动器仍指向这些位置。
new_home custom-paths
test_config="$test_directory/config 空格' "
test_zdot="$test_directory/zdot 空格' "
install_directory="$test_config/zsh/mac-shell-tools"
manager_directory="$install_directory/manager"
zshrc="$test_zdot/.zshrc"
run_bootstrap 0
run_mst 0 list
run_mst 0 upgrade
run_mst 0 install other
assert_functions 0 1
[ ! -e "$test_home/.zshrc" ] || fail '自定义路径污染默认主配置'
run_mst 0 upgrade
run_mst 0 uninstall --all
assert_functions 0 0

# 管理器文件链接不能被引导或常驻启动器覆盖/执行。
new_home linked-manager
run_bootstrap 0
cp "$manager_directory/manager-core.sh" "$test_directory/linked-core-target"
rm "$manager_directory/manager-core.sh"
ln -s "$test_directory/linked-core-target" "$manager_directory/manager-core.sh"
run_bootstrap 1 upgrade
run_mst 1 list
[ -L "$manager_directory/manager-core.sh" ] || fail '管理器符号链接被覆盖'

# 流式引导也只安装 mst；无需原安装脚本即可在另一个目录查询。
new_home stdin-bootstrap
if cat "$project_dir/install.sh" | env HOME="$test_home" XDG_CONFIG_HOME= ZDOTDIR= \
    TMPDIR="$test_directory/tmp" RUNZSH=no PATH="$test_directory/mock:$PATH" MST_RELEASE="$project_dir/install.sh" /bin/sh \
    > "$test_directory/out" 2> "$test_directory/err"; then actual=0; else actual=$?; fi
expected=0
assert_status 流式引导
assert_functions 0 0
run_mst 0 list
printf 'PASS mst: %s 项常驻管理、在线升级及隔离断言。\n' "$checks"
