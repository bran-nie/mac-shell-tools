#!/bin/zsh
# 验证真实扫描的树形结构及原生平铺管道，并覆盖输入、失败及 Shell 隔离。
# 固定 du 数据另外验证大小精度、同量祖先、树枝和深层展示。
emulate -R zsh
setopt nounset pipefail
project_directory=$1
test_directory=$(mktemp -d "${TMPDIR:-/tmp}/mac-shell-tools-dsize-test.XXXXXX") || exit 1
restricted_directory=$test_directory/restricted
trap 'chmod -R u+rwx "$restricted_directory" 2>/dev/null; rm -rf "$test_directory"' EXIT
trap 'exit 1' HUP INT TERM
checks=0

# 断言失败输出具体上下文，不在失败后继续制造连带结果。
fail() {
  print -ru2 -- "FAIL dsize: $*"
  exit 1
}

# 捕获实际退出码与输出，错误断言同时要求有简短诊断。
expect_status() {
  local expected=$1 label=$2 actual
  shift 2
  "$@" > "$test_directory/out" 2> "$test_directory/err"
  actual=$?
  [[ $actual == $expected ]] || fail "$label: 预期 $expected，实际 $actual；$(<"$test_directory/err")"
  if (( expected )); then
    [[ -s "$test_directory/err" ]] || fail "$label: 缺少错误说明"
  fi
  (( checks++ ))
  return 0
}

# 平铺兼容格式逐字对比当前平台的系统命令。
compare_reference() {
  local label=$1 expected_depth=$2 expected_lines=$3 expected_directory=$4
  shift 4
  /usr/bin/du -h -d "$expected_depth" "$expected_directory" 2>/dev/null |
    /usr/bin/sort -h | /usr/bin/tail -n "$expected_lines" > "$test_directory/expected" || fail "$label: 基线失败"
  expect_status 0 "$label" dsize --flat "$@"
  cmp -s "$test_directory/expected" "$test_directory/out" || fail "$label: 输出与系统管道不同"
  [[ ! -s "$test_directory/err" ]] || fail "$label: 成功时出现错误输出"
}

# 真实扫描只去掉大小列，直接与手写的树形结构比较。
compare_tree() {
  local label=$1
  shift
  cat > "$test_directory/expected"
  expect_status 0 "$label" dsize "$@"
  sed -E 's/^ *[0-9.]+[BKMGTPE]  //' "$test_directory/out" > "$test_directory/actual-tree"
  cmp -s "$test_directory/expected" "$test_directory/actual-tree" || fail "$label: 树形结构不符；$(<"$test_directory/out")"
  [[ ! -s "$test_directory/err" ]] || fail "$label: 成功时出现错误输出"
}

mkdir -p "$test_directory/tree/small/deeper/deepest" "$test_directory/tree/空格 path" \
  "$test_directory/tree/-example" "$test_directory/mock" "$restricted_directory/hidden"
dd if=/dev/zero of="$test_directory/tree/root-file" bs=1024 count=64 2>/dev/null
dd if=/dev/zero of="$test_directory/tree/small/deeper/deepest/file" bs=1024 count=1024 2>/dev/null
dd if=/dev/zero of="$test_directory/tree/空格 path/file" bs=1024 count=16 2>/dev/null
dd if=/dev/zero of="$restricted_directory/hidden/file" bs=1024 count=8 2>/dev/null

