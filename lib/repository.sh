#!/bin/sh
# Plain-file tool repository: source snapshots, local bundles and online assets.

read_version_file() {
  check_file "$1"
  [ -f "$1" ] || fail error.metadata "$1"
  awk -v count="$2" 'END {exit NR != count}' "$1" || fail error.metadata "$1"
  bundle_version=$(sed -n '1p' "$1")
  bundle_revision=$(sed -n '2p' "$1")
  bundle_state=$(sed -n '3p' "$1")
  valid_version "$bundle_version" || fail error.metadata "$1"
  case $bundle_revision in
    unknown) ;;
    ''|*[!0-9a-f]*) fail error.metadata "$1" ;;
    *) [ "${#bundle_revision}" -ge 7 ] && [ "${#bundle_revision}" -le 64 ] || fail error.metadata "$1" ;;
  esac
  case $bundle_state in clean|modified|unknown) ;; *) fail error.metadata "$1" ;; esac
  if [ "$2" -eq 4 ]; then
    bundle_digest=$(sed -n '4p' "$1")
    case $bundle_digest in ''|*[!0-9a-f]*) fail error.metadata "$1" ;; esac
    [ "${#bundle_digest}" -eq 64 ] || fail error.metadata "$1"
  fi
}

source_install_mode() {
  check_directory "$1"
  check_file "$1/install.mode"
  if [ -f "$1/install.mode" ]; then
    awk 'NR != 1 || ($0 != "local" && $0 != "online") {bad=1} END {exit bad || NR != 1}' \
      "$1/install.mode" || fail error.catalog "$1/install.mode"
    cat "$1/install.mode"
  else
    printf '%s\n' local
  fi
}

valid_asset_path() {
  case $1 in ''|/*|.*|*/.*|*..*|*[!a-zA-Z0-9./-]*|files.list) return 1 ;; *) return 0 ;; esac
}

validate_tool_dependencies() {
  check_file "$1/dependencies.list"
  if [ -f "$1/dependencies.list" ]; then
    # A declaration contains command names only, never executable hooks or flags.
    awk '!/^[a-zA-Z0-9][a-zA-Z0-9_-]*$/ || seen[$0]++ {bad=1} END {exit bad || NR == 0}' \
      "$1/dependencies.list" || fail error.dependency_manifest "$1/dependencies.list"
  fi
}

check_selected_dependencies() {
  case $action in
    install|update) ;;
    setup|upgrade|uninstall|list) return 0 ;;
  esac
  for dependency_tool in $selected_files; do
    dependency_component=$(available_component "$dependency_tool")
    check_directory "$dependency_component"
    validate_tool_dependencies "$dependency_component"
    if [ -f "$dependency_component/dependencies.list" ]; then
      while IFS= read -r tool_dependency || [ -n "$tool_dependency" ]; do
        command -v "$tool_dependency" >/dev/null 2>&1 || \
          fail error.tool_dependency "${dependency_tool%.zsh}" "$tool_dependency"
      done < "$dependency_component/dependencies.list"
    fi
  done
}

validate_downloads() {
  check_file "$1"
  [ -f "$1" ] || fail error.download_manifest "$1"
  awk -F '\t' 'NF != 4 {bad=1} END {exit bad || NR == 0}' "$1" || fail error.download_manifest "$1"
  download_seen=' '
  while IFS="$(printf '\t')" read -r download_path download_url download_digest download_kind || [ -n "$download_path" ]; do
    valid_asset_path "$download_path" || fail error.download_manifest "$1"
    case $download_seen in *" $download_path "*) fail error.download_manifest "$1" ;; esac
    download_seen="$download_seen$download_path "
    case $download_url in https://?*) ;; *) fail error.download_manifest "$1" ;; esac
    case $download_url in *[[:space:]]*) fail error.download_manifest "$1" ;; esac
    case $download_digest in ''|*[!0-9a-f]*) fail error.download_manifest "$1" ;; esac
    [ "${#download_digest}" -eq 64 ] || fail error.download_manifest "$1"
    case $download_kind in file|executable) ;; *) fail error.download_manifest "$1" ;; esac
    # Remote resources supplement the bundle; they cannot replace its source,
    # language catalogs, ownership or provenance records.
    case $download_path in
      *.zsh|*.sh|VERSION|version|package.meta|install.mode|downloads.list|dependencies.list|*/files.list) fail error.download_manifest "$1" ;;
    esac
  done < "$1"
}

