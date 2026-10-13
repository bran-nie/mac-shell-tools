# mst_text_en message catalog.
mst_text_en() {
  case $1 in
    help) printf '%s\n' 'Usage: npmg [command] [package ...] [npm options]

Manage global npm packages using the active Node and npm.
Prefix priority: explicit --prefix, saved prefix, then $HOME/.local/npm.
A package without a command is shorthand for install; no arguments show help.

  install, i        Install packages; package versions/tags are supported
  update, up        Update named packages, or all packages when no names are given
  uninstall, rm     Uninstall named packages
  list, ls          List installed packages (default --depth=0)
  config prefix     Show the effective prefix
  config prefix DIR Save a prefix; relative paths become absolute
  config prefix --reset
                    Restore the default prefix
  config show       Show prefix, source, config file and bin directory
  -V, --version     Show the loaded npmg tool version
  -h, --help        Show this help

Every package operation defaults to -g --prefix <effective prefix>.
Explicit npm options can override defaults. All remaining arguments, output,
errors and exit codes belong to npm. Subcommand --help/--version belong to npm.
Use npmg install <name> for a package named like a command, or npmg -- <name>.
Loading npmg adds the effective prefix/bin to PATH once, keeping existing priority.
Saving/resetting the prefix updates this shell as well as future loads.
Config commands do not require Node/npm and never change npm configuration.
Node and npm must be available in the current PATH; dependencies are not installed.

Examples: npmg live-server; npmg install playwright @larksuite/cli
          npmg update; npmg rm live-server; npmg ls --json
          npmg live-server@latest --dry-run; npmg install --help
Bare install follows npm behavior and installs the current package context.
Exit codes: 0 help/version; 2 language configuration error; 1 missing dependency;
package operations return npm exit codes.' ;;
    error.dependency) printf '%s\n' 'Required command is missing: %s. Make Node and npm available in the current PATH first.' ;;
    error.config_dependency) printf '%s\n' 'Required configuration command is missing: %s' ;;
    error.config_usage) printf '%s\n' 'Usage: npmg config show | npmg config prefix [directory|--reset]' ;;
    error.config_file) printf '%s\n' 'Invalid, unreadable or linked npmg configuration: %s' ;;
    error.config_write) printf '%s\n' 'Could not save npmg configuration: %s' ;;
    error.prefix) printf '%s\n' 'Invalid prefix: %s (use a nonempty path without colons or line breaks).' ;;
    config.show) printf '%s\n' 'Prefix: %s
Source: %s
Config: %s
Bin: %s' ;;
    config.saved) printf '%s\n' 'Prefix: %s' ;;
    completion.help) printf '%s\n' 'Show npmg help' ;;
    completion.version) printf '%s\n' 'Show npmg version' ;;
    completion.npm_help) printf '%s\n' 'Show npm command help' ;;
    completion.npm_version) printf '%s\n' 'Show npm version' ;;
    completion.command) printf '%s\n' 'Command or package to install' ;;
    completion.package) printf '%s\n' 'npm package specification' ;;
    completion.prefix) printf '%s\n' 'Override the shared installation directory' ;;
    completion.registry) printf '%s\n' 'npm registry URL' ;;
    completion.depth) printf '%s\n' 'Dependency display depth' ;;
    completion.install) printf '%s\n' 'Install global packages' ;;
    completion.update) printf '%s\n' 'Update global packages' ;;
    completion.uninstall) printf '%s\n' 'Uninstall global packages' ;;
    completion.list) printf '%s\n' 'List installed global packages' ;;
    completion.config) printf '%s\n' 'Configure npmg' ;;
    completion.show) printf '%s\n' 'Show effective configuration' ;;
    completion.reset) printf '%s\n' 'Restore the default prefix' ;;
    *) return 1 ;;
  esac
}
