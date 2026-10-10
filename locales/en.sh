# mst_text_en message catalog.
mst_text_en() {
  case $1 in
    error.help) printf '%s\n' 'Run mst --help for usage.' ;;
    error.interrupted) printf '%s\n' 'Operation interrupted. Existing backups can be used for recovery.' ;;
    error.runzsh) printf '%s\n' 'RUNZSH must be yes or no.' ;;
    error.option) printf '%s\n' 'Unknown option: %s' ;;
    error.command) printf '%s\n' 'Unknown command: %s' ;;
    error.name) printf '%s\n' 'Invalid tool name: %s' ;;
    error.all_names) printf '%s\n' '--all cannot be combined with tool names.' ;;
    error.no_names) printf '%s\n' '%s does not accept tool names or --all.' ;;
    error.uninstall_names) printf '%s\n' 'Specify tools to uninstall, or use uninstall --all.' ;;
    error.language) printf '%s\n' 'Unsupported language: %s (use en or zh-CN).' ;;
    error.language_value) printf '%s\n' '--lang requires en or zh-CN.' ;;
    error.config) printf '%s\n' 'Usage: mst config language [en|zh-CN]' ;;
    error.absolute) printf '%s\n' '%s must be an absolute path: %s' ;;
    error.symlink) printf '%s\n' 'Symbolic link preserved; refusing to manage: %s' ;;
    error.file_type) printf '%s\n' 'Target is not a regular file: %s' ;;
    error.directory_type) printf '%s\n' 'Target is not a directory: %s' ;;
    error.markers) printf '%s\n' 'Managed markers are broken or duplicated: %s' ;;
    error.unknown_entry) printf '%s\n' 'Existing entry has no recognized managed block: %s' ;;
    error.state) printf '%s\n' 'Invalid or duplicate installed-tool record: %s' ;;
    error.metadata) printf '%s\n' 'Invalid or missing version metadata: %s' ;;
    error.catalog) printf '%s\n' 'Invalid tool catalog: %s' ;;
    error.repository) printf '%s\n' 'Local tool repository is missing; run mst upgrade to synchronize it.' ;;
    error.download_manifest) printf '%s\n' 'Invalid online resource manifest: %s' ;;
    error.checksum) printf '%s\n' 'Downloaded resource checksum mismatch: %s' ;;
    error.assets) printf '%s\n' 'Invalid owned-file manifest: %s' ;;
    error.available) printf '%s\n' 'Tool is unavailable in this package: %s' ;;
    error.not_installed) printf '%s\n' 'Tool is not installed: %s' ;;
    error.unknown_tool) printf '%s\n' 'Unknown tool: %s' ;;
    error.escape) printf '%s\n' 'Cannot quote configuration path: %s' ;;
    error.syntax) printf '%s\n' 'Shell syntax check failed: %s' ;;
    error.dependency) printf '%s\n' 'Required command is missing: %s' ;;
    error.platform) printf '%s\n' 'Supported systems: macOS and Linux.' ;;
    error.mkdir) printf '%s\n' 'Cannot create directory: %s' ;;
    error.enter) printf '%s\n' 'Cannot enter directory: %s' ;;
    error.lock) printf '%s\n' 'Cannot acquire the installation lock; check for another operation before removing it: %s' ;;
    error.stage) printf '%s\n' 'Cannot create a temporary directory.' ;;
    error.payload) printf '%s\n' 'Cannot prepare the tool repository.' ;;
    error.readonly) printf '%s\n' 'File is not writable: %s' ;;
    error.parent) printf '%s\n' 'Directory is not writable or accessible: %s' ;;
    error.backup) printf '%s\n' 'Cannot create a complete backup: %s' ;;
    error.write) printf '%s\n' 'Cannot write or replace file (check permissions and free space): %s' ;;
    error.remove) printf '%s\n' 'Cannot remove file: %s' ;;
    error.download) printf '%s\n' 'Download failed; existing managed files are unchanged.' ;;
    error.empty) printf '%s\n' 'Downloaded package is empty; existing files are unchanged.' ;;
    error.download_syntax) printf '%s\n' 'Downloaded package has invalid shell syntax; existing files are unchanged.' ;;
    error.package) printf '%s\n' 'Downloaded content is not a supported mac-shell-tools package; existing files are unchanged.' ;;
    error.read_release) printf '%s\n' 'Cannot read the downloaded package.' ;;
    error.migration_conflict) printf '%s\n' 'New installation already exists with conflicting legacy state; preserved both locations: %s' ;;
    error.migration_source) printf '%s\n' 'Legacy installation is missing a registered tool: %s' ;;
    info.fetch) printf '%s\n' 'Fetching: %s' ;;
    info.backup) printf '%s\n' 'Backed up: %s' ;;
    info.write) printf '%s\n' 'Written: %s' ;;
    info.remove) printf '%s\n' 'Uninstalled: %s' ;;
    info.unchanged) printf '%s\n' 'No files need changing.' ;;
    info.complete) printf '%s\n' 'Operation complete.' ;;
    info.login) printf '%s\n' 'Starting a new login Zsh in this terminal; exiting may return to the previous session.' ;;
    info.activate) printf '%s\n' 'Start Zsh with zsh -l, or run this in your current Zsh:' ;;
    info.uninstall_activate) printf '%s\n' 'Start a fresh Zsh with exec zsh -l; loaded functions remain in existing sessions.' ;;
    info.empty) printf '%s\n' 'No tools are installed; nothing to update.' ;;
    info.no_tools) printf '%s\n' 'No tools to process. Run mst list to see their status.' ;;
    info.language) printf '%s\n' 'Language: %s' ;;
    info.migrate) printf '%s\n' 'Migrating the registered installation from %s' ;;
    info.migrated) printf '%s\n' 'Migration complete. Personal files and existing backups remain in %s' ;;
    status.not_installed) printf '%s\n' 'not installed' ;;
    status.installed) printf '%s\n' 'installed' ;;
    status.missing) printf '%s\n' 'installed (file missing)' ;;
    status.unavailable) printf '%s\n' 'unavailable in catalog' ;;
    list.header) printf '%s\n' 'TOOL                 STATUS                       INSTALLED VERSION             AVAILABLE VERSION' ;;
    help) printf '%s\n' 'Usage: mst <command> [tool ...] [options]
       sh install.sh [command] [tool ...] [options]

Commands:
  install [tool ...]       Install from the local repository; no names means all.
  update [tool ...]        Synchronize, then update installed tools only.
  uninstall tool ...      Uninstall selected tools, with backups.
  uninstall --all         Uninstall all tools; keep mst.
  list                    Show the local catalog, status, and versions.
  upgrade                 Upgrade mst and sync scripts; keep installed tools unchanged.
  version                 Show mst'\''s installed version and source revision.
  config language         Show the saved language (default: en).
  config language en      Save English for mst and tools.
  config language zh-CN   Save Simplified Chinese for mst and tools.

Options:
  --all                   Select all; cannot be combined with tool names.
  --lang en|zh-CN         Use this language for this command only.
  --no-run-zsh            Do not start a new Zsh session.
  --unattended            Non-interactive operation; do not start Zsh.
  -V, --version           Show mst'\''s version.
  -h, --help              Show this help.

Running install.sh without a command installs mst only.
mst upgrade/update synchronize the latest GitHub source snapshot.
Ordinary mst install is offline; online tools download declared resources.
RUNZSH=no also disables the new login session.
Language changes take effect on the next invocation, without a new session.' ;;
    *) return 1 ;;
  esac
}