load_source_catalog() {
  # The builder validates staged metadata before publishing generated files.
  catalog_metadata_directory=${1:-$source_directory}
  check_file "$source_directory/scripts/tools.list"
  [ -f "$source_directory/scripts/tools.list" ] || fail error.catalog "$source_directory/scripts/tools.list"
  tool_files=
  tool_catalog=
  for catalog_file in $(cat "$source_directory/scripts/tools.list"); do
    case $catalog_file in init.zsh|mst.zsh) fail error.catalog "$catalog_file" ;; *.zsh) ;; *) fail error.catalog "$catalog_file" ;; esac
    valid_tool_name "${catalog_file%.zsh}" || fail error.catalog "$catalog_file"
    contains_file "$tool_files" "$catalog_file" && fail error.catalog "$catalog_file"
    catalog_component="$source_directory/tools/${catalog_file%.zsh}"
    catalog_mode=$(source_install_mode "$catalog_component")
    validate_tool_dependencies "$catalog_component"
    check_file "$catalog_component/$catalog_file"
    [ -f "$catalog_component/$catalog_file" ] || fail error.catalog "$catalog_file"
    read_version_file "$catalog_metadata_directory/tools/${catalog_file%.zsh}/package.meta" 4
    case $catalog_mode in
      local)
        check_file "$catalog_component/downloads.list"
        [ ! -f "$catalog_component/downloads.list" ] || fail error.download_manifest "$catalog_component/downloads.list" ;;
      online) validate_downloads "$catalog_component/downloads.list" ;;
    esac
    tool_files="$tool_files $catalog_file"
    tool_catalog="$tool_catalog$(printf '%s\t%s' "$catalog_file" "$catalog_mode")
"
  done
}

load_local_catalog() {
  check_file "$repository_directory/catalog.tsv"
  if [ ! -f "$repository_directory/catalog.tsv" ]; then
    case $action in
      uninstall) tool_files=; tool_catalog=; return 0 ;;
      *) fail error.repository ;;
    esac
  fi
  awk -F '\t' 'NF != 2 || ($2 != "local" && $2 != "online") || seen[$1]++ {bad=1} END {exit bad}' \
    "$repository_directory/catalog.tsv" || fail error.catalog "$repository_directory/catalog.tsv"
  tool_catalog=$(cat "$repository_directory/catalog.tsv")
  tool_files=
  while IFS="$(printf '\t')" read -r catalog_file catalog_mode || [ -n "$catalog_file" ]; do
    case $catalog_file in init.zsh|mst.zsh) fail error.catalog "$catalog_file" ;; *.zsh) ;; *) fail error.catalog "$catalog_file" ;; esac
    valid_tool_name "${catalog_file%.zsh}" || fail error.catalog "$catalog_file"
    tool_files="$tool_files $catalog_file"
  done < "$repository_directory/catalog.tsv"
}

install_mode_for() {
  printf '%s\n' "$tool_catalog" | awk -F '\t' -v name="$1" '$1 == name {print $2; exit}'
}

available_component() {
  case $invocation_mode in
    bootstrap) printf '%s/tools/%s\n' "$source_directory" "${1%.zsh}" ;;
    installed) printf '%s/tools/%s\n' "$repository_directory" "${1%.zsh}" ;;
  esac
}

prepare_source_payload() {
  mkdir -p "$stage/payload/manager/locales" "$stage/payload/repository/tools"
  cp "$source_directory/tools/init.zsh" "$stage/payload/init.zsh"
  cp "$source_directory/lib/manager.sh" "$stage/payload/manager/manager-core.sh"
  cp "$source_directory/lib/repository.sh" "$source_directory/lib/i18n.sh" "$source_directory/lib/mst.zsh" "$stage/payload/manager/"
  cp "$source_directory/locales/"*.sh "$stage/payload/manager/locales/"
  cp "$source_directory/LICENSE" "$stage/payload/manager/LICENSE"
  repository_payload="$stage/payload/repository"
  cp "$source_directory/tools/init.zsh" "$repository_payload/init.zsh"
  printf '%s\n%s\n%s\n' "$package_version" "$package_revision" "$package_state" > "$repository_payload/version"
  printf '%s' "$tool_catalog" > "$repository_payload/catalog.tsv"
  printf '%s\n' init.zsh > "$repository_payload/files.list"
  for payload_file in $tool_files; do
    payload_name=${payload_file%.zsh}
    payload_source="$source_directory/tools/$payload_name"
    payload_target="$repository_payload/tools/$payload_name"
    mkdir -p "$payload_target"
    read_version_file "$payload_source/package.meta" 4
    sed -e "s/@MST_VERSION@/$bundle_version/g" -e "s/@MST_REVISION@/$bundle_revision/g" \
      -e "s/@MST_STATE@/$bundle_state/g" "$payload_source/$payload_file" > "$payload_target/$payload_file"
    printf '%s\n%s\n%s\n' "$bundle_version" "$bundle_revision" "$bundle_state" > "$payload_target/version"
    cp "$source_directory/LICENSE" "$payload_target/LICENSE"
    printf '%s\n' "$payload_file" version LICENSE > "$payload_target/files.list"
    if [ -f "$payload_source/dependencies.list" ]; then
      cp "$payload_source/dependencies.list" "$payload_target/dependencies.list"
      printf '%s\n' dependencies.list >> "$payload_target/files.list"
    fi
    if [ -d "$payload_source/locales" ]; then
      check_directory "$payload_source/locales"
      mkdir "$payload_target/locales"
      cp "$source_directory/lib/i18n.sh" "$payload_target/i18n.sh"
      printf '%s\n' i18n.sh >> "$payload_target/files.list"
      for payload_language in en zh-CN; do
        check_file "$payload_source/locales/$payload_language.sh"
        if [ -f "$payload_source/locales/$payload_language.sh" ]; then
          cp "$payload_source/locales/$payload_language.sh" "$payload_target/locales/$payload_language.sh"
          printf 'locales/%s.sh\n' "$payload_language" >> "$payload_target/files.list"
        fi
      done
    fi
    case $(install_mode_for "$payload_file") in
      local) ;;
      online)
        cp "$payload_source/downloads.list" "$payload_target/downloads.list"
        printf '%s\n' downloads.list >> "$payload_target/files.list" ;;
    esac
    while IFS= read -r payload_asset; do printf 'tools/%s/%s\n' "$payload_name" "$payload_asset"; done < "$payload_target/files.list" >> "$repository_payload/files.list"
    printf 'tools/%s/files.list\n' "$payload_name" >> "$repository_payload/files.list"
  done
  # Publish the catalog after all of its component files have been copied.
  printf '%s\n' version catalog.tsv >> "$repository_payload/files.list"
}

