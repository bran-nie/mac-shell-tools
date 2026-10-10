#!/bin/sh
# 用临时双工具安装包验证管理语义；不会给仓库新增演示工具。
set -eu
project_dir=$1
test_directory=$(mktemp -d "${TMPDIR:-/tmp}/mac-shell-tools-management-test.XXXXXX")
trap 'chmod -R u+rwX "$test_directory"; rm -rf "$test_directory"' 0
trap 'exit 1' HUP INT TERM
checks=0
fixture="$test_directory/package"
mkdir -p "$fixture/scripts" "$fixture/tools" "$fixture/lib"
cp "$project_dir/scripts/build-installer.sh" "$project_dir/scripts/installer.sh.in" "$project_dir/scripts/bootstrap.sh.in" "$fixture/scripts/"
cp "$project_dir/lib/mst.zsh" "$fixture/lib/"
cp "$project_dir/tools/init.zsh" "$project_dir/tools/dsize.zsh" "$fixture/tools/"
cp "$project_dir/LICENSE" "$fixture/LICENSE"
printf '%s\n' dsize.zsh other.zsh > "$fixture/scripts/tools.list"
printf '%s\n' 'other() { print -r -- other-ready; }' > "$fixture/tools/other.zsh"
sh "$fixture/scripts/build-installer.sh" > "$test_directory/build"
installer="$fixture/install.sh"

fail() {
  printf 'FAIL management: %s\n' "$*" >&2
  cat "$test_directory/out" "$test_directory/err" >&2
  exit 1
}

new_home() {
  test_home="$test_directory/$1/home"
  test_config=
  test_zdot=
  install_directory="$test_home/.config/zsh/tools"
  zshrc="$test_home/.zshrc"
  mkdir -p "$test_home"
}

run() {
  expected=$1
  shift
  if env HOME="$test_home" XDG_CONFIG_HOME="$test_config" ZDOTDIR="$test_zdot" RUNZSH=no \
      /bin/sh "$installer" "$@" > "$test_directory/out" 2> "$test_directory/err"; then
    actual=0
  else
    actual=$?
  fi
  [ "$actual" -eq "$expected" ] || fail "$*: 预期 ${expected}，实际 $actual"
  if [ "$expected" -ne 0 ] && [ ! -s "$test_directory/err" ]; then fail '失败没有诊断'; fi
  checks=$((checks + 1))
}

assert_functions() {
  env HOME="$test_home" /bin/zsh -f -c '
    source "$1"
    (( $+functions[dsize] == $2 && $+functions[other] == $3 ))
  ' -- "$zshrc" "$1" "$2" || fail '实际加载的工具与选择不符'
}

# 查询、无安装时的更新和参数错误均不得创建配置。
new_home untouched
run 0 --help
run 0 list
grep -Eq '^other[[:space:]]+not installed$' "$test_directory/out" || fail 'list 缺少可用工具'
run 0 update
run 0 uninstall --all
run 0 uninstall dsize
for invalid in unknown --invalid; do run 2 "$invalid"; done
run 2 install unknown
run 2 update dsize
run 2 uninstall unknown
run 2 uninstall
run 2 install dsize --all
run 2 list dsize
run 2 list --all
run 2 install ../dsize
run 2 install -- -dsize
[ ! -e "$test_home/.config" ] && [ ! -e "$zshrc" ] || fail '只读或无效命令创建配置'

new_home incremental
run 0 install other
[ ! -e "$install_directory/dsize.zsh" ] || fail '选择安装仍安装了所有工具'
assert_functions 0 1
[ "$(cat "$install_directory/.mac-shell-tools-installed")" = other.zsh ] || fail '安装清单不准确'
other_identity=$(stat -f '%i:%m' "$install_directory/other.zsh")
run 0 install dsize dsize
assert_functions 1 1
[ "$(stat -f '%i:%m' "$install_directory/other.zsh")" = "$other_identity" ] || fail '增量安装重写了其他工具'
[ "$(wc -l < "$install_directory/.mac-shell-tools-installed" | tr -d ' ')" -eq 2 ] || fail '重复工具未去重'
state_identity=$(stat -f '%i:%m' "$install_directory/.mac-shell-tools-installed")
run 0 install dsize
[ "$(stat -f '%i:%m' "$install_directory/.mac-shell-tools-installed")" = "$state_identity" ] || fail '重复安装重写清单'
run 0 list
grep -Eq '^dsize[[:space:]]+installed$' "$test_directory/out" || fail 'list 安装状态错误'

