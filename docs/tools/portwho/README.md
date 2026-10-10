# portwho

[简体中文](README-cn.md) · [mac-shell-tools](../../../README.md)

Find programs listening on TCP ports on macOS or Linux, using `lsof`. Show the program, PID, user, and listen address. Multiple ports are supported; with no arguments, show all visible TCP listeners.

## Install

After [installing mst](../../../README.md#install-mst), run:

```sh
mst upgrade
mst install portwho
```

Requires `lsof` (included with macOS; on Ubuntu, install it with `sudo apt install lsof` if missing). Running portwho does not require a network connection.

## Usage

```zsh
portwho 3000
portwho 80 443
portwho
portwho --help
portwho --version
```

| Argument | Behavior |
| --- | --- |
| `port ...` | One or more decimal TCP ports, 1–65535 |
| No ports | List all visible TCP listeners |
| `-h`, `--help` | Show help |
| `-V`, `--version` | Show the version loaded in this shell |
| `--` | Stop parsing options |

Leading zeros are decimal; duplicate ports are queried once. Ranges, service names, and comma-separated ports are not accepted. Tab completes options and common port numbers without running lsof.

Output keeps native `lsof` columns, including `COMMAND`, `PID`, `USER`, and `NAME`. Names and port numbers are not resolved over the network. Only TCP sockets in `LISTEN` state are selected; UDP and established client connections are excluded. Program names identify the process reported by the OS, such as `node` or `python`, rather than its full launch arguments.

Results are limited by the current user's permissions. An empty result says **no visible listener matched**; it does not prove that the port is available. The tool never invokes sudo or stops processes. Backend warnings and failures return an error and preserve any partial output.

## Language and versions

Help, status, errors, and completion descriptions default to English. `mst config language zh-CN` or `mst config language en` changes the shared preference on the next call. `MST_LANG=zh-CN portwho --help` overrides it once. Native lsof data, column names, and backend diagnostics retain their original format and language.

`portwho --version` reports the loaded function's source release, revision, and state. `mst update portwho` updates its source, version record, and language packs together. With automatic activation disabled, source the printed entry to load the updated function.

## Exit codes

| Code | Meaning |
| --- | --- |
| `0` | Results, no visible match, help, or version |
| `2` | Invalid arguments or language configuration |
| `1` | Missing dependency, query failure, warning, or interruption |
