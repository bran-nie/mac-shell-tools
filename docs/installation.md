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
| Tools and shared entry | `${XDG_CONFIG_HOME:-$HOME/.config}/zsh/tools` |
| Manager library | `<tools directory>/.mac-shell-tools/manager-core.sh` |
| Launcher and Zsh function | `<tools directory>/.mac-shell-tools/mst.sh` and `mst.zsh` |
| Installed-tool manifest | `<tools directory>/.mac-shell-tools-installed` |
| Main Zsh configuration | `${ZDOTDIR:-$HOME}/.zshrc` |

Unset or empty environment variables use the defaults; nonempty relative paths are rejected. For example, with a downloaded installer:

```sh
XDG_CONFIG_HOME="$HOME/Custom Config" ZDOTDIR="$HOME/Custom Zsh" sh install.sh
```

The loader records the resolved absolute path to `init.zsh`, with Zsh quoting. The installed launcher remembers both the tools directory and `.zshrc` path, including when it delegates to a newly downloaded package. Later environment changes do not redirect `mst` to another configuration. A new session started by mst uses the recorded configuration directory. Parent-directory symlinks are resolved without replacing the links.

The installed-tool manifest contains one validated filename per line and is never executed. It controls updates and uninstallation. Manager-only installation and upgrade do not write this manifest. Without a manifest, only exact known tool registrations inside the entry's managed block are recognized; a same-named file alone does not establish ownership. Keep the manifest with installed files.

`list` also includes registered tools absent from the local catalog, and reports missing files. An unnamed `update` preserves and skips tools absent from the latest package; explicitly updating one is an error. A registered tool can still be uninstalled after it is removed from the catalog.

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

Every changed or removed existing file, including manager files and the tool manifest, is backed up beside the original:

```text
<file>.bak.YYYYMMDD-HHMMSS.<random-suffix>
```

Backup paths are printed. Identical files are not rewritten and create no backup. Prepared content is syntax-checked, all changed targets are checked for writability, and each replacement uses a temporary file in the target directory.

Operations are not transactions across multiple files. A later write or removal can fail after earlier changes succeeded. Fix the reported failure and repeat the command, or restore the corresponding backups of the manager, tools, manifest, entry, and main configuration together. Keep their registrations consistent, then start a new Zsh session. Re-run the GitHub installation command to repair a missing or damaged manager.

Only one operation can hold `<tools directory>/.mac-shell-tools-install.lock`. Remove a stale lock manually only after confirming that no management operation is running. Failure cleanup removes only the operation's own lock and temporary files.
