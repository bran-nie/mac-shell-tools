#!/bin/zsh
# Real loopback TCP/UDP sockets plus deterministic lsof failure cases.
emulate -R zsh
setopt nounset pipefail
project_directory=$1
test_directory=$(mktemp -d "${TMPDIR:-/tmp}/mac-shell-tools-portwho-test.XXXXXX") || exit 1
listener_pid=''
checks=0
cleanup() {
  if [[ -n $listener_pid ]]; then
    kill "$listener_pid" 2>/dev/null
    wait "$listener_pid" 2>/dev/null
  fi
  rm -rf "$test_directory"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM
fail() { print -ru2 -- "FAIL portwho: $*"; exit 1; }
expect_status() {
  local expected=$1 label=$2 actual
  shift 2
  "$@" > "$test_directory/out" 2> "$test_directory/err"
  actual=$?
  [[ $actual == $expected ]] || fail "$label: expected $expected, got $actual; $(<"$test_directory/err")"
  if (( expected )); then [[ -s "$test_directory/err" ]] || fail "$label: missing diagnostic"; fi
  (( checks++ ))
  return 0
}
mkdir "$test_directory/mock"
before_directory=$PWD
before_options=$(setopt)
before_traps=$(trap)
source "$project_directory/tools/portwho/portwho.zsh" > "$test_directory/out" 2> "$test_directory/err"
[[ ! -s "$test_directory/out" && ! -s "$test_directory/err" ]] || fail 'noisy source'
expect_status 0 help portwho --help
expect_status 0 short-help portwho -h
expect_status 0 version portwho --version
[[ $(<"$test_directory/out") == 'portwho development (unbuilt; unknown)' ]] || fail 'source version'
expect_status 0 Chinese-help env MST_LANG=zh-CN zsh -f -c 'source "$1/tools/portwho/portwho.zsh"; portwho --help' -- "$project_directory"
[[ $(<"$test_directory/out") == *'用法：portwho'* ]] || fail 'Chinese help'
for value in '' 0 65536 1.5 +1 abc '80,443' '1-100' １２ 99999999999999999999999999999; do
  expect_status 2 invalid-port portwho "$value"
done
expect_status 2 negative-port portwho -- -1
expect_status 2 unknown-option portwho --invalid

# These sockets belong only to this test and never connect to a remote host.
python3 - "$test_directory/ports" <<'PY' > "$test_directory/listener-out" 2> "$test_directory/listener-err" &
import socket, sys, time
sockets = []
for kind in (socket.SOCK_STREAM, socket.SOCK_STREAM, socket.SOCK_DGRAM):
    connection = socket.socket(socket.AF_INET, kind)
    connection.bind(("127.0.0.1", 0))
    if kind == socket.SOCK_STREAM:
        connection.listen(1)
    sockets.append(connection)
with open(sys.argv[1], "w") as output:
    output.write(" ".join(str(connection.getsockname()[1]) for connection in sockets))
while True:
    time.sleep(1)
PY
listener_pid=$!
zmodload zsh/zselect
for attempt in {1..200}; do
  [[ -s "$test_directory/ports" ]] && break
  kill -0 "$listener_pid" 2>/dev/null || fail "listener could not start: $(<"$test_directory/listener-err")"
  zselect -t 5
done
[[ -s "$test_directory/ports" ]] || fail 'listener readiness timeout'
IFS=' ' read -r -A ports < "$test_directory/ports"
expect_status 0 one-port portwho "$ports[1]"
[[ $(<"$test_directory/out") == *"$listener_pid"* && $(<"$test_directory/out") == *":$ports[1] (LISTEN)"* ]] || fail 'real listener missing'
[[ $(<"$test_directory/out") != *":$ports[2] (LISTEN)"* && ! -s "$test_directory/err" ]] || fail 'query included other port'
expect_status 0 multiple-ports portwho "$ports[1]" "$ports[2]"
[[ $(<"$test_directory/out") == *":$ports[1] (LISTEN)"* && $(<"$test_directory/out") == *":$ports[2] (LISTEN)"* ]] || fail 'multiple selection'
expect_status 0 no-arguments portwho
[[ $(<"$test_directory/out") == *"$listener_pid"* && $(<"$test_directory/out") != *"UDP 127.0.0.1:$ports[3]"* ]] || fail 'all TCP selection'
expect_status 0 UDP-excluded portwho "$ports[3]"
[[ $(<"$test_directory/out") == *'No visible TCP listeners'* && $(<"$test_directory/out") == *'current permissions'* ]] || fail 'empty query claimed port free'

# The mock records exact argv; caller input can never become another lsof option.
cat > "$test_directory/mock/lsof" <<'MOCK'
#!/bin/sh
printf '%s\n' "$@" > "$MST_QUERY_LOG"
case $MST_QUERY_MODE in
  empty) exit 1 ;;
  warning) printf 'permission warning\n' >&2; exit 1 ;;
  partial) printf 'partial-result\n'; exit 1 ;;
  failure) exit 2 ;;
  interrupted) kill -TERM "$PPID"; exit 0 ;;
esac
MOCK
chmod +x "$test_directory/mock/lsof"
original_path=$PATH
export MST_QUERY_LOG="$test_directory/args" MST_QUERY_MODE=empty
PATH="$test_directory/mock:$original_path" expect_status 0 decimal-and-dedup portwho 00080 443 80 000443 --
[[ $(<"$test_directory/args") == $'-nP\n+c\n0\n-a\n-iTCP:80,443\n-sTCP:LISTEN' ]] || fail 'lsof argument contract'
for mode in warning partial failure interrupted; do
  MST_QUERY_MODE=$mode PATH="$test_directory/mock:$original_path" expect_status 1 "$mode" portwho 80
done
[[ $(<"$test_directory/err") == *'Query interrupted'* ]] || fail 'signal diagnostic'
MST_LANG=zh-CN PATH="$test_directory/mock:$original_path" expect_status 0 Chinese-empty portwho 80
[[ $(<"$test_directory/out") == *'结果受当前权限限制'* ]] || fail 'Chinese empty message'
PATH=/nonexistent expect_status 0 help-without-dependencies portwho --help
PATH=/nonexistent expect_status 1 missing-lsof portwho 80
[[ $PWD == $before_directory && $(setopt) == $before_options && $(trap) == $before_traps ]] || fail 'caller shell state changed'
[[ -z $(print -rl -- "$TMPDIR"/mst-portwho.*(N)) ]] || fail 'query temporary directory leaked'
print -r -- "PASS portwho: $checks input, real TCP/UDP, failure, language, and isolation checks."
