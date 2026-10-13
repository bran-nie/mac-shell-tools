#!/bin/sh
# Platform gates and shell boundaries; native suites verify actual BSD/GNU behavior.
set -eu
project_dir=$1
test_directory=$(mktemp -d "${TMPDIR:-/tmp}/mac-shell-tools-platform-test.XXXXXX")
trap 'rm -rf "$test_directory"' 0
trap 'exit 1' HUP INT TERM
checks=0
mkdir -p "$test_directory/mock" "$test_directory/tmp"

fail() {
  printf 'FAIL platform: %s\n' "$*" >&2
  cat "$test_directory/err" >&2
  exit 1
}

cat > "$test_directory/mock/uname" <<'MOCK'
#!/bin/sh
printf '%s\n' "$MST_TEST_PLATFORM"
MOCK
chmod +x "$test_directory/mock/uname"

for platform in Darwin Linux FreeBSD MINGW64_NT; do
  test_home="$test_directory/$platform/home"
  mkdir -p "$test_home"
  if env HOME="$test_home" XDG_CONFIG_HOME= ZDOTDIR= MST_LANG= RUNZSH=no \
      TMPDIR="$test_directory/tmp" PATH="$test_directory/mock:$PATH" MST_TEST_PLATFORM="$platform" \
      /bin/sh "$project_dir/install.sh" install sample \
      > "$test_directory/out" 2> "$test_directory/err"; then actual=0; else actual=$?; fi
  case $platform in
    Darwin|Linux)
      [ "$actual" -eq 0 ] || fail "$platform rejected"
      env HOME="$test_home" ZDOTDIR= MST_LANG= /bin/zsh -f -c '
        source "$HOME/.zshrc"
        (( $+functions[mst] && $+functions[sample] )) || exit 1
        sample --help >/dev/null
      ' || fail "$platform installation unusable"
      ;;
    FreeBSD|MINGW64_NT)
      [ "$actual" -eq 1 ] || fail "$platform accepted"
      grep -Fq 'macOS and Linux' "$test_directory/err" || fail 'platform diagnostic missing'
      [ ! -e "$test_home/.config" ] && [ ! -e "$test_home/.zshrc" ] || fail 'unsupported system wrote configuration'
      ;;
  esac
  checks=$((checks + 1))
done

# The POSIX bootstrap may be launched from Bash. SHELL is a login preference,
# not proof of the interpreter running the installer or loading the config.
test_home="$test_directory/bash/home"
mkdir -p "$test_home"
env HOME="$test_home" XDG_CONFIG_HOME= ZDOTDIR= MST_LANG= RUNZSH=no SHELL=/bin/bash \
  TMPDIR="$test_directory/tmp" /bin/bash "$project_dir/install.sh" install sample \
  > "$test_directory/out" 2> "$test_directory/err" || fail 'bootstrap launched from Bash failed'
env HOME="$test_home" /bin/bash --noprofile --norc -c '
  source "$HOME/.zshrc"
  if declare -F mst >/dev/null || declare -F sample >/dev/null; then exit 1; fi
  source "$1/tools/init.zsh"
' -- "$project_dir" > "$test_directory/out" 2> "$test_directory/err" || fail 'Zsh loader ran in Bash'
[ ! -s "$test_directory/out" ] && [ ! -s "$test_directory/err" ] || fail 'Bash load produced output'
checks=$((checks + 1))

# Non-interactive uses load functions without initializing the completion system.
env HOME="$test_home" ZDOTDIR= MST_LANG= /bin/zsh -f -c '
  source "$HOME/.zshrc"
  (( $+functions[mst] && $+functions[sample] && ! $+functions[compdef] )) || exit 1
  sample --help >/dev/null
' > "$test_directory/out" 2> "$test_directory/err" || fail 'non-interactive load changed completion'
[ ! -e "$test_home/.zcompdump" ] || fail 'non-interactive load created completion cache'
checks=$((checks + 1))

# Missing Zsh must fail before installing manager files or changing .zshrc.
mkdir "$test_directory/no-zsh"
for dependency in uname mkdir mktemp cat awk cmp cp mv date rm rmdir; do
  ln -s "$(command -v "$dependency")" "$test_directory/no-zsh/$dependency"
done
test_home="$test_directory/no-zsh-home"
mkdir "$test_home"
if env HOME="$test_home" XDG_CONFIG_HOME= ZDOTDIR= MST_LANG= RUNZSH=no \
    TMPDIR="$test_directory/tmp" PATH="$test_directory/no-zsh" /bin/sh "$project_dir/install.sh" \
    > "$test_directory/out" 2> "$test_directory/err"; then fail 'missing Zsh accepted'; fi
grep -Fq 'Required command is missing: zsh' "$test_directory/err" || fail 'missing Zsh diagnostic missing'
[ ! -e "$test_home/.config" ] && [ ! -e "$test_home/.zshrc" ] || fail 'missing Zsh changed configuration'
checks=$((checks + 1))

printf 'PASS platform: %s platform and shell checks.\n' "$checks"
