# mac-shell-tools

[简体中文](README-cn.md)

A small Zsh toolkit for macOS. Its first command, `dsize`, shows the largest entries in a directory with directory and option Tab completion.

Requires macOS, Zsh, and the standard macOS command-line tools. The intended environment already uses Oh My Zsh. No `sudo`, Homebrew, Node.js, Python, or additional runtime is needed. The installer does not install Oh My Zsh.

## Install

From a local checkout:

```sh
sh install.sh
```

`install.sh` is self-contained. You can copy or share that single file and run it from any directory without the rest of the repository.

Once `install.sh` has been published on this repository's `main` branch, download and run it:

```sh
curl -fsSL -o install.sh "https://raw.githubusercontent.com/bran-nie/mac-shell-tools/main/install.sh"
sh install.sh
```

Or install directly:

```sh
curl -fsSL "https://raw.githubusercontent.com/bran-nie/mac-shell-tools/main/install.sh" | sh
```

Open a new terminal afterward, or run the `source` command printed by the installer. With default paths, that command is:

```zsh
source "$HOME/.zshrc"
dsize --help
```

The installer runs in a child process; activation happens when your Zsh loads the updated configuration.

## Use dsize

```zsh
dsize
dsize ~/Library
dsize ~/Library/Caches -n 50
dsize ~/Library -d 3 -n 50
dsize -n 50 ~/Library
dsize ~/Library --depth=3 --lines=30
dsize "$HOME/Library/Application Support" -n 30
dsize -- ./-example
```

| Argument | Default | Accepted values |
| --- | --- | --- |
| Directory | `.` | One existing directory |
| `-d N`, `--depth N`, `--depth=N` | `2` | Decimal integer, 0–1000 |
| `-n N`, `--lines N`, `--lines=N` | `25` | Decimal integer, 1–1000000 |
| `-h`, `--help` | | Show help |
| `--` | | Stop parsing options; at most one directory may follow |

Options and the directory may appear in either order. Repeated options use the last value. Leading zeros are interpreted as decimal. Use normal Shell quoting for spaces; the command does not evaluate or expand input strings with `eval`.

The output uses the ordinary `du` format: readable units, ascending size, and the largest N lines. **The largest entry appears last.** The target directory's total is included. No headers, colors, or percentages are added.

Exit codes: `0` for success or help, `2` for invalid arguments or paths, and `1` for an incomplete scan, interruption, or command failure. When `du` fails, available results can still be printed with a brief diagnostic on stderr. Repeated permission errors are suppressed.

### Tab completion

`dsize <Tab>` completes directories, including paths with spaces. Options, help flags, depth suggestions (`0 1 2 3 4 5`), and line-count suggestions (`10 25 50 100`) are supported, including `--depth=` and `--lines=`. Suggestions do not restrict accepted values. Completion never runs a disk scan.

Load the toolkit **after Oh My Zsh or `compinit` initializes completion**. The tools register with `compdef` when it is available and never run `compinit` themselves. The command also works without a completion system.

## Paths and configuration

Default installation:

```text
~/.config/zsh/tools/
├── init.zsh
└── dsize.zsh
```

- Tools: `${XDG_CONFIG_HOME:-$HOME/.config}/zsh/tools`.
- Main configuration: `${ZDOTDIR:-$HOME}/.zshrc`.
- Unset or empty variables use the defaults. Nonempty relative paths are rejected.

For example:

```sh
XDG_CONFIG_HOME="$HOME/Custom Config" ZDOTDIR="$HOME/Custom Zsh" sh install.sh
```

The installer appends one marked block at the end of the main configuration, after the existing Oh My Zsh setup. The block checks for `init.zsh` before sourcing it. It stores the resolved absolute installation path with Zsh quoting; changing environment variables later does not relocate that reference. Run the installer with the desired paths again when changing locations. Parent-directory symlinks are resolved without replacing them.

`init.zsh` locates tools relative to itself and explicitly loads registered files. It stays quiet, does not change directories, and does not glob-load unregistered scripts or backups. You can source it again to refresh definitions.

## Updates, backups, and recovery

Run a newer `install.sh` to update. Identical files are left untouched. Changed `dsize.zsh`, `init.zsh`, and existing `.zshrc` files are backed up before replacement:

```text
<file>.bak.YYYYMMDD-HHMMSS.<random-suffix>
```

Every backup path is printed. To restore, copy a selected backup to its original path and reload the configuration. Only the marked tool-registration area in an existing `init.zsh` is updated; other references and comments remain. Unrelated `.zshrc` content stays intact, and the toolkit block moves to the end.

Unknown entry files, damaged or duplicated markers, non-file targets, and symlinked configuration files or final tool directories cause installation to stop. Symlinks and their targets remain unchanged. Resolve these cases manually before retrying. A simultaneous installation into the same tool directory is rejected; remove a stale `.mac-shell-tools-install.lock` directory only after confirming no installer is running.

Content is prepared and syntax-checked before writes. Each file is replaced through a same-directory temporary file; tools and the entry are installed before the main configuration. A failed update may leave some files updated, with backups available. Correct the reported failure and rerun, or restore the backups.

Other `source` lines and manually defined functions are not rewritten. If you already defined `dsize()`, `_dsize()`, or `compdef _dsize dsize` yourself, remove those duplicate definitions manually where appropriate, including in `.zshrc_alias`. Custom load order can still override names.

## Uninstall

1. Remove the `.zshrc` block between `# >>> mac-shell-tools >>>` and `# <<< mac-shell-tools <<<` if no other tools depend on that entry. If you keep personal tools in the entry, keep its reference and remove only the `dsize.zsh` registration.
2. Remove the installed `dsize.zsh` after confirming it belongs to this project. Remove `init.zsh` only if it contains no personal registrations or comments you need.
3. Keep your other tools and any backups you still need. Open a new terminal to clear loaded function definitions.

Do not delete the entire shared tools directory as an uninstall shortcut.

## Interpreting sizes

`dsize` reports **disk usage**, which can differ from logical file sizes, Finder totals, macOS “System Data,” or space actually released after deletion. Hard links and APFS behavior can affect the numbers. Parent totals include children, so the displayed lines cannot be added together.

Depth controls displayed levels, not traversal: calculating totals can still read deeper directories. A lower depth does not guarantee a faster scan. Restricted directories can produce incomplete results. Output retains `du`'s text format, so filenames containing tabs or newlines are not unambiguous records. The toolkit only measures; it does not delete or clean files.

## Development

```sh
sh scripts/build-installer.sh
sh scripts/check.sh
```

The checks require macOS and use temporary HOME/config directories. They cover the real BSD pipeline, input errors, permissions, command failures, interruption, installation, backups, configuration preservation, self-contained/stdin installation, and real Tab completion in a Zsh pseudo-terminal. CI runs the same command on macOS.

See [development notes](docs/development.md) for adding tools, updating the generated installer, and a short terminal-specific manual checklist.

No project license has been selected yet.
