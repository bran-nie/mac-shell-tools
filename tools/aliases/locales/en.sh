# mst_text_en message catalog.
mst_text_en() {
  case $1 in
    help) printf '%s\n' 'Usage: aliases [command]

Load common aliases and an optional personal Zsh file into the current shell.
Builtins: ll="ls -alh", duls="du -h -d 1 -c".

  list                 List tracked aliases/functions, sources and live state
  show NAME            Show the current definition of a tracked name
  reload               Reload into this shell; remove stale owned definitions
  config file          Show the saved personal file path (empty by default)
  config file PATH     Save a readable Zsh file; relative paths become absolute
  config file --reset  Clear the saved path; keep the personal file
  config show          Show saved/loaded paths and the last load exit code
  -V, --version        Show the loaded aliases tool version
  -h, --help           Show this help

After setting or resetting a path, run aliases reload or open a new terminal.
Personal aliases/functions override defaults. Defaults skip existing names.
Later manual changes are preserved until a fresh shell. Reload restores earlier
definitions only while the current value still matches the one this tool loaded.
The personal file is trusted Zsh code: source may execute commands and functions.
Only regular aliases and function definitions are tracked; other script effects
are not undone. Loading is quiet; list/config show report a failed last load.
No personal file is discovered automatically, uploaded or changed by this tool.

Examples: aliases list; aliases show ll
          aliases config file ~/.zshrc_alias; aliases reload
Exit codes: 0 success; 2 invalid arguments/configuration; 1 load/write failure.' ;;
    error.usage) printf '%s\n' 'Usage: aliases list | show NAME | reload | config ... | --help | --version' ;;
    error.config_usage) printf '%s\n' 'Usage: aliases config show | aliases config file [path|--reset]' ;;
    error.config_file) printf '%s\n' 'Invalid, unreadable or linked aliases configuration: %s' ;;
    error.config_write) printf '%s\n' 'Could not save aliases configuration: %s' ;;
    error.path) printf '%s\n' 'Invalid personal file path: %s (use a nonempty path without line breaks).' ;;
    error.personal_file) printf '%s\n' 'Personal file is not a readable regular file: %s' ;;
    error.personal_syntax) printf '%s\n' 'Personal file has invalid Zsh syntax: %s' ;;
    error.personal_load) printf '%s\n' 'Personal file failed: %s (exit %s). Alias/function definitions were restored.' ;;
    error.dependency) printf '%s\n' 'Required configuration command is missing: %s' ;;
    error.unknown) printf '%s\n' 'Name is not tracked by aliases: %s' ;;
    error.last_load) printf '%s\n' 'The last load failed; run aliases reload for details.' ;;
    error.recursive) printf '%s\n' 'Recursive aliases reload is not supported.' ;;
    config.show) printf '%s\n' 'Config: %s
Saved personal file: %s
Loaded personal file: %s
Last load exit code: %s' ;;
    config.saved) printf '%s\n' 'Configuration saved. Run aliases reload or open a new terminal to apply it.' ;;
    reloaded) printf '%s\n' 'Aliases reloaded in this shell.' ;;
    list.header) printf '%s\n' 'NAME               TYPE      SOURCE       STATE          CURRENT DEFINITION' ;;
    show.header) printf '%s\n' 'Name: %s
Type: %s
Source: %s
State: %s' ;;
    show.absent) printf '%s\n' '(not defined)' ;;
    source.builtin) printf '%s\n' 'builtin' ;;
    source.personal) printf '%s\n' 'personal' ;;
    state.active) printf '%s\n' 'active' ;;
    state.skipped) printf '%s\n' 'skipped' ;;
    state.overridden) printf '%s\n' 'overridden' ;;
    state.removed) printf '%s\n' 'removed' ;;
    state.shadowed) printf '%s\n' 'shadowed' ;;
    completion.command) printf '%s\n' 'Aliases command' ;;
    completion.list) printf '%s\n' 'List sources and active definitions' ;;
    completion.show) printf '%s\n' 'Show a tracked alias or function' ;;
    completion.reload) printf '%s\n' 'Reload aliases in this shell' ;;
    completion.config) printf '%s\n' 'Configure the personal file' ;;
    completion.file) printf '%s\n' 'Set or show the personal Zsh file' ;;
    completion.config_show) printf '%s\n' 'Show saved and loaded configuration' ;;
    completion.reset) printf '%s\n' 'Clear the saved personal file path' ;;
    completion.help) printf '%s\n' 'Show aliases help' ;;
    completion.version) printf '%s\n' 'Show aliases version' ;;
    *) return 1 ;;
  esac
}