# 单独更新不碰另一个工具；更新全集不能重新安装已卸载工具。
printf '\n# personal other revision\n' >> "$install_directory/other.zsh"
cp "$install_directory/other.zsh" "$test_directory/other-revision"
printf '\n# stale dsize\n' >> "$install_directory/dsize.zsh"
run 0 update dsize
cmp -s "$install_directory/dsize.zsh" "$fixture/tools/dsize.zsh" || fail '指定更新未生效'
cmp -s "$install_directory/other.zsh" "$test_directory/other-revision" || fail '指定更新影响其他工具'
printf '# unrelated tool\n' > "$install_directory/personal.zsh"
run 0 uninstall dsize
[ ! -e "$install_directory/dsize.zsh" ] || fail '单独卸载没有删除工具'
assert_functions 0 1
[ "$(cat "$install_directory/.mac-shell-tools-installed")" = other.zsh ] || fail '卸载清单错误'
[ -f "$install_directory/personal.zsh" ] || fail '卸载删除个人文件'
found_backup=no
for backup in "$install_directory"/dsize.zsh.bak.*; do
  if cmp -s "$backup" "$fixture/tools/dsize.zsh"; then found_backup=yes; fi
done
[ "$found_backup" = yes ] || fail '卸载缺少完整备份'
run 0 update --all
[ ! -e "$install_directory/dsize.zsh" ] || fail 'update 重新安装已卸载工具'
cmp -s "$install_directory/other.zsh" "$fixture/tools/other.zsh" || fail '更新已安装工具失败'
run 2 update dsize
run 0 uninstall dsize

# 已卸载后的同名个人文件不属于清单，不能因重复卸载而删除。
printf '# unregistered personal file\n' > "$install_directory/dsize.zsh"
run 0 uninstall dsize
[ "$(cat "$install_directory/dsize.zsh")" = '# unregistered personal file' ] || fail '删除未登记同名文件'
run 0 uninstall --all
[ ! -e "$install_directory/other.zsh" ] && [ -f "$install_directory/init.zsh" ] || fail '末项卸载未保留管理入口'
[ ! -e "$install_directory/.mac-shell-tools-installed" ] || fail '末项卸载残留清单'
[ -f "$install_directory/personal.zsh" ] && [ -f "$install_directory/dsize.zsh" ] || fail '全卸载删除无关文件'
grep -Fq '# >>> mac-shell-tools >>>' "$zshrc" || fail '卸载全部工具后管理器无法加载'
env HOME="$test_home" /bin/zsh -f -c 'source "$HOME/.zshrc"; (( $+functions[mst] )); mst list' \
  > "$test_directory/list-after-uninstall" || fail '卸载全部工具后 mst 不可用'
grep -Fq 'exec zsh -l' "$test_directory/out" || fail '卸载未提示清除内存函数'
run 0 uninstall --all

# 个人入口区域存在时，保留入口与原引用，仅清空项目注册。
new_home custom-entry
printf '%s\n' 'export PERSONAL_SETTING=kept' > "$zshrc"
run 0 --all
printf '%s\n' 'export PERSONAL_ENTRY=kept' >> "$install_directory/init.zsh"
cp "$zshrc" "$test_directory/custom-rc"
run 0 uninstall --all
cmp -s "$zshrc" "$test_directory/custom-rc" || fail '自定义入口卸载改写引用'
[ -f "$install_directory/init.zsh" ] || fail '删除个人入口'
env HOME="$test_home" /bin/zsh -f -c '
  source "$HOME/.zshrc"
  [[ $PERSONAL_SETTING == kept && $PERSONAL_ENTRY == kept ]]
  (( ! $+functions[dsize] && ! $+functions[other] ))
