# dsize

[简体中文](README-cn.md) · [mac-shell-tools](../../../README.md)

Show a disk-usage tree for a chosen directory on macOS or Linux, with up to 25 lines by default and directory Tab completion. Uses system `du`, `sort`, and POSIX `awk`; installing `tree` is unnecessary. Linux requires GNU Coreutils or compatible commands supporting `du -k -d` and `sort -k`. The `--flat` format also needs `du -h -d`, `sort -h`, and `tail -n`.

## Install

After [installing mst](../../../README.md#install-mst), run:

```sh
mst install dsize
```

## Usage

```zsh
dsize
dsize ~/.config
dsize ~/.config/zsh -n 50
dsize ~/.config -d 3 -n 50
dsize -n 50 ~/.config
dsize ~/.config --depth=3 --lines=30
dsize "$HOME/path with spaces" -n 30
dsize -- ./-example
dsize --flat                 # Original flat ranking
```

| Argument | Default | Accepted values |
| --- | --- | --- |
| Directory | `.` | One existing directory |
| `-d N`, `--depth N`, `--depth=N` | `2` | Decimal integer, 0–1000 |
| `-n N`, `--lines N`, `--lines=N` | `25` | Decimal integer, 1–1000000 |
| `--flat` | | Use the original flat size ranking |
| `-h`, `--help` | | Show help |
| `-V`, `--version` | | Show the version loaded in this shell |
| `--` | | Stop parsing options; at most one directory may follow |

Options and the directory may appear in either order. Repeated options use the last value. Leading zeros are decimal. Quote paths with spaces normally; input strings are never evaluated with `eval`.

The default output starts with the target directory total, then uses `├──` and `└──` to show parent-child relationships. Children show only their own names, and siblings are ordered largest first. For example:

```text
  1.9G  .
  905M  ├── node_modules
  900M  │   └── .pnpm
  681M  └── .next
  465M      ├── dev
  131M      └── cache
```

The `-n` limit includes the root and all displayed parents. It selects the N largest directories within the scan depth; ties use bytewise path order, with parents first. This keeps the selected tree connected, and `-n 1` shows only the target total. Sizes are sorted using raw KiB values before conversion to readable units, so displayed sizes can be equal after rounding. Unselected directories are omitted without extra placeholder lines.

`--flat` keeps the original ordinary `du` format: readable units, ascending size, and the largest N lines. **The largest entry appears last.**

Both formats show directory totals, including the target directory itself. File usage contributes to its containing directory; individual files are not listed. No headers, colors, or percentages are added.

## Tab completion

`dsize <Tab>` completes directories, including paths with spaces. Short and long options, `--flat`, help flags, depth suggestions (`0 1 2 3 4 5`), and line-count suggestions (`10 25 50 100`) are supported, including `--depth=` and `--lines=`. Suggestions do not restrict accepted values. Completion never starts a disk scan.

The shared loader reuses completion initialized by Oh My Zsh or your own configuration. In interactive Zsh without `compdef`, it initializes completion before loading tools. Loading the dsize source file alone does not run `compinit`; the command also works without completion.

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

`dsize` reports **disk usage**, which can differ from logical file sizes, file-manager totals, or space released after deletion. Hard links, sparse files, and filesystem features such as APFS cloning can affect the numbers. Results can differ across filesystems and operating systems. Parent totals include children, so output lines cannot be added together.

Depth controls displayed levels, not traversal: calculating totals can still read deeper directories. Lower depth does not guarantee a faster scan. Restricted directories can produce incomplete results.

Scanning uses `du`'s text records, so filenames containing tabs or newlines are not unambiguous. The tool measures disk usage and does not delete or clean files.
