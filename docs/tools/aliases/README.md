# aliases

[简体中文](README-cn.md)

Load common aliases and an explicitly selected personal Zsh file into the current shell. Defaults ship with the tool; personal files remain yours.

## Install and try

```sh
mst install aliases
aliases list
aliases show ll
ll
```

Installation requires only mst's Zsh and base commands, with no Node/npm dependency.

To try a checkout, run `source /path/to/checkout/tools/aliases/aliases.zsh` in Zsh. This does not install the tool or edit `.zshrc`.

## Built-in aliases

| Alias | Command | Purpose |
| --- | --- | --- |
| `ll` | `ls -alh` | List files, including hidden entries, in long format with human-readable sizes |
| `duls` | `du -h -d 1 -c` | Show directory disk usage to one level of subdirectories, with human-readable sizes and a grand total |

Existing aliases or functions with these names take priority; `aliases list` shows skipped defaults.

## Personal configuration

```sh
aliases config file ~/.zshrc_alias
aliases config show
aliases reload
```

`config file PATH` checks readability and Zsh syntax, then saves only the path. **Run `aliases reload` or open a new terminal to load it.** Relative paths, quoted `~/...`, spaces, Unicode and personal-file symlinks are supported. Line breaks in paths are rejected. Without a saved path, only defaults load; `~/.zshrc_alias` is never discovered automatically.

Use regular Zsh syntax in the personal file:

```zsh
alias ll='ls -al'
alias work='cd "$HOME/work"'

function mkcd {
  mkdir -p -- "$1" && cd -- "$1"
}
```

The file is sourced in the current shell and can execute commands. Select only files you trust. Regular aliases and function definitions are tracked; variables, directories, global/suffix aliases, hooks and other script effects are outside rollback. Keep functions' actions inside their bodies so they run on invocation.

If `.zshrc` already sources the same file, remove that old source line when migrating and open a new shell so the file loads only through aliases. Identical definitions that predate the first load are not claimed, protecting existing configuration from later removal. The tool does not rewrite personal `.zshrc` content.

Defaults are available on a new computer after `mst install aliases`. Transfer personal files through your own private dotfiles repository or another mechanism, then select their local path. This tool does not upload or synchronize files.

## Commands and ownership

| Command | Behavior |
| --- | --- |
| `aliases`, `aliases --help` | Show help |
| `aliases list` | Show tracked aliases/functions, sources, live state and current definitions |
| `aliases show NAME` | Show the full definition, including multiline function bodies |
| `aliases reload` | Reload personal configuration and defaults into this shell |
| `aliases config file` | Print the saved personal path; empty when unset |
| `aliases config file PATH` | Save a path for the next reload or new shell |
| `aliases config file --reset` | Clear the path for the next load; retain the personal file |
| `aliases config show` | Show config location, saved/loaded paths and last load exit code |
| `aliases --version` | Show the loaded tool version |

Sources are `builtin` and `personal`; types are `alias` and `function`. Inspection and completion use current shell state and never execute the personal file. States are `active`, `skipped`, `overridden`, `removed`, and `shadowed` (a function hidden by an alias).

Personal definitions take priority over defaults. Reload removes stale owned definitions and restores definitions that were overridden. Cleanup happens only while the current value matches what the tool loaded. Names manually changed or removed afterward remain untouched on subsequent reloads in that session; a fresh shell uses configuration again.

Unreadable files or syntax errors leave existing definitions intact. A nonzero source status restores aliases/functions from before loading. Other effects of arbitrary personal Zsh code cannot be rolled back. Startup is quiet; use `aliases list` or `aliases config show` to inspect failure state, then `aliases reload` for diagnostics. Explicit reload also displays the personal file's output.

## Settings and updates

The setting is one data-only line, `file=/absolute/path`, stored in `aliases.conf` beside the installed shared `init.zsh`. Its location stays pinned if `XDG_CONFIG_HOME` changes later. Source-checkout loads use `${XDG_CONFIG_HOME:-$HOME/.config}/zsh/mac-shell-tools/aliases.conf`. The setting file is never executed and refuses symlinks/non-files; the selected personal Zsh file may be a symlink for dotfiles workflows.

`mst update aliases` replaces the implementation/defaults while retaining personal files and settings. `mst uninstall aliases` retains them too; open a new shell or run `exec zsh -l` afterward to clear definitions held by the old session. Offline reinstall reuses the saved setting.

Help, states, errors and completion descriptions follow mst's language preference, with `MST_LANG` overrides. Names and command text stay unchanged. Tab completes commands, tracked names, file paths, reset, help and version options.

Exit codes: `0` success; `2` invalid arguments/configuration/syntax; `1` source or write failure. `list` returns `1` after a failed last load and suggests reloading; `config show` remains available for diagnosis.
