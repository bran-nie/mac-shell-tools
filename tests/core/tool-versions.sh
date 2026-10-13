#!/bin/sh
# Component releases stay independent across catalog and manager upgrades.
set -eu
project_dir=$1
. "$project_dir/tests/common.sh"
test_directory=$(mktemp -d "${TMPDIR:-/tmp}/mac-shell-tools-tool-versions.XXXXXX")
trap 'rm -rf "$test_directory"' 0
trap 'exit 1' HUP INT TERM
fixture="$test_directory/release"
test_home="$test_directory/home"
install_directory="$test_home/.config/zsh/mac-shell-tools"
checks=0
mkdir -p "$test_home" "$test_directory/baseline"
copy_package "$project_dir" "$fixture"
: > "$test_directory/out"
: > "$test_directory/err"
fail() {
  printf 'FAIL tool versions: %s\n' "$*" >&2
  cat "$test_directory/out" "$test_directory/err" >&2
  exit 1
}
build() { sh "$fixture/scripts/build-installer.sh" "$@" > "$test_directory/build"; }
same() {
  cmp -s "$1" "$2" || fail "$3"
  checks=$((checks + 1))
}
changed() {
  [ "$(sed -n '1p' "$1")" != "$(sed -n '1p' "$2")" ] || fail "$3"
  checks=$((checks + 1))
}
run_source() {
  expected=$1; shift
  if env HOME="$test_home" XDG_CONFIG_HOME= ZDOTDIR= MST_LANG=en RUNZSH=no \
      sh "$fixture/install.sh" "$@" > "$test_directory/out" 2> "$test_directory/err"; then actual=0; else actual=$?; fi
  [ "$actual" -eq "$expected" ] || fail "$*: expected $expected, got $actual"
  checks=$((checks + 1))
}
list_installed() {
  env HOME="$test_home" XDG_CONFIG_HOME= ZDOTDIR= MST_LANG=en RUNZSH=no \
    zsh -f -c 'source "$HOME/.zshrc"; mst list' > "$test_directory/out" 2> "$test_directory/err" || fail 'installed list'
  checks=$((checks + 1))
}
assert_list_version() {
  awk -v tool="$1" -v installed="$2" -v available="$3" \
    '$1 == tool && $2 == "installed" && $3 == installed && $4 == available {found=1} END {exit !found}' \
    "$test_directory/out" || fail "incorrect versions for $1"
  checks=$((checks + 1))
}

# Reproduce adding dependent to a release with sample/second already installed.
printf '%s\n' sample.zsh second.zsh third.zsh > "$fixture/scripts/tools.list"
build
for tool in sample second third; do cp "$fixture/tools/$tool/package.meta" "$test_directory/baseline/$tool"; done
sample_version=$(sed -n '1p' "$test_directory/baseline/sample")
second_version=$(sed -n '1p' "$test_directory/baseline/second")
run_source 0 install sample second
cp -R "$install_directory/tools" "$test_directory/installed-before"
printf '%s\n' dependent.zsh >> "$fixture/scripts/tools.list"
printf '0.8.0-dev\n' > "$fixture/VERSION"
printf '\n# manager-only change\n' >> "$fixture/lib/mst.zsh"
printf '\n# manager-only translation\n' >> "$fixture/locales/en.sh"
build
for tool in sample second third; do
  same "$test_directory/baseline/$tool" "$fixture/tools/$tool/package.meta" 'new tool/manager changed an existing tool version'
done
run_source 0 upgrade
diff -r "$test_directory/installed-before" "$install_directory/tools" > "$test_directory/diff" || fail 'upgrade rewrote installed tools'
list_installed
assert_list_version sample "$sample_version" "$sample_version"
assert_list_version second "$second_version" "$second_version"
run_source 0 list
assert_list_version sample "$sample_version" "$sample_version"

# Each shipped tool input participates; unrelated tools keep their metadata.
for asset in dependent.zsh locales/en.sh dependencies.list; do
  cp "$fixture/tools/dependent/package.meta" "$test_directory/before-dependent"
  case $asset in
    dependencies.list) printf 'another-runtime\n' >> "$fixture/tools/dependent/$asset" ;;
    *) printf '\n# tool change\n' >> "$fixture/tools/dependent/$asset" ;;
  esac
  build
  changed "$test_directory/before-dependent" "$fixture/tools/dependent/package.meta" "$asset did not change dependent version"
  same "$test_directory/baseline/sample" "$fixture/tools/sample/package.meta" 'dependent edit changed sample'
