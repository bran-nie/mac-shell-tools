#!/bin/sh
set -eu
test_directory=$(mktemp -d "${TMPDIR:-/tmp}/mst-locales.XXXXXX")
trap 'rm -rf "$test_directory"' 0
checks=0
fail() { printf 'FAIL locales: %s (%s)\n' "$*" "$catalog_directory" >&2; exit 1; }
# Complete catalogs share keys and printf arguments; fallback is tested above.
for catalog_directory do
  for catalog_language in en zh-CN; do
    awk '/^[[:space:]]+[a-z][a-z_.]*\)/ {key=$1; sub(/\)$/, "", key); print key}' \
      "$catalog_directory/$catalog_language.sh" > "$test_directory/keys-$catalog_language"
  done
  cmp -s "$test_directory/keys-en" "$test_directory/keys-zh-CN" || fail 'catalog keys differ'
  while IFS= read -r key; do
    english_format=$(/bin/sh -c '. "$1/en.sh"; mst_text_en "$2"' -- "$catalog_directory" "$key")
    chinese_format=$(/bin/sh -c '. "$1/zh-CN.sh"; mst_text_zh_CN "$2"' -- "$catalog_directory" "$key")
    english_arguments=$(printf '%s\n' "$english_format" | sed 's/[^%]//g')
    chinese_arguments=$(printf '%s\n' "$chinese_format" | sed 's/[^%]//g')
    [ "$english_arguments" = "$chinese_arguments" ] || fail "catalog arguments differ: $key"
  done < "$test_directory/keys-en"
  checks=$((checks + 1))
done
printf 'PASS locales: %s catalogs.\n' "$checks"