' || fail '自定义入口丢失或未卸载工具'
run 0 install other
assert_functions 0 1

# 无清单时只认可项目管理区里的明确注册，不推断同名文件归属。
new_home without-state
run 0 install dsize
rm "$install_directory/.mac-shell-tools-installed"
printf '# not registered\n' > "$install_directory/other.zsh"
run 0 uninstall --all
[ ! -e "$install_directory/dsize.zsh" ] && [ -f "$install_directory/other.zsh" ] || fail '无清单时的所有权识别错误'

# 安装包不再提供某个已登记工具时，保留它；仍可显式卸载。
new_home unavailable
run 0 install other
installer="$project_dir/install.sh"
run 0 list
grep -Fq 'unavailable in this installer' "$test_directory/out" || fail '未列出不在安装包中的已装工具'
run 0 update
[ -f "$install_directory/other.zsh" ] || fail '更新删除安装包外的工具'
run 2 update other
run 0 install dsize
assert_functions 1 1
run 0 uninstall other
assert_functions 1 0
installer="$fixture/install.sh"

# 丢失的已登记工具可由 update 修复；格式错误和链接不应执行或覆盖。
new_home state-errors
run 0 install dsize
rm "$install_directory/dsize.zsh"
run 0 list
grep -Fq 'file missing' "$test_directory/out" || fail '未报告工具文件缺失'
run 0 update
cmp -s "$install_directory/dsize.zsh" "$fixture/tools/dsize.zsh" || fail '未修复丢失文件'
state_file="$install_directory/.mac-shell-tools-installed"
cp "$state_file" "$test_directory/good-state"
for corrupt in traversal duplicate blank executable reserved manager; do
  case $corrupt in
    traversal) printf '../outside.zsh\n' > "$state_file" ;;
    duplicate) printf 'dsize.zsh\ndsize.zsh\n' > "$state_file" ;;
    blank) printf '\n' > "$state_file" ;;
    executable) printf 'touch %s/executed\n' "$test_home" > "$state_file" ;;
    reserved) printf 'init.zsh\n' > "$state_file" ;;
    manager) printf 'mst.zsh\n' > "$state_file" ;;
  esac
  run 1 uninstall --all
  [ -f "$install_directory/dsize.zsh" ] && [ ! -e "$test_home/executed" ] || fail '无效清单产生副作用'
done
cp "$test_directory/good-state" "$state_file"
mv "$state_file" "$test_directory/state-target"
ln -s "$test_directory/state-target" "$state_file"
run 1 update
[ -L "$state_file" ] || fail '替换清单链接'
rm "$state_file"
cp "$test_directory/good-state" "$state_file"
cp "$install_directory/dsize.zsh" "$test_directory/tool-target"
rm "$install_directory/dsize.zsh"
ln -s "$test_directory/tool-target" "$install_directory/dsize.zsh"
run 1 uninstall --all
cmp -s "$state_file" "$test_directory/good-state" || fail '卸载预检失败改写清单'
[ -L "$install_directory/dsize.zsh" ] || fail '卸载替换工具链接'

new_home readonly-uninstall
run 0 install dsize other
chmod 400 "$install_directory/dsize.zsh"
if [ ! -w "$install_directory/dsize.zsh" ]; then
  cp "$install_directory/init.zsh" "$test_directory/readonly-init"
  run 1 uninstall --all
  cmp -s "$install_directory/init.zsh" "$test_directory/readonly-init" || fail '权限预检失败已改写入口'
  [ -f "$install_directory/other.zsh" ] || fail '权限预检失败删除其他工具'
fi

