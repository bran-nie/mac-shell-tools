# dsize

[简体中文](README-cn.md) · [mac-shell-tools](../../../README.md)

Show disk usage for a chosen directory using the standard macOS `du`, `sort`, and `tail` commands. Keep up to 25 largest results by default, with directory Tab completion.

## Install

After [installing mst](../../../README.md#install-mst), run:

```sh
mst install dsize
```

## Usage

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
| `-V`, `--version` | | Show the version loaded in this shell |
| `--` | | Stop parsing options; at most one directory may follow |

Options and the directory may appear in either order. Repeated options use the last value. Leading zeros are decimal. Quote paths with spaces normally; input strings are never evaluated with `eval`.

Output keeps the ordinary `du` format: readable units, ascending size, and the largest N lines. **The largest entry appears last.** Results are directory totals, including the target directory itself. File usage contributes to its containing directory; individual files are not listed. No headers, colors, or percentages are added.

## Tab completion

`dsize <Tab>` completes directories, including paths with spaces. Short and long options, help flags, depth suggestions (`0 1 2 3 4 5`), and line-count suggestions (`10 25 50 100`) are supported, including `--depth=` and `--lines=`. Suggestions do not restrict accepted values. Completion never starts a disk scan.

Load the toolkit after Oh My Zsh or `compinit`. It registers with `compdef` when available and never runs `compinit` itself. The command also works without completion.

## Language and version

Help, errors, and completion descriptions default to English. Run `mst config language zh-CN` or `mst config language en` to save the shared preference; it applies on the next call without reloading. `MST_LANG=zh-CN dsize --help` overrides it once. Missing translations fall back to English; disk-usage data and exit codes remain the same.

`dsize --version` reports the loaded function's source release, revision, and state. After `mst update dsize --no-run-zsh`, source the printed loader to use the new function. Source files, version records, and language packs live together in `~/.config/zsh/mac-shell-tools/tools/dsize/` and update together.

## Exit codes

| Code | Meaning |
| --- | --- |
| `0` | Success or help |
| `2` | Invalid arguments or paths |
| `1` | Incomplete scan, interruption, or command failure |

When `du` fails, available results can still be printed, with a brief diagnostic on stderr. Repeated permission errors are suppressed.

## Interpreting sizes

`dsize` reports **disk usage**, which can differ from logical file sizes, Finder totals, macOS “System Data,” or space released after deletion. Hard links and APFS behavior can affect the numbers. Parent totals include children, so output lines cannot be added together.

Depth controls displayed levels, not traversal: calculating totals can still read deeper directories. Lower depth does not guarantee a faster scan. Restricted directories can produce incomplete results.

Output retains `du`'s text format, so filenames containing tabs or newlines are not unambiguous records. The tool measures disk usage and does not delete or clean files.