cd "$test_directory/tree" || exit 1
before_directory=$PWD
before_options=$(setopt)
before_traps=$(trap)
source "$project_directory/tools/init.zsh" > "$test_directory/load-out" 2> "$test_directory/load-err"
[[ ! -s "$test_directory/load-out" && ! -s "$test_directory/load-err" ]] || fail '加载产生无关输出'
[[ $PWD == $before_directory && $(setopt) == $before_options && $(trap) == $before_traps ]] || fail '加载改变 Shell 状态'
compare_reference 默认 2 25 .
compare_reference 显式目录 2 25 "$PWD" "$PWD"
compare_reference 只设条数 2 2 . -n 2
compare_reference 只设深度 0 25 . -d 0
compare_reference 混合顺序 3 4 small -n 4 small -d 3
compare_reference 目录在前 3 4 small small -d 3 -n 4
compare_reference 长参数 3 30 small --depth 3 small --lines 30
compare_reference 等号写法 3 30 small small --depth=3 --lines=30
compare_reference 空格中文 2 25 '空格 path' '空格 path'
compare_reference 相对路径 2 25 small/deeper small/deeper
compare_reference 连字符目录 2 25 ./-example -- -example
compare_reference 显式点前缀 2 25 ./-example ./-example
compare_reference 前导零 8 25 . --depth=0008 --lines=00025
compare_reference 零深度 0 1 . --depth=000 --lines=0001
compare_reference 重复覆盖 1 2 . -d invalid --depth=1 --lines=0 -n 2
compare_reference 最大边界 1000 1000000 . -d 1000 -n 1000000
compare_reference 分隔符在末尾 2 25 small small --
compare_reference 分隔符后选项样路径 2 25 ./-example -d 2 -- -example
compare_reference 最大条目 2 1 . -n 1
[[ $(<"$test_directory/out") == *$'\t.' ]] || fail '最后一行应为最大目标汇总'
compare_tree 默认树形 <<'TREE'
.
├── small
│   └── deeper
├── 空格 path
└── -example
TREE
compare_tree 树形截取 -n 3 <<'TREE'
.
└── small
    └── deeper
TREE
compare_tree 只显示汇总 -n 1 <<'TREE'
.
TREE
compare_tree 零深度树形 -d 0 <<'TREE'
.
TREE
compare_tree 更深树形 small -d 3 <<'TREE'
small
└── deeper
    └── deepest
TREE
compare_tree 尾斜杠 small/ <<'TREE'
small/
└── deeper
    └── deepest
TREE
compare_tree 连续斜杠 small/// <<'TREE'
small///
└── deeper
    └── deepest
TREE
compare_tree 点路径 small/. <<'TREE'
small/.
└── deeper
    └── deepest
TREE
compare_tree 父路径 small/../small <<'TREE'
small/../small
└── deeper
    └── deepest
TREE
compare_tree 连字符树形 -- -example <<'TREE'
./-example
TREE
special_directory="$test_directory/中文 空格 \\ [a] \$name"
mkdir -p "$special_directory/子目录 \\ [b] \$child"
compare_tree 特殊字符树形 "$special_directory" <<TREE
$special_directory
└── 子目录 \\ [b] \$child
TREE

# 排除规则累加，并且在真实扫描时跳过任意层级的同名目录。
compare_tree 排除目录名 --exclude small <<'TREE'
.
├── 空格 path
└── -example
TREE
compare_tree 排除通配模式 --exclude='sma*' <<'TREE'
.
├── 空格 path
└── -example
TREE
compare_tree 多规则与空格名称 -e small --exclude='空格 path' <<'TREE'
.
└── -example
TREE
compare_tree 排除后截取 --exclude small -n 2 <<'TREE'
.
└── 空格 path
TREE
compare_tree 排除连字符名称 --exclude=-example <<'TREE'
.
├── small
│   └── deeper
└── 空格 path
TREE
expect_status 0 排除根目录 dsize . --exclude=.
[[ ! -s "$test_directory/out" && ! -s "$test_directory/err" ]] || fail '匹配根目录时应成功且无输出'

filter_directory="$test_directory/filters"
mkdir -p "$filter_directory/node_modules/cache" "$filter_directory/.git/objects" \
  "$filter_directory/keep/node_modules/cache"
dd if=/dev/zero of="$filter_directory/node_modules/cache/data" bs=1024 count=64 2>/dev/null
dd if=/dev/zero of="$filter_directory/.git/objects/data" bs=1024 count=32 2>/dev/null
dd if=/dev/zero of="$filter_directory/keep/node_modules/cache/data" bs=1024 count=128 2>/dev/null
dd if=/dev/zero of="$filter_directory/keep/data" bs=1024 count=16 2>/dev/null
compare_tree 排除所有层级 "$filter_directory" -e node_modules --exclude .git <<TREE
$filter_directory
└── keep
TREE
expect_status 0 排除后平铺总量 dsize "$filter_directory" --flat -d 0 -e node_modules --exclude=.git
cp "$test_directory/out" "$test_directory/filtered-total"
# 把排除项实际移出目标目录，使用不带过滤参数的系统 du 独立核对总量。
mv "$filter_directory/node_modules" "$test_directory/excluded-node"
mv "$filter_directory/.git" "$test_directory/excluded-git"
mv "$filter_directory/keep/node_modules" "$test_directory/excluded-nested"
/usr/bin/du -h -d 0 "$filter_directory" > "$test_directory/expected" || fail '排除总量基线失败'
cmp -s "$test_directory/expected" "$test_directory/filtered-total" || fail '排除项仍被计入总量'
mv "$test_directory/excluded-node" "$filter_directory/node_modules"
mv "$test_directory/excluded-git" "$filter_directory/.git"
mv "$test_directory/excluded-nested" "$filter_directory/keep/node_modules"

