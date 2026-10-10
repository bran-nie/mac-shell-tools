#!/bin/sh
# 以隔离 HOME 验证安装、升级和故障；没有任何真实用户配置写入。
# 断言文件内容及配置保留，不绑定随机备份名或暂存实现细节。
set -eu
project_dir=$1
. "$project_dir/tests/common.sh"
installer="$project_dir/install.sh"
test_directory=$(mktemp -d "${TMPDIR:-/tmp}/mac-shell-tools-install-test.XXXXXX")
trap 'chmod -R u+rwX "$test_directory"; rm -rf "$test_directory"' 0
trap 'exit 1' HUP INT TERM
checks=0

# 失败立即结束，保留在终端中的具体断言和安装器诊断。
fail() {
  printf 'FAIL install: %s\n' "$*" >&2
  cat "$test_directory/err" >&2
  exit 1
}

# 每个用例拥有新的 HOME，避免前一安装状态掩盖问题。
new_home() {
  test_home="$test_directory/$1/home"
  install_directory="$test_home/.config/zsh/mac-shell-tools"
  zshrc="$test_home/.zshrc"
  mkdir -p "$test_home"
}

# 额外环境参数覆盖默认值，用于路径、依赖和写入失败注入。
run_install() {
  expected=$1
  label=$2
  shift 2
  if env HOME="$test_home" XDG_CONFIG_HOME= ZDOTDIR= "$@" /bin/sh "$installer" install \
      > "$test_directory/out" 2> "$test_directory/err"; then actual=0; else actual=$?; fi
  [ "$actual" -eq "$expected" ] || fail "$label: 预期 $expected，实际 $actual"
  if [ "$expected" -ne 0 ] && [ ! -s "$test_directory/err" ]; then fail "$label: 缺少诊断"; fi
  checks=$((checks + 1))
}

# 安装后在干净 Zsh 中加载配置，检测引用转义及工具是否实际可用。
assert_usable() {
  env HOME="$test_home" XDG_CONFIG_HOME="$test_directory/different-config" ZDOTDIR= \
    /bin/zsh -f -c 'source "$1"; (( $+functions[dsize] )); dsize --help >/dev/null' -- "$1" ||
    fail '安装后不能加载 dsize'
}

# 统计备份数量只遍历当前用例，不触碰其他用户目录。
backup_count() {
  find "$test_home" -type f -name '*.bak.*' | wc -l | tr -d ' '
}

# 文件标识和时间一起验证真正的幂等，不依赖等待跨过时间戳精度。
file_identity() {
  file_stat "$zshrc" "$install_directory/init.zsh" "$install_directory/tools/dsize/dsize.zsh"
}

new_home first
run_install 0 首次安装
tool_matches "$project_dir" dsize "$install_directory/tools/dsize/dsize.zsh" || fail '工具内容不一致'
assert_usable "$zshrc"
[ "$(backup_count)" -eq 0 ] || fail '首次安装不应产生备份'
identity=$(file_identity)
run_install 0 重复安装
[ "$(file_identity)" = "$identity" ] || fail '重复安装重写了文件'
[ "$(backup_count)" -eq 0 ] || fail '重复安装新增备份'
[ "$(awk '$0 == "# >>> mac-shell-tools >>>" { n++ } END { print n }' "$zshrc")" -eq 1 ] || fail '入口重复注册'

new_home preserve
cat > "$zshrc" <<'CONFIG'
# unrelated settings and references
export USER_SETTING=preserved
source "$HOME/custom-config.zsh"
CONFIG
printf 'export CUSTOM_SETTING=preserved\n' > "$test_home/custom-config.zsh"
printf '# independently managed aliases\n' > "$test_home/.zshrc_alias"
cp "$zshrc" "$test_directory/original-zshrc"
cp "$test_home/.zshrc_alias" "$test_directory/original-alias"
run_install 0 已有主配置
grep -Fq 'source "$HOME/custom-config.zsh"' "$zshrc" || fail '改写了用户 source 引用'
cmp -s "$test_home/.zshrc_alias" "$test_directory/original-alias" || fail '改写了别名配置'
[ "$(backup_count)" -eq 1 ] || fail '缺少主配置备份'
for backup in "$install_directory"/backups/zshrc/.zshrc.bak.*; do
  cmp -s "$backup" "$test_directory/original-zshrc" || fail '主配置备份内容不完整'
done
assert_usable "$zshrc"

# 修改管理内容并添加用户区域，检查更新只替换管理区域。
printf '\n# customized dsize\n' >> "$install_directory/tools/dsize/dsize.zsh"
cp "$install_directory/tools/dsize/dsize.zsh" "$test_directory/custom-dsize"
awk '/^# <<< mac-shell-tools managed tools <<</ { print ": # stale managed command" } { print }' \
  "$install_directory/init.zsh" > "$test_directory/changed-init"
cat "$test_directory/changed-init" > "$install_directory/init.zsh"
cat >> "$install_directory/init.zsh" <<'CUSTOM'
# extra tool stays registered
source "${${(%):-%x}:A:h}/extra.zsh"
CUSTOM
printf 'export EXTRA_TOOL=loaded\n' > "$install_directory/extra.zsh"
printf '# setting after managed block\n' >> "$zshrc"
cp "$install_directory/init.zsh" "$test_directory/custom-init"
cp "$zshrc" "$test_directory/custom-zshrc"
run_install 0 更新
tool_matches "$project_dir" dsize "$install_directory/tools/dsize/dsize.zsh" || fail '没有更新工具'
grep -Fq '# extra tool stays registered' "$install_directory/init.zsh" || fail '丢失入口用户区域'
if grep -Fq 'stale managed command' "$install_directory/init.zsh"; then fail '管理区域未刷新'; fi
grep -Fq '# setting after managed block' "$zshrc" || fail '丢失主配置用户内容'
[ "$(tail -n 1 "$zshrc")" = '# <<< mac-shell-tools <<<' ] || fail '入口没有移到主配置末尾'
[ "$(backup_count)" -eq 4 ] || fail '更新没有备份所有变化文件'
for saved in dsize init zshrc; do
  case $saved in
    dsize) target="$install_directory/backups/tools/dsize/dsize.zsh" ;;
    init) target="$install_directory/backups/init.zsh" ;;
    zshrc) target="$install_directory/backups/zshrc/.zshrc" ;;
  esac
  found=0
  for backup in "$target".bak.*; do
    if cmp -s "$backup" "$test_directory/custom-$saved"; then found=1; fi
  done
  [ "$found" -eq 1 ] || fail "缺少完整 $saved 更新备份"
