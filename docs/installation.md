# Installation and recovery

[简体中文](installation-cn.md) · [Project README](../README.md)

## Install the manager, then tools

The recommended GitHub command in the project README runs the self-contained `install.sh` without arguments. This installs mst and its shared loader, with no tools enabled. Then run:

```sh
mst list
mst install dsize
```

`mst` works from any directory in Zsh once the configuration has loaded. It is a function that locates a saved launcher beside its own definition file; neither a PATH change nor the original repository is needed. Bare `mst` displays help.

## Online updates and offline commands

| Command | Source and effect |
| --- | --- |
| `mst list` | Read the local catalog and installed-tool manifest |
| `mst install <tool>` | Fetch the latest package, install selected tools, and refresh the manager |
| `mst install --all` | Fetch the latest package and install every available tool |
| `mst update [tool ...]` | Fetch the latest package and update installed tools only; keep the manager version |
| `mst upgrade` | Fetch the latest manager and catalog; leave tool files and installed-tool selection unchanged |
| `mst uninstall <tool>` / `mst uninstall --all` | Remove registered tools offline; retain mst |

Online operations fetch [the GitHub main installation package](https://raw.githubusercontent.com/bran-nie/mac-shell-tools/main/install.sh). The complete download is checked for content, shell syntax, and the supported bootstrap marker before it runs or writes configuration. A failed or invalid download leaves existing managed files unchanged.

`mst list` uses the last saved catalog. Run `mst upgrade` to discover newly published tools, then install the ones you want. Neither `upgrade` nor `update` installs new or previously removed tools. An `update` with no installed tools is a local no-op.

Tool commands accept multiple names. `install` without names means all available tools; `update` without names means all installed tools. `--all` selects all for the operation and cannot be combined with names. `uninstall` requires names or `--all`; `upgrade` and `list` accept neither.

For local or single-file distribution, `sh install.sh` installs mst only. Explicit commands such as `sh install.sh install dsize` use the files embedded in that copy of the script. Installed `mst` uses the online behavior above.

## Paths and ownership

| Item | Path |
| --- | --- |
| Installation root | `${XDG_CONFIG_HOME:-$HOME/.config}/zsh/mac-shell-tools` |
| Shared loader | `<root>/init.zsh` |
| Manager library | `<root>/manager/manager-core.sh` |
| Launcher and Zsh function | `<root>/manager/mst.sh` and `mst.zsh` |
| Manager version and language packs | `<root>/manager/version` and `locales/` |
| Tool bundle | `<root>/tools/<name>/`, including source, `version`, `files.list`, and language packs |
| Installed-tool manifest | `<root>/tools/installed.list` |
| Saved preferences | `<root>/config.conf` |
| New backups | `<root>/backups/` |
| Main Zsh configuration | `${ZDOTDIR:-$HOME}/.zshrc` |

Unset or empty environment variables use the defaults; nonempty relative paths are rejected. For example, with a downloaded installer:

```sh
XDG_CONFIG_HOME="$HOME/Custom Config" ZDOTDIR="$HOME/Custom Zsh" sh install.sh
```

The loader records the resolved absolute path to `init.zsh`, with Zsh quoting. The installed launcher remembers both the tools directory and `.zshrc` path, including when it delegates to a newly downloaded package. Later environment changes do not redirect `mst` to another configuration. A new session started by mst uses the recorded configuration directory. Parent-directory symlinks are resolved without replacing the links.

The installed-tool manifest is plain data with four tab-separated fields per line: tool filename, source version, source revision, and source state (`clean`, `modified`, or `unknown`). It controls updates and uninstallation and is never executed. Each component also has a three-line `version` record and each tool has a `files.list` ownership record for its bundle. Personal files added to a tool's directory are retained on uninstall. Keep these records with the installed files.

Manager-only installation and upgrade do not change tool records, except when migrating the previous layout. Without an installed manifest, only exact known tool registrations inside the entry's managed block are recognized, with version `unknown`; a same-named file alone does not establish ownership.

`list` also includes registered tools absent from the local catalog, and reports missing files. An unnamed `update` preserves and skips tools absent from the latest package; explicitly updating one is an error. A registered tool can still be uninstalled after it is removed from the catalog.

## Language

English is the default; Simplified Chinese uses `zh-CN`:

```sh
mst config language zh-CN
mst config language en
mst config language
mst --lang zh-CN list
```

The saved setting applies to mst and tool help, diagnostics, and completion descriptions on the next call, including already loaded tools. Changing it does not start a new shell. `--lang` overrides the manager's language for one command; `MST_LANG=en` or `MST_LANG=zh-CN` provides an environment override for mst or a tool. Precedence is `--lang` → `MST_LANG` → saved preference → English. The query shows the saved preference.

Preferences are validated data, never sourced as shell code. Unsupported values or malformed configuration produce an error; an explicit language override can be used to repair a malformed configuration. Missing translations fall back to English. Tool names, options, paths, disk-usage data, versions, and exit codes are unchanged by language selection. Manager language packs are upgraded with mst; tool language packs are updated with their tool.

## Versions

`mst --version` (also `mst version`) reports the installed manager's source version, revision, and state. `dsize --version` reports the function loaded in the current shell. After an update with automatic activation disabled, source the printed entry to load the new function before checking its version.

Releases use `MAJOR.MINOR.PATCH` and Git tags `vX.Y.Z`. Unreleased builds use versions such as `0.1.0-dev+<source-digest>`. A development snapshot may have source state `modified`; without Git provenance it records `unknown`. The source revision describes the build's source snapshot, which may precede the generated-package publication commit.

`mst list` shows installed and available source versions separately. `mst upgrade` changes mst and its local catalog; `mst update` changes installed tool bundles and their version records. Online commands fetch the published `main` package, rather than selecting a release by comparing version numbers.

## Migrating the previous layout

Run `mst upgrade` to migrate an installation in `${XDG_CONFIG_HOME:-$HOME/.config}/zsh/tools`. The installed launcher remembers its original paths, so custom configuration locations are preserved even if the current environment differs. Re-running the new bootstrap also recognizes the default old layout.

Only registered tools are copied into the new per-tool directories. Their source stays unchanged and records `unknown` until `mst update [tool ...]` installs a versioned bundle. This also means an unchanged old tool keeps its original messages until updated. Registered tools absent from the new catalog are retained and remain uninstallable.

The `.zshrc` managed block is redirected to the new loader. The old loader's managed registrations are retired, while its personal content stays at the original path and is sourced by the new loader; relative personal references therefore remain valid. The old mst launcher forwards to the new one for existing sessions. Original tool copies, personal files, and old backups are retained. Keep the old directory while these compatibility or personal references are needed.

Migration acquires both locations' locks and records a recovery journal. After a failure, fix the reported issue and retry the same upgrade or bootstrap command. Conflicting files, invalid records, missing registered tools, and linked managed directories are preserved and reported instead of silently overwritten.

## Configuration preservation

The main configuration uses these unique markers:

```text
# >>> mac-shell-tools >>>
# <<< mac-shell-tools <<<
```

The loader block is added at the end, after existing Oh My Zsh initialization. `init.zsh` loads mst and explicitly registered tools from its own directory. It never scans or executes arbitrary scripts and backups. Its managed region uses:

```text
# >>> mac-shell-tools managed tools >>>
# <<< mac-shell-tools managed tools <<<
```

Content outside these blocks is preserved. Unknown entry files, broken or duplicate markers, non-file targets, symlinked managed files, and symlinked final tools or manager directories stop changes. Unregistered personal files are not removed.

Uninstalling the last tool leaves mst, the shared entry, and its main-configuration reference available for later queries and installations. Tool registrations and the empty tool manifest are removed. Unrelated files, backups, and `.zshrc` itself are kept.

Other `source` lines, manual functions, and aliases are not rewritten. Existing definitions with the same names may override project functions or remain after removal; manage those definitions separately.

## Session activation

After a successful file change, mst starts a new login Zsh if both input and output are terminals. It releases its lock and removes download, bootstrap, and installation temporary files before starting the session. This child session reloads configuration; it does not edit the caller's in-memory state.

`--no-run-zsh`, `--unattended`, or `RUNZSH=no` disables this behavior. Queries, failures, unchanged operations, piped input, and redirected output do not start Zsh. `RUNZSH` accepts `yes` or `no`; unset or empty means `yes`. Exiting the new session may return to the previous one; unexported variables and functions are not carried over.

The recommended `sh -c` download command retains terminal input. `curl ... | sh` gives the installer piped input, so activation is manual.

After installation or update, use the printed `source` command or open a new terminal when needed. After uninstallation, start a fresh session or run `exec zsh -l`: re-sourcing configuration does not clear functions already loaded in memory.

## Backups and recovery

Every changed or removed existing file, including manager files and tool records, is backed up under `<root>/backups/`, mirroring its relative path:

```text
backups/tools/dsize/dsize.zsh.bak.YYYYMMDD-HHMMSS.<random-suffix>
backups/zshrc/.zshrc.bak.YYYYMMDD-HHMMSS.<random-suffix>
backups/legacy/init.zsh.bak.YYYYMMDD-HHMMSS.<random-suffix>
```

Backup paths are printed. Identical files are not rewritten and create no backup. Prepared content is syntax-checked, all changed targets are checked for writability, and each replacement uses a temporary file in the target directory.

Operations are not transactions across multiple files. A later write or removal can fail after earlier changes succeeded. Fix the reported failure and repeat the command, or restore the corresponding backups of the manager, tools, manifest, entry, and main configuration together. Keep their registrations consistent, then start a new Zsh session. Re-run the GitHub installation command to repair a missing or damaged manager.

Only one operation can hold `<root>/.mac-shell-tools-install.lock`. Remove a stale lock manually only after confirming that no management operation is running. Failure cleanup removes only the operation's own lock and temporary files.