# include 仅筛选第一层文件夹，所选目录内部保持原来的深度和统计口径。
compare_tree 包含第一层目录 --include small <<'TREE'
.
└── small
    └── deeper
TREE
compare_tree 包含通配模式 --include='sma*' <<'TREE'
.
└── small
    └── deeper
TREE
compare_tree 包含规则取并集 -i small --include='空格 path' <<'TREE'
.
├── small
│   └── deeper
└── 空格 path
TREE
compare_tree 包含后零深度 -i small -d 0 <<'TREE'
.
TREE
compare_tree 包含后条数截取 -i small -n 2 <<'TREE'
.
└── small
TREE
compare_tree 包含后深度相对根目录 -i small -d 3 <<'TREE'
.
└── small
    └── deeper
        └── deepest
TREE
compare_tree 包含尾斜杠 small/// --include deeper <<'TREE'
small///
└── deeper
    └── deepest
TREE
compare_tree 包含连字符目录 --include=-example <<'TREE'
.
└── -example
TREE
compare_tree 包含隐藏目录 "$filter_directory" -i .git <<TREE
$filter_directory
└── .git
    └── objects
TREE
compare_tree 只包含第一层同名目录 "$filter_directory" -i node_modules <<TREE
$filter_directory
└── node_modules
    └── cache
TREE
compare_tree 所选子树内继续排除 "$filter_directory" -i node_modules -e cache <<TREE
$filter_directory
└── node_modules
TREE
for include_pattern in deeper root-file missing-directory tree; do
  expect_status 0 不包含深层目录或根文件 dsize --include "$include_pattern"
  [[ ! -s "$test_directory/out" && ! -s "$test_directory/err" ]] || fail "include 误匹配：$include_pattern"
done
expect_status 0 排除覆盖包含 dsize "$filter_directory" -i node_modules -e node_modules
[[ ! -s "$test_directory/out" && ! -s "$test_directory/err" ]] || fail 'exclude 没有覆盖 include'
expect_status 0 包含时排除根目录 dsize "$filter_directory" -i node_modules -e filters
[[ ! -s "$test_directory/out" && ! -s "$test_directory/err" ]] || fail 'include 绕过了根目录排除规则'