done
env HOME="$test_home" /bin/zsh -f -c 'source "$HOME/.zshrc"; [[ $EXTRA_TOOL == loaded && $USER_SETTING == preserved && $CUSTOM_SETTING == preserved ]]' || fail '自定义工具未加载'
assert_usable "$zshrc"
identity=$(file_identity)
run_install 0 更新后幂等
[ "$(file_identity)" = "$identity" ] || fail '自定义区域导致重复重写'

# 固定同一时间戳连续更新，随机后缀仍须保留两个不同的恢复副本。
mkdir "$test_directory/mock"
cat > "$test_directory/mock/date" <<'MOCK'
#!/bin/sh
printf '20260101-010101\n'
MOCK
chmod +x "$test_directory/mock/date"
for revision in one two; do
  printf '\n# change %s\n' "$revision" >> "$install_directory/tools/dsize/dsize.zsh"
  cp "$install_directory/tools/dsize/dsize.zsh" "$test_directory/revision-$revision"
  run_install 0 快速连续备份 PATH="$test_directory/mock:$PATH"
done
for revision in one two; do
  found=0
  for backup in "$install_directory"/backups/tools/dsize/dsize.zsh.bak.20260101-010101.*; do
    if cmp -s "$backup" "$test_directory/revision-$revision"; then found=1; fi
  done
  [ "$found" -eq 1 ] || fail '同时间戳备份被覆盖'
done

new_home custom-paths
custom_config="$test_directory/config 空格' "'$value'
custom_zdot="$test_directory/zdot 空格' "'$value'
run_install 0 自定义路径 XDG_CONFIG_HOME="$custom_config" ZDOTDIR="$custom_zdot"
tool_matches "$project_dir" dsize "$custom_config/zsh/mac-shell-tools/tools/dsize/dsize.zsh" || fail '工具未安装到 XDG 路径'
assert_usable "$custom_zdot/.zshrc"
[ ! -e "$test_home/.zshrc" ] || fail '忽略了 ZDOTDIR'
for assignment in XDG_CONFIG_HOME=relative ZDOTDIR=relative HOME=relative; do
  new_home relative-path
  run_install 1 拒绝相对路径 "$assignment"
done

# 未知入口和损坏标记必须在替换工具或主配置之前拒绝。
new_home unknown-init
mkdir -p "$install_directory"
printf '# personal entry\n' > "$install_directory/init.zsh"
cp "$install_directory/init.zsh" "$test_directory/unknown-init.snapshot"
run_install 1 未知入口
cmp -s "$install_directory/init.zsh" "$test_directory/unknown-init.snapshot" || fail '覆盖未知入口'
[ ! -e "$zshrc" ] && [ ! -e "$install_directory/tools/dsize/dsize.zsh" ] || fail '失败前已修改配置'

