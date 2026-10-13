# npmg

[简体中文](README-cn.md)

Manage npm global packages in a shared directory, independent of nvm version directories, using the currently active Node and npm. The default is `$HOME/.local/npm`; you can save a different prefix.

## Install

```sh
mst upgrade
mst install npmg
```

Node and npm must be available in the current PATH before installing or updating npmg. With nvm, activate a Node version first. A missing dependency stops selected installs, including multiple tools or `--all`, before tools are written. `mst upgrade`, tool listing, and uninstallation do not require Node/npm.

Installing npmg copies the wrapper offline. Package operations use your npm configuration and may access its registry. Loading npmg reads its prefix setting and appends `{prefix}/bin` to PATH once, preserving existing command priority. Loading does not create directories or write npm configuration.

## Configure the prefix

```sh
npmg config prefix "$HOME/tools/npm"
npmg config prefix
npmg config show
npmg config prefix --reset
```

`config prefix <directory>` saves the directory; relative paths are normalized to absolute paths at the time of the command, and a quoted `~/...` is also supported. `config prefix` prints the effective directory. `config show` shows the directory, its `saved`/`default` source, the configuration file, and bin directory. `--reset` removes the saved setting and restores `$HOME/.local/npm`.

Prefix priority is **explicit npm `--prefix` > saved prefix > default**. A one-off npm override does not change the saved setting or PATH. Saving/resetting changes PATH in the current shell and later loads; npmg removes only a previous PATH entry it added and preserves independently configured entries. Package directories are not created, moved, copied, or deleted when changing this setting, so packages in the old directory remain there.

The setting is a data-only `npmg.conf` beside the installed shared `init.zsh`. It stays at that installation's pinned location if `XDG_CONFIG_HOME` later changes. Directly loading source from a checkout uses `${XDG_CONFIG_HOME:-$HOME/.config}/zsh/mac-shell-tools/npmg.conf`. These commands work without Node/npm and do not modify `.npmrc` or set persistent `NPM_CONFIG_PREFIX`. Saving requires standard mkdir/mktemp/mv/rm commands. Empty paths, colons and line breaks are rejected; writes use a private same-directory temporary file. Invalid or linked configuration produces an error on package/config reads; `config prefix --reset` can repair malformed data, while startup stays quiet.

## Usage

| Command | Behavior |
| --- | --- |
| `npmg live-server` | Shortcut for `npmg install live-server` |
| `npmg install playwright @larksuite/cli` | Install one or more packages |
| `npmg update live-server` | Update a named package |
| `npmg update` | Update all packages in the prefix |
| `npmg uninstall live-server` | Uninstall a named package |
| `npmg list` | List installed packages, defaulting to `--depth=0` |

Aliases: `i` for `install`, `up` for `update`, `rm` for `uninstall`, and `ls` for `list`.

All package operations default to `-g --prefix <effective prefix>`. Remaining arguments retain their order and boundaries; explicit npm flags can override defaults:

```sh
npmg live-server@latest --dry-run
npmg live-server --registry=https://registry.npmjs.org
npmg install live-server --prefix "$HOME/other-npm"
npmg list --depth=2 --json
npmg install ./local-package --global=false --prefix ./project
```

PATH setup covers the effective saved/default prefix. Add a one-off override's `bin` directory yourself if needed. Commands earlier in PATH retain priority, including older copies of a CLI in the active nvm directory.

`npmg`, `npmg --help`, and `npmg -h` show wrapper help; `npmg --version` and `npmg -V` show its loaded version. Subcommand `--help` and `--version` belong to npm, for example `npmg install --help`. Options preceding a package also use shortcut install. For a package named like a subcommand, use `npmg install update` or `npmg -- update`.

Bare `npmg` shows help. Explicit `npmg install` without package arguments follows npm behavior and installs the current package context. Updates follow npm's version rules; use install with an explicit version or tag when needed.

## Runtime, ownership, and completion

Every package operation rechecks Node/npm and returns npm's output, errors, stdin behavior, and exit status unchanged. Missing dependencies return `1`, invalid mst language configuration returns `2`, and wrapper help/version return `0`. npmg's help, errors, and completion follow mst's language setting; npm output stays unchanged.

The wrapper does not install or select Node. Shared packages must support the active Node version; native addons may need rebuilding after a version change. See the official [npm folder layout](https://docs.npmjs.com/cli/v11/configuring-npm/folders/), [update rules](https://docs.npmjs.com/cli/v11/commands/npm-update/), [rebuild behavior](https://docs.npmjs.com/cli/v11/commands/npm-rebuild/), and [nvm prefix compatibility notes](https://github.com/nvm-sh/nvm#compatibility-issues).

`mst update npmg` updates the wrapper; `npmg update` updates npm packages. `mst uninstall npmg` leaves its saved configuration, the shared prefix and its packages intact.

Tab suggests subcommands, aliases, and common options, including directory completion for `--prefix`. It never invokes npm or queries the registry for package names. Options without completion suggestions can still be passed.
