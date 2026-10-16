# mac-shell-tools

[简体中文](README-cn.md)

A small Zsh tool manager for macOS and Linux. Install **mst** first, then choose the tools you need.

Requires Zsh and standard system commands; online synchronization also requires curl and tar. On Linux, use GNU Coreutils or compatible commands. The shared loader reuses existing completion (including Oh My Zsh), or initializes it in interactive Zsh when needed. The manager installs into your user configuration directory without `sudo`. See [Ubuntu 24.04 prerequisites](docs/installation.md#supported-systems-and-zsh).

## Install mst

Run this command to install the manager from GitHub:

```sh
mac_shell_tools_installer="$(curl -fsSL "https://raw.githubusercontent.com/bran-nie/mac-shell-tools/main/install.sh")" &&
  sh -c "$mac_shell_tools_installer"
```

The lightweight bootstrap downloads one source snapshot, installs **mst**, and synchronizes ordinary scripts into a local repository. **No tools are enabled.** In an interactive terminal, a successful change starts a new login Zsh in the same window, making `mst` available immediately. Exiting it may return to the previous session.

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
| `mst install dsize` | Install or reinstall selected tools from the local repository |
| `mst install --all` | Install all available tools from the local repository |
| `mst update` | Synchronize scripts, then update installed tools only |
| `mst update dsize` | Update a selected installed tool |
| `mst upgrade` | Upgrade mst and synchronize scripts, keeping installed tools unchanged |
| `mst uninstall dsize` | Uninstall selected tools, with backups |
| `mst uninstall --all` | Uninstall all registered tools; keep mst available |
| `mst config language` | Show the saved language; default: English |
| `mst config language list` | List supported languages and mark the current language |
| `mst config language en` | Save English for mst and tools |
| `mst config language zh-CN` | Save Simplified Chinese for mst and tools |
| `mst --help` | Show commands and options |

`upgrade` and `update` synchronize a source snapshot from GitHub `main`. Ordinary `install`, `list`, and `uninstall` work offline. Tools declaring additional online resources download and verify those resources during installation. When new tools are published, run `mst upgrade`, then `mst list` and `mst install <tool>`. New tools are never installed by `upgrade` or `update`, and removed tools stay removed.

Tool commands accept multiple names. `install` without names means all available tools; `update` without names means all installed tools. `--all` cannot be combined with names.

After a change, an interactive terminal starts a new login Zsh. Pass `--no-run-zsh` or `--unattended`, or set `RUNZSH=no`, to skip it. Queries, unchanged operations, piped input, and redirected output also skip it. Follow the printed activation command in Zsh when needed; from Bash, enter Zsh with `zsh -l`. After uninstalling, start a fresh Zsh or run `exec zsh -l` to clear loaded functions. A new session reloads configuration and does not carry over unexported variables or functions.

## Tools

| Tool | Description | Documentation |
| --- | --- | --- |
| `dsize` | Show a disk-usage tree (up to 25 lines by default), with include/exclude filters and directory Tab completion | [Usage](docs/tools/dsize/README.md) |
| `portwho` | Find programs listening on one or more TCP ports, with PID, user, and address | [Usage](docs/tools/portwho/README.md) |
| `extract` | Extract ZIP and common TAR archives into a new directory, with preview and Tab completion | [Usage](docs/tools/extract/README.md) |
| `npmg` | Install, update, uninstall, and list npm global packages in a shared directory; requires Node and npm | [Usage](docs/tools/npmg/README.md) |
| `aliases` | Load common aliases and a personal Zsh file, with source inspection and reload | [Usage](docs/tools/aliases/README.md) |

## Configuration

The default installation root is `~/.config/zsh/mac-shell-tools/`:

```text
~/.config/zsh/mac-shell-tools/
├── init.zsh              # Shared loader, referenced by .zshrc
├── manager/              # mst, its version, and language packs
├── repository/           # Synchronized catalog and scripts; never auto-loaded
├── tools/
│   ├── installed.list    # Installed tools and their versions
│   ├── dsize/            # Each installed tool has its own source, version,
│   ├── portwho/          # and language packs; only selected tools appear
│   ├── extract/
│   ├── npmg/
│   └── aliases/
├── config.conf           # Saved preferences, created when configured
├── npmg.conf             # Optional saved npmg prefix; retained on uninstall
├── aliases.conf          # Optional personal Zsh file path; retained on uninstall
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
mst config language list    # List languages; * marks the effective language
mst --lang zh-CN list        # Use Chinese for this command only
mst --version
dsize --version
```

`mst config language list` shows `en` (English) and `zh-CN` (简体中文) without changing settings. Its `*` marker follows `--lang` → `MST_LANG` → saved preference → English. Tab completion is available for `mst config language` and its values.

The project uses `MAJOR.MINOR.PATCH` releases, tagged `vX.Y.Z`. Each tool has an independent version; development versions include `-dev` and that tool's source digest. Adding tools or changing the manager or documentation leaves other tool versions unchanged. Shared runtime changes update the affected tools' versions. `mst upgrade` keeps installed versions; `mst update` updates installed tools. See [versioning details](docs/development.md#版本与发布).

## Development

```sh
sh scripts/build-installer.sh
sh scripts/check.sh
```

Checks use temporary HOME/config directories and mock downloads, including real Tab completion and login-session tests in pseudo-terminals. PR/main checks select affected suites on macOS. Manual, release and weekly full runs also cover Ubuntu. Use `sh scripts/check.sh --tool npmg` for one tool; timing reports and logs are saved under `.artifacts/`. See [development notes](docs/development.md).

## License

[MIT](LICENSE) © 2026 bran.nie.
