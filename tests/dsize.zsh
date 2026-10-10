#!/bin/zsh
# 对比真实 BSD 管道，并覆盖输入、权限、阶段失败及 Shell 隔离。
# 命令替身只用于稳定重现失败，不替代正常统计的平台验证。
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

# 期望值直接来自 macOS 系统命令，验证格式、排序、行数和默认值。
compare_reference() {
  local label=$1 expected_depth=$2 expected_lines=$3 expected_directory=$4
  shift 4
  /usr/bin/du -h -d "$expected_depth" "$expected_directory" 2>/dev/null |
    /usr/bin/sort -h | /usr/bin/tail -n "$expected_lines" > "$test_directory/expected" || fail "$label: 基线失败"
  expect_status 0 "$label" dsize "$@"
  cmp -s "$test_directory/expected" "$test_directory/out" || fail "$label: 输出与 BSD 管道不同"
  [[ ! -s "$test_directory/err" ]] || fail "$label: 成功时出现错误输出"
}

mkdir -p "$test_directory/tree/small/deeper/deepest" "$test_directory/tree/空格 path" \
  "$test_directory/tree/-example" "$test_directory/mock" "$restricted_directory/hidden"
dd if=/dev/zero of="$test_directory/tree/root-file" bs=1024 count=64 2>/dev/null
dd if=/dev/zero of="$test_directory/tree/small/deeper/deepest/file" bs=1024 count=8 2>/dev/null
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
expect_status 0 帮助 dsize --help
[[ $(<"$test_directory/out") == *'last repeated option wins'* ]] || fail '帮助缺少重复选项说明'
expect_status 0 短帮助 dsize -h

for option in -d --depth -n --lines; do
  expect_status 2 缺值 dsize "$option"
  for value in '' -1 abc 1.5 +1 １２; do
    expect_status 2 非整数 dsize "$option" "$value"
  done
done
expect_status 2 空等号深度 dsize --depth=
expect_status 2 空等号条数 dsize --lines=
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
else
  print -ru2 -- 'SKIP: 当前身份可绕过目录权限；仍验证受控 du 失败。'
fi
chmod 700 "$restricted_directory/hidden"

# 每个失败阶段独立注入，检查部分结果以及流水线错误不会伪装成功。
cat > "$test_directory/mock/du" <<'MOCK'
#!/bin/sh
printf '4K\tpartial-result\n'
exit 1
MOCK
chmod +x "$test_directory/mock/du"
original_path=$PATH
PATH="$test_directory/mock:$original_path" expect_status 1 du失败 dsize .
[[ $(<"$test_directory/out") == *partial-result* ]] || fail 'du 失败时丢失部分结果'
rm "$test_directory/mock/du"
for stage_name in sort tail; do
  cat > "$test_directory/mock/$stage_name" <<'MOCK'
#!/bin/sh
/bin/cat >/dev/null
exit 1
MOCK
  chmod +x "$test_directory/mock/$stage_name"
  PATH="$test_directory/mock:$original_path" expect_status 1 "$stage_name 失败" dsize .
  [[ $(<"$test_directory/err") == *'Sorting or truncating output failed'* ]] || fail "$stage_name 缺少阶段错误"
  rm "$test_directory/mock/$stage_name"
done
ln -s /usr/bin/du "$test_directory/mock/du"
ln -s /usr/bin/sort "$test_directory/mock/sort"
PATH="$test_directory/mock" expect_status 1 缺少tail dsize .
rm "$test_directory/mock/du" "$test_directory/mock/sort"

# 即使各管道阶段返回 0，扫描期间接收到信号也必须报告失败。
cat > "$test_directory/mock/du" <<'MOCK'
#!/bin/sh
kill -TERM "$PPID"
printf '4K\tinterrupted-result\n'
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
