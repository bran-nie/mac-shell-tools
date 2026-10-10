# mac-shell-tools

[简体中文](README-cn.md)

A small Zsh tool manager for macOS. Install **mst** first, then choose the tools you need.

Requires macOS, Zsh, and standard macOS commands, including curl for online operations. Load after Oh My Zsh or `compinit` for Tab completion. No `sudo`, Homebrew, or extra runtime is required.

## Install mst

Run this command to install the manager from GitHub:

```sh
mac_shell_tools_installer="$(curl -fsSL "https://raw.githubusercontent.com/bran-nie/mac-shell-tools/main/install.sh")" &&
  sh -c "$mac_shell_tools_installer"
```

This installs **mst only**. In an interactive terminal, a successful change starts a new login Zsh in the same window, making `mst` available immediately. Exiting it may return to the previous session.

Then choose your tools, from any directory:

```sh
mst list
mst install dsize
```

Use `mst install --all` if you want every available tool. You do not need to keep the repository or installation script.

## Manage tools

| Command | Behavior |
| --- | --- |
| `mst list` | Show tools, installation status, and installed/available versions, offline |
| `mst install dsize` | Install or update selected tools; refresh mst and its catalog |
| `mst install --all` | Install or update all available tools |
| `mst update` | Update installed tools only |
| `mst update dsize` | Update a selected installed tool |
| `mst upgrade` | Upgrade mst and refresh its catalog, keeping installed tools unchanged |
| `mst uninstall dsize` | Uninstall selected tools, with backups |
| `mst uninstall --all` | Uninstall all registered tools; keep mst available |
| `mst config language` | Show the saved language; default: English |
| `mst config language en` | Save English for mst and tools |
| `mst config language zh-CN` | Save Simplified Chinese for mst and tools |
| `mst --help` | Show commands and options |

`install`, `update`, and `upgrade` fetch the latest package from GitHub `main`. `list` and `uninstall` work offline. When new tools are published, run `mst upgrade`, then `mst list` and `mst install <tool>`. New tools are never installed by `upgrade` or `update`, and removed tools stay removed.

Tool commands accept multiple names. `install` without names means all available tools; `update` without names means all installed tools. `--all` cannot be combined with names.

After a change, an interactive terminal starts a new login Zsh. Pass `--no-run-zsh` or `--unattended`, or set `RUNZSH=no`, to skip it. Queries, unchanged operations, piped input, and redirected output also skip it. Follow the printed activation command when needed; after uninstalling, start a new terminal or run `exec zsh -l` to clear loaded functions. A new session reloads configuration and does not carry over unexported variables or functions.

## Tools

| Tool | Description | Documentation |
| --- | --- | --- |
| `dsize` | Show disk usage for a chosen directory (up to 25 largest results by default), with directory Tab completion | [Usage](docs/tools/dsize/README.md) |

## Configuration

The default installation root is `~/.config/zsh/mac-shell-tools/`:

```text
~/.config/zsh/mac-shell-tools/
├── init.zsh              # Shared loader, referenced by .zshrc
├── manager/              # mst, its version, and language packs
├── tools/
│   ├── installed.list    # Installed tools and their versions
│   └── dsize/            # dsize source, version, and language packs
├── config.conf           # Saved preferences, created when configured
└── backups/              # Backups of changed or removed files
```

`mst` is a Zsh function, so no PATH changes are needed. Set `XDG_CONFIG_HOME` and `ZDOTDIR` to absolute paths before installation to customize these locations. Installed management commands remember their original paths.

Existing installations in `~/.config/zsh/tools` migrate with `mst upgrade`. Tool content is preserved; tools without version records show `unknown` until updated. Personal files and old backups remain at their original location. See [installation and recovery](docs/installation.md).

For local installation, run `sh install.sh` from a checkout. The `curl ... | sh` form also installs mst, but requires manual activation.

## Language and versions

Output defaults to English. A saved language applies to mst and tool help, errors, and completion descriptions on their next invocation, without opening a new terminal:

```sh
mst config language zh-CN   # Save Simplified Chinese
mst config language en      # Save English
mst config language         # Show the saved language
mst --lang zh-CN list        # Use Chinese for this command only
mst --version
dsize --version
```

The project uses `MAJOR.MINOR.PATCH` releases, tagged `vX.Y.Z`; development versions include `-dev` and a source digest. Each installed component records its own source release and revision. `mst upgrade` keeps tool versions; `mst update` updates installed tool versions. See [versioning details](docs/development.md#版本与发布).

## Development

```sh
sh scripts/build-installer.sh
sh scripts/check.sh
```

The macOS checks use temporary HOME/config directories and mock downloads, including real Tab completion and login-session tests in pseudo-terminals. See [development notes](docs/development.md).

## License

[MIT](LICENSE) © 2026 bran.nie.