# 重叠规则不重复选中；多个子树在同一 du 中测量，跨子树硬链接只计一次。
ln "$filter_directory/keep/data" "$filter_directory/node_modules/shared-data"
expected_total=$(/usr/bin/du -k -d 0 "$filter_directory/node_modules" "$filter_directory/keep" | awk '{ total += $1 } END { print total }')
expect_status 0 包含总量及硬链接去重 dsize "$filter_directory" --include=node_modules -i 'node*' -i keep --flat -d 0
actual_total=$(<"$test_directory/out")
actual_total=${actual_total%%$'\t'*}
actual_total=${actual_total// /}
[[ $actual_total == "${expected_total}K" ]] || fail "包含总量不符：$actual_total，期望 ${expected_total}K"
expect_status 0 包含平铺格式 dsize "$filter_directory" --include=node_modules --flat
[[ $(tail -n 1 "$test_directory/out") == *$'\t'"$filter_directory" ]] || fail '包含平铺汇总应在最后'
ln -s "$filter_directory/node_modules" ./directory-link
expect_status 0 不跟随第一层符号链接 dsize --include directory-link
[[ ! -s "$test_directory/out" && ! -s "$test_directory/err" ]] || fail 'include 跟随了符号链接'

# 固定未排序输入：交错的父子行必须归组，且不能按可读单位取整后排序。
original_path=$PATH
export DSIZE_TEST_DATA="$test_directory/du-data"
cat > "$test_directory/mock/du" <<'MOCK'
#!/bin/sh
cat "$DSIZE_TEST_DATA"
MOCK
chmod +x "$test_directory/mock/du"
printf '%s\n' $'134144\t./.next/cache' $'921600\t./node_modules/.pnpm' \
  $'926720\t./node_modules' $'476160\t./.next/dev' $'697344\t./.next' \
  $'1992294\t.' $'1024\t./.next/static' $'1024\t./docs' > "$DSIZE_TEST_DATA"
PATH="$test_directory/mock:$original_path" expect_status 0 树形大小与归组 dsize -n 6
cat > "$test_directory/expected" <<'TREE'
  1.9G  .
  905M  ├── node_modules
  900M  │   └── .pnpm
  681M  └── .next
  465M      ├── dev
  131M      └── cache
TREE
cmp -s "$test_directory/expected" "$test_directory/out" || fail "大小与归组不符；$(<"$test_directory/out")"
printf '%s\n' $'0\t./z/sub' $'0\t./z' $'0\t./a/sub' $'0\t./a' $'0\t.' > "$DSIZE_TEST_DATA"
PATH="$test_directory/mock:$original_path" compare_tree 同量保留祖先 -n 3 <<'TREE'
.
└── a
    └── sub
TREE
printf '%s\n' $'12308\t./a' $'12309\t./z' $'24617\t.' > "$DSIZE_TEST_DATA"
PATH="$test_directory/mock:$original_path" compare_tree 原始数值排序 -n 2 <<'TREE'
.
└── z
TREE
printf '%s\n' $'8\t/child' $'8\t/' > "$DSIZE_TEST_DATA"
PATH="$test_directory/mock:$original_path" compare_tree 文件系统根路径 -n 2 <<'TREE'
/
└── child
TREE
printf '%s\n' $'8\t./a' $'8\t.' $'4\t./ab' > "$DSIZE_TEST_DATA"
PATH="$test_directory/mock:$original_path" compare_tree 相近名称不误归组 <<'TREE'
.
├── a
└── ab
TREE
deep_path=.
printf '0\t.\n' > "$DSIZE_TEST_DATA"
for level in {1..1000}; do
  deep_path+=/x
  printf '0\t%s\n' "$deep_path" >> "$DSIZE_TEST_DATA"
done
PATH="$test_directory/mock:$original_path" expect_status 0 千层树形 dsize -d 1000 -n 1001
deep_output=( "${(@f)$(<"$test_directory/out")}" )
[[ ${#deep_output} == 1001 && $deep_output[-1] == *'└── x' ]] || fail '深层树形被截断或渲染失败'
[[ ! -s "$test_directory/err" ]] || fail '深层树形产生错误'
rm "$test_directory/mock/du"

# 后端契约覆盖 GNU（包括 macOS PATH 中的 GNU du）及 macOS BSD 参数。
# 仅此处模拟版本/平台；不以参数契约代替真实 GNU/Linux 扫描验证。
export DSIZE_TEST_DU_ARGUMENTS="$test_directory/du-arguments"
cat > "$test_directory/mock/du" <<'MOCK'
#!/bin/sh
if [ "$1" = --version ]; then
  case "$DSIZE_TEST_DU_BACKEND" in
    gnu) printf 'du (GNU coreutils) 9.0\n'; exit 0 ;;
    bsd) exit 1 ;;
  esac
fi
printf '%s\n' "$@" > "$DSIZE_TEST_DU_ARGUMENTS"
printf '4\t.\n'
MOCK
chmod +x "$test_directory/mock/du"
PATH="$test_directory/mock:$original_path" DSIZE_TEST_DU_BACKEND=gnu OSTYPE=darwin \
  expect_status 0 GNU排除参数 dsize -e node_modules --exclude='cache*' --exclude '空格 path' --exclude=-option
printf '%s\n' -k -d 2 --exclude=node_modules '--exclude=cache*' '--exclude=空格 path' --exclude=-option . > "$test_directory/expected"
cmp -s "$test_directory/expected" "$DSIZE_TEST_DU_ARGUMENTS" || fail 'GNU 排除参数发生拆词或转义'
PATH="$test_directory/mock:$original_path" DSIZE_TEST_DU_BACKEND=bsd OSTYPE=darwin \
  expect_status 0 BSD排除参数 dsize -e node_modules --exclude='cache*' --exclude '空格 path' --exclude=-option
printf '%s\n' -k -d 2 -I node_modules -I 'cache*' -I '空格 path' -I -option . > "$test_directory/expected"
cmp -s "$test_directory/expected" "$DSIZE_TEST_DU_ARGUMENTS" || fail 'BSD 排除参数发生拆词或转义'
PATH="$test_directory/mock:$original_path" DSIZE_TEST_DU_BACKEND=bsd OSTYPE=unknown \
  expect_status 1 不支持的排除后端 dsize --exclude node_modules
[[ $(<"$test_directory/err") == *'Exclusions require'* ]] || fail '不支持的后端缺少说明'
rm "$test_directory/mock/du"

expect_status 0 帮助 dsize --help
[[ $(<"$test_directory/out") == *'last repeated option wins'* ]] || fail '帮助缺少重复选项说明'
[[ $(<"$test_directory/out") == *'--flat'* && $(<"$test_directory/out") == *'tree'* ]] || fail '帮助缺少树形及兼容格式说明'
expect_status 0 短帮助 dsize -h

# Real scan data must remain byte-identical when only the display language changes.
expect_status 0 英文数据 dsize "$test_directory/tree" -d 0
cp "$test_directory/out" "$test_directory/english-data"
MST_LANG=zh-CN expect_status 0 中文数据 dsize "$test_directory/tree" -d 0
cmp -s "$test_directory/english-data" "$test_directory/out" || fail '语言改变了磁盘统计数据'
MST_LANG=zh-CN expect_status 2 中文错误 dsize --invalid
[[ $(<"$test_directory/err") == *'未知选项'* ]] || fail '工具错误未使用中文'

for option in -d --depth -n --lines; do
  expect_status 2 缺值 dsize "$option"
  for value in '' -1 abc 1.5 +1 １２; do
    expect_status 2 非整数 dsize "$option" "$value"
  done
done
expect_status 2 空等号深度 dsize --depth=
expect_status 2 空等号条数 dsize --lines=
for option in -e --exclude; do
  expect_status 2 排除缺值 dsize "$option"
  expect_status 2 空排除规则 dsize "$option" ''
done
expect_status 2 空等号排除 dsize --exclude=
expect_status 2 排除路径 dsize --exclude=small/deeper
expect_status 2 排除尾斜杠 dsize --exclude=small/
expect_status 2 排除绝对路径 dsize --exclude="$test_directory/tree/small"
for option in -i --include; do
  expect_status 2 包含缺值 dsize "$option"
  expect_status 2 空包含规则 dsize "$option" ''
done
expect_status 2 空等号包含 dsize --include=
expect_status 2 包含路径 dsize --include=small/deeper
expect_status 2 包含尾斜杠 dsize --include=small/
expect_status 2 无效包含模式 dsize --include='[bad'
expect_status 2 无效排除模式 dsize --exclude='[bad'
MST_LANG=zh-CN expect_status 2 中文排除错误 dsize --exclude=small/deeper
[[ $(<"$test_directory/err") == *'匹配名称而非路径'* ]] || fail '排除规则错误缺少中文'
expect_status 2 零条数 dsize -n 0000
expect_status 2 深度上界 dsize -d 1001
expect_status 2 条数上界 dsize -n 1000001
expect_status 2 巨大深度 dsize --depth=9999999999999999999999999999999999999999999
expect_status 2 巨大条数 dsize --lines=18446744073709551616
expect_status 2 未知选项 dsize --unknown
expect_status 2 不支持拼接 dsize -d2
expect_status 2 多个目录 dsize small '空格 path'
expect_status 2 分隔符多个目录 dsize -- small '空格 path'
expect_status 2 分隔符前后目录 dsize small -- '空格 path'
expect_status 2 不存在 dsize missing-directory
expect_status 2 普通文件 dsize root-file
expect_status 2 空目录参数 dsize ''

chmod 000 "$restricted_directory/hidden"
if [[ ! -r "$restricted_directory/hidden" ]]; then
  expect_status 1 真实权限限制 dsize "$restricted_directory"
  [[ -s "$test_directory/out" && $(<"$test_directory/err") == *'Incomplete scan'* ]] || fail '权限错误缺少部分结果或说明'
  expect_status 0 排除不可读目录 dsize "$restricted_directory" --exclude hidden
  [[ -s "$test_directory/out" && ! -s "$test_directory/err" ]] || fail '排除目录仍被扫描'
  expect_status 1 包含不可读目录 dsize "$restricted_directory" --include hidden
  expect_status 1 无法列出第一层 dsize "$restricted_directory/hidden" --include anything
  expect_status 0 未选中不可读子目录 dsize "$restricted_directory" --include missing
  [[ ! -s "$test_directory/out" && ! -s "$test_directory/err" ]] || fail 'include 扫描了未选中的子目录'
else
  print -ru2 -- 'SKIP: 当前身份可绕过目录权限；仍验证受控 du 失败。'
fi
chmod 700 "$restricted_directory/hidden"

# 每个失败阶段独立注入，检查部分结果以及流水线错误不会伪装成功。
cat > "$test_directory/mock/du" <<'MOCK'
#!/bin/sh
printf '4\t./small/partial-result\n4\t./small\n'
exit 1
MOCK
chmod +x "$test_directory/mock/du"
PATH="$test_directory/mock:$original_path" expect_status 1 du失败 dsize .
[[ $(<"$test_directory/out") == *partial-result* ]] || fail 'du 失败时丢失部分结果'
PATH="$test_directory/mock:$original_path" expect_status 1 包含扫描失败 dsize --include small
[[ $(<"$test_directory/out") == *partial-result* ]] || fail 'include 丢失部分结果'
rm "$test_directory/mock/du"
for stage_name in sort awk tail; do
  cat > "$test_directory/mock/$stage_name" <<'MOCK'
#!/bin/sh
/bin/cat >/dev/null
exit 1
MOCK
  chmod +x "$test_directory/mock/$stage_name"
  stage_arguments=()
  case $stage_name in tail) stage_arguments=(--flat) ;; esac
  PATH="$test_directory/mock:$original_path" expect_status 1 "$stage_name 失败" dsize "${stage_arguments[@]}" .
  [[ $(<"$test_directory/err") == *'Sorting, truncating, or formatting output failed'* ]] || fail "$stage_name 缺少阶段错误"
  rm "$test_directory/mock/$stage_name"
done
cat > "$test_directory/mock/awk" <<'MOCK'
#!/bin/sh
case "$*" in
  *show_children=*) /bin/cat >/dev/null; exit 1 ;;
  *) exec /usr/bin/awk "$@" ;;