done
printf '\n# sample change\n' >> "$fixture/tools/sample/sample.zsh"
build
new_sample_version=$(sed -n '1p' "$fixture/tools/sample/package.meta")
changed "$test_directory/baseline/sample" "$fixture/tools/sample/package.meta" 'sample source did not change its version'
same "$test_directory/baseline/second" "$fixture/tools/second/package.meta" 'sample edit changed second'
run_source 0 upgrade
list_installed
assert_list_version sample "$sample_version" "$new_sample_version"
assert_list_version second "$second_version" "$second_version"

# Preserve old package-wide records honestly until that tool is updated.
legacy_version=0.1.0-dev+1505faa1813c
awk -F '\t' -v OFS='\t' -v version="$legacy_version" '$1 == "sample.zsh" {$2=version} {print}' \
  "$install_directory/tools/installed.list" > "$test_directory/legacy-state"
cp "$test_directory/legacy-state" "$install_directory/tools/installed.list"
run_source 0 upgrade
same "$test_directory/legacy-state" "$install_directory/tools/installed.list" 'upgrade rewrote a legacy installed version'
list_installed
assert_list_version sample "$legacy_version" "$new_sample_version"
run_source 0 update sample
list_installed
assert_list_version sample "$new_sample_version" "$new_sample_version"
env HOME="$test_home" XDG_CONFIG_HOME= ZDOTDIR= MST_LANG=en zsh -f -c \
  'source "$HOME/.zshrc"; sample --version' > "$test_directory/out"
grep -Fq "sample $new_sample_version (" "$test_directory/out" || fail 'loaded version differs from list'

# Shared runtime updates affect every tool that ships that runtime.
for tool in sample second third dependent; do cp "$fixture/tools/$tool/package.meta" "$test_directory/baseline/$tool"; done
printf '\n# shared language runtime change\n' >> "$fixture/lib/i18n.sh"
build
for tool in sample second third dependent; do
  changed "$test_directory/baseline/$tool" "$fixture/tools/$tool/package.meta" 'shared runtime did not change dependent tool version'
done

# A clean unchanged component also retains provenance on later publications.
git -C "$fixture" init -q
git -C "$fixture" add .
git -C "$fixture" -c user.name=MST-Test -c user.email=mst@example.invalid -c commit.gpgsign=false \
  -c core.hooksPath=/dev/null commit -qm 'Component sources'
build --refresh-revision
cp "$fixture/tools/second/package.meta" "$test_directory/clean-second"
grep -Fxq clean "$test_directory/clean-second" || fail 'component source not marked clean'
printf '\n# later manager release\n' >> "$fixture/lib/mst.zsh"
build --refresh-revision
same "$test_directory/clean-second" "$fixture/tools/second/package.meta" 'manager publication rewrote clean tool provenance'
build --check

# Generated metadata is required and parsed as data before installation writes.
cp "$fixture/tools/second/package.meta" "$test_directory/valid-metadata"
for invalid in missing malformed linked; do
  case $invalid in
    missing) rm "$fixture/tools/second/package.meta" ;;
    malformed) printf 'touch %s/executed\n' "$test_home" > "$fixture/tools/second/package.meta" ;;
    linked)
      rm "$fixture/tools/second/package.meta"
      ln -s "$test_directory/valid-metadata" "$fixture/tools/second/package.meta" ;;
  esac
  run_source 1 install second
  [ ! -e "$test_home/executed" ] || fail 'metadata executed'
  rm -f "$fixture/tools/second/package.meta"
  cp "$test_directory/valid-metadata" "$fixture/tools/second/package.meta"
done
printf 'broken\n' > "$fixture/tools/second/package.meta"
if build --check > "$test_directory/out" 2> "$test_directory/err"; then fail 'stale component metadata accepted'; fi
cp "$test_directory/valid-metadata" "$fixture/tools/second/package.meta"
printf 'PASS tool versions: %s independent release, upgrade, legacy and metadata checks.\n' "$checks"