for malformed in incomplete reversed duplicate similar; do
  new_home "malformed-$malformed"
  case $malformed in
    incomplete) printf '# >>> mac-shell-tools >>>\n' > "$zshrc" ;;
    reversed) printf '# <<< mac-shell-tools <<<\n# >>> mac-shell-tools >>>\n' > "$zshrc" ;;
    duplicate) printf '# >>> mac-shell-tools >>>\n# <<< mac-shell-tools <<<\n# >>> mac-shell-tools >>>\n# <<< mac-shell-tools <<<\n' > "$zshrc" ;;
    similar) printf ' # >>> mac-shell-tools >>>\n' > "$zshrc" ;;
  esac
  cp "$zshrc" "$test_directory/bad-zshrc"
  run_install 1 损坏标记
  cmp -s "$zshrc" "$test_directory/bad-zshrc" || fail '改写损坏配置'
  [ ! -e "$install_directory/tools/dsize/dsize.zsh" ] || fail '损坏配置仍写入工具'
done
new_home invalid-syntax
printf 'if invalid shell syntax\n' > "$zshrc"
run_install 1 主配置语法错误
[ ! -e "$install_directory/tools/dsize/dsize.zsh" ] || fail '语法检查失败后仍写入工具'

for linked in zshrc init dsize directory; do
  new_home "symlink-$linked"
  mkdir -p "$install_directory/tools/dsize"
  case $linked in
    zshrc) link=$zshrc ;;
    init) link="$install_directory/init.zsh" ;;
    dsize) link="$install_directory/tools/dsize/dsize.zsh" ;;
    directory) rm -r "$install_directory"; link=$install_directory ;;
  esac
  original="$test_home/link-target"
  if [ "$linked" = directory ]; then mkdir "$original"; else printf '# link target\n' > "$original"; fi
  ln -s "$original" "$link"
  run_install 1 保留符号链接
  [ -L "$link" ] && [ "$(readlink "$link")" = "$original" ] || fail '符号链接被替换'
  if [ "$linked" != directory ]; then
    [ "$(cat "$original")" = '# link target' ] || fail '符号链接目标被改写'
  fi
done

new_home directory-target
mkdir "$zshrc"
run_install 1 目标类型错误
new_home unwritable
printf '# readonly\n' > "$zshrc"
chmod 400 "$zshrc"
if [ ! -w "$zshrc" ]; then
  run_install 1 文件不可写
  [ ! -e "$install_directory/tools/dsize/dsize.zsh" ] || fail '权限预检失败后仍写入工具'
fi
chmod 600 "$zshrc"
new_home occupied-lock
mkdir -p "$install_directory/.mac-shell-tools-install.lock"
run_install 1 安装锁
[ -d "$install_directory/.mac-shell-tools-install.lock" ] || fail '移除了非本进程安装锁'

# 文件替换失败后不能留下引用不存在入口的主配置，并可重新安装恢复。
cat > "$test_directory/mock/mv" <<'MOCK'
#!/bin/sh
for destination do :; done
case $destination in
  */init.zsh) printf 'simulated rename failure\n' >&2; exit 1 ;;
esac
exec /bin/mv "$@"
MOCK
chmod +x "$test_directory/mock/mv"
new_home write-failure
run_install 1 替换失败 PATH="$test_directory/mock:$PATH"
[ ! -e "$zshrc" ] && [ ! -e "$install_directory/init.zsh" ] || fail '失败留下悬空主配置引用'
[ ! -d "$install_directory/.mac-shell-tools-install.lock" ] || fail '失败未清理安装锁'
[ "$(find "$install_directory" -name '.mac-shell-tools.*' | wc -l | tr -d ' ')" -eq 0 ] || fail '失败未清理暂存文件'
rm "$test_directory/mock/mv"
run_install 0 失败后恢复
assert_usable "$zshrc"

# 模拟写入主配置时空间不足，原内容及备份仍完整可恢复。
cat > "$test_directory/mock/cat" <<'MOCK'
#!/bin/sh
case ${1:-} in
  */next-zshrc) printf 'simulated no space left\n' >&2; exit 1 ;;
esac
exec /bin/cat "$@"
MOCK
chmod +x "$test_directory/mock/cat"
new_home disk-failure
printf '# original config\n' > "$zshrc"
cp "$zshrc" "$test_directory/disk-original"
run_install 1 写入失败 PATH="$test_directory/mock:$PATH"
cmp -s "$zshrc" "$test_directory/disk-original" || fail '写入失败破坏原配置'
for backup in "$install_directory"/backups/zshrc/.zshrc.bak.*; do
  cmp -s "$backup" "$test_directory/disk-original" || fail '写入失败未保留完整备份'
done
rm "$test_directory/mock/cat"

# 单文件与 stdin 模式均不依赖源码所在目录。
new_home standalone
mkdir "$test_directory/share"
cp "$installer" "$test_directory/share/standalone.sh"
installer="$test_directory/share/standalone.sh"
run_install 0 独立脚本
assert_usable "$zshrc"
new_home stdin
if cat "$installer" | env HOME="$test_home" XDG_CONFIG_HOME= ZDOTDIR= /bin/sh -s -- install \
    > "$test_directory/out" 2> "$test_directory/err"; then checks=$((checks + 1)); else fail 'stdin 安装失败'; fi
assert_usable "$zshrc"
printf 'PASS install: %s 项安装检查及配置保留断言。\n' "$checks"