# 删除失败和备份失败覆盖卸载中途的可恢复状态。
# 删除失败保留完整备份和清单，可重试恢复；不能留下自己的锁或暂存。
new_home removal-failure
run 0 install dsize other
mkdir "$test_directory/failing-bin"
cat > "$test_directory/failing-bin/rm" <<'MOCK'
#!/bin/sh
case ${1:-} in
  */dsize.zsh) printf 'simulated removal failure\n' >&2; exit 1 ;;
esac
exec /bin/rm "$@"
MOCK
chmod +x "$test_directory/failing-bin/rm"
if env HOME="$test_home" XDG_CONFIG_HOME= ZDOTDIR= RUNZSH=no \
    PATH="$test_directory/failing-bin:$PATH" /bin/sh "$installer" uninstall dsize \
    > "$test_directory/out" 2> "$test_directory/err"; then
  fail '删除失败应报错'
fi
checks=$((checks + 1))
[ -f "$install_directory/dsize.zsh" ] && [ -f "$install_directory/other.zsh" ] || fail '删除失败丢失原文件'
grep -Fxq dsize.zsh "$install_directory/.mac-shell-tools-installed" || fail '删除失败过早清除清单'
[ ! -d "$install_directory/.mac-shell-tools-install.lock" ] || fail '删除失败残留锁'
[ "$(find "$install_directory" -name '.mac-shell-tools.*' | wc -l | tr -d ' ')" -eq 0 ] || fail '删除失败残留暂存'
found_backup=no
for backup in "$install_directory"/dsize.zsh.bak.*; do
  if cmp -s "$backup" "$fixture/tools/dsize.zsh"; then found_backup=yes; fi
done
[ "$found_backup" = yes ] || fail '删除失败缺少备份'
run 0 uninstall dsize
assert_functions 0 1

# 备份失败不能删除目标文件；先移除注册的中间状态可由同一命令修复。
new_home backup-failure
run 0 install dsize other
cat > "$test_directory/failing-bin/cp" <<'MOCK'
#!/bin/sh
case ${2:-} in
  */dsize.zsh) printf 'simulated backup failure\n' >&2; exit 1 ;;
esac
exec /bin/cp "$@"
MOCK
chmod +x "$test_directory/failing-bin/cp"
if env HOME="$test_home" XDG_CONFIG_HOME= ZDOTDIR= RUNZSH=no \
    PATH="$test_directory/failing-bin:$PATH" /bin/sh "$installer" uninstall dsize \
    > "$test_directory/out" 2> "$test_directory/err"; then
  fail '备份失败应报错'
fi
checks=$((checks + 1))
[ -f "$install_directory/dsize.zsh" ] || fail '备份失败仍删除工具'
[ ! -d "$install_directory/.mac-shell-tools-install.lock" ] || fail '备份失败残留锁'
run 0 uninstall dsize
assert_functions 0 1

# 自定义路径、stdin 和 sh -c 入口均需正确转发管理参数。
new_home custom-paths
test_config="$test_directory/config 空格' "
test_zdot="$test_directory/zdot 空格' "
install_directory="$test_config/zsh/tools"
zshrc="$test_zdot/.zshrc"
run 0 install other
assert_functions 0 1
run 0 uninstall --all
[ ! -e "$test_home/.zshrc" ] && [ ! -e "$install_directory/other.zsh" ] || fail '自定义路径卸载错误'

new_home stdin-arguments
if cat "$installer" | env HOME="$test_home" XDG_CONFIG_HOME= ZDOTDIR= /bin/sh -s -- install other \
    > "$test_directory/out" 2> "$test_directory/err"; then checks=$((checks + 1)); else fail 'stdin 参数失败'; fi
assert_functions 0 1
env HOME="$test_home" XDG_CONFIG_HOME= ZDOTDIR= RUNZSH=no \
  /bin/sh -c "$(cat "$installer")" -- uninstall other > "$test_directory/out" 2> "$test_directory/err" ||
  fail 'sh -c 参数失败'
checks=$((checks + 1))
[ ! -e "$install_directory/other.zsh" ] || fail 'sh -c 未执行卸载参数'
printf 'PASS management: %s 项管理操作及文件保留断言。\n' "$checks"