write_payload() {
  mkdir -p "$stage/payload/tools"
  case $invocation_mode in
    bootstrap) prepare_source_payload; bundle_repository="$stage/payload/repository" ;;
    installed)
      bundle_repository=$repository_directory
      # Installed-tool ownership and uninstallation do not depend on the cache.
      printf '%s\n%s\n' "$init_begin" "$init_end" > "$stage/payload/init.zsh"
      if [ "$write_manager_runtime" = yes ]; then
        mkdir -p "$stage/payload/manager/locales"
        for payload_asset in manager-core.sh mst.zsh i18n.sh repository.sh LICENSE locales/en.sh locales/zh-CN.sh; do
          cp "$manager_directory/$payload_asset" "$stage/payload/manager/$payload_asset"
        done
      fi ;;
  esac
  case $action in
    install|update) ;;
    setup|upgrade|uninstall) return 0 ;;
  esac
  for payload_file in $selected_files; do
    cached_component="$bundle_repository/tools/${payload_file%.zsh}"
    check_directory "$cached_component"
    validate_assets "$cached_component/files.list"
    payload_component="$stage/payload/tools/${payload_file%.zsh}"
    mkdir -p "$payload_component"
    while IFS= read -r payload_asset; do
      bundle_tail=$payload_asset
      bundle_cursor=$cached_component
      while :; do
        case $bundle_tail in
          */*)
            bundle_cursor="$bundle_cursor/${bundle_tail%%/*}"
            check_directory "$bundle_cursor"
            bundle_tail=${bundle_tail#*/} ;;
          *) break ;;
        esac
      done
      check_file "$cached_component/$payload_asset"
      [ -f "$cached_component/$payload_asset" ] || fail error.assets "$cached_component/files.list"
      case $payload_asset in */*) mkdir -p "$payload_component/${payload_asset%/*}" ;; esac
      cp -p "$cached_component/$payload_asset" "$payload_component/$payload_asset"
    done < "$cached_component/files.list"
    cp "$cached_component/files.list" "$payload_component/files.list"
    case $(install_mode_for "$payload_file") in
      local) ;;
      online) download_tool_assets "$payload_component" ;;
      *) fail error.catalog "$payload_file" ;;
    esac
  done
}

download_tool_assets() {
  online_component=$1
  command -v curl >/dev/null 2>&1 || fail error.dependency curl
  if command -v sha256sum >/dev/null 2>&1; then
    tool_sha256() { sha256sum "$1" | awk '{print $1}'; }
  elif command -v shasum >/dev/null 2>&1; then
    tool_sha256() { shasum -a 256 "$1" | awk '{print $1}'; }
  else
    fail error.dependency 'sha256sum or shasum'
  fi
  validate_downloads "$online_component/downloads.list"
  while IFS="$(printf '\t')" read -r download_path download_url download_digest download_kind || [ -n "$download_path" ]; do
    [ ! -e "$online_component/$download_path" ] || fail error.download_manifest "$online_component/downloads.list"
    case $download_path in */*) mkdir -p "$online_component/${download_path%/*}" ;; esac
    message info.fetch "$download_url"
    curl -fsSL --proto '=https' --proto-redir '=https' --connect-timeout 10 --max-time 60 \
      -o "$online_component/$download_path" "$download_url" || fail error.download
    [ "$(tool_sha256 "$online_component/$download_path")" = "$download_digest" ] || fail error.checksum "$download_path"
    case $download_kind in
      file) chmod 644 "$online_component/$download_path" ;;
      executable) chmod 755 "$online_component/$download_path" ;;
    esac
    printf '%s\n' "$download_path" >> "$online_component/files.list"
  done < "$online_component/downloads.list"
}