esac
MOCK
chmod +x "$test_directory/mock/awk"
PATH="$test_directory/mock:$original_path" expect_status 1 包含汇总失败 dsize --include small
rm "$test_directory/mock/awk"
ln -s /usr/bin/du "$test_directory/mock/du"
ln -s /usr/bin/sort "$test_directory/mock/sort"
PATH="$test_directory/mock" expect_status 1 缺少awk dsize .
PATH="$test_directory/mock" expect_status 1 缺少tail dsize --flat .
rm "$test_directory/mock/du" "$test_directory/mock/sort"

# 即使各管道阶段返回 0，扫描期间接收到信号也必须报告失败。
cat > "$test_directory/mock/du" <<'MOCK'
#!/bin/sh
kill -TERM "$PPID"
printf '4\tinterrupted-result\n'
exit 0
MOCK
chmod +x "$test_directory/mock/du"
PATH="$test_directory/mock:$original_path" expect_status 1 中断 dsize .
[[ $(<"$test_directory/err") == *'Scan interrupted'* ]] || fail '中断诊断缺失'
[[ $PWD == $before_directory && $(setopt) == $before_options && $(trap) == $before_traps ]] || fail '调用改变 Shell 状态'

# 集中入口只执行注册文件，重新 source 会刷新定义；缺失工具安静跳过。
mkdir "$test_directory/isolated-tools"
cp "$project_directory/tools/init.zsh" "$test_directory/isolated-tools/"
cp -R "$project_directory/tools/dsize" "$test_directory/isolated-tools/"
cp "$project_directory/lib/i18n.sh" "$test_directory/isolated-tools/dsize/"
printf 'print -r -- unexpected\n' > "$test_directory/isolated-tools/unregistered.zsh"
source "$test_directory/isolated-tools/init.zsh" > "$test_directory/load-out"
[[ ! -s "$test_directory/load-out" ]] || fail '执行了未注册文件'
dsize() { return 42 }
source "$test_directory/isolated-tools/init.zsh"
expect_status 0 重载刷新 dsize --help
rm "$test_directory/isolated-tools/dsize/dsize.zsh"
unfunction dsize
source "$test_directory/isolated-tools/init.zsh" > "$test_directory/load-out" 2> "$test_directory/load-err"
[[ ! -s "$test_directory/load-out" && ! -s "$test_directory/load-err" && $+functions[dsize] == 0 ]] || fail '缺失工具未安静跳过'
print -r -- "PASS dsize: $checks 项行为检查及加载隔离。"
