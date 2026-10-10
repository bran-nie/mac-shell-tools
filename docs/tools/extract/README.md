# extract

[简体中文](README-cn.md) · [mac-shell-tools](../../../README.md)

Extract one ZIP or TAR archive on macOS or Linux into a dedicated new directory. Preview archive contents and complete archive paths or destination directories with Tab.

## Install

After [installing mst](../../../README.md#install-mst), run:

```sh
mst upgrade
mst install extract
```

Uses `tar` for TAR archives and `unzip` with ZipInfo support for ZIP archives. macOS includes both; Ubuntu can install them with `sudo apt install tar unzip`. Compressed TAR support also depends on the backend's gzip, bzip2, or xz support; on Ubuntu these are provided by `gzip`, `bzip2`, and `xz-utils`. No additional runtime or network connection is needed to use the tool.

## Usage

```zsh
extract app.tar.gz                 # Creates ./app/
extract ~/Downloads/app.zip        # Creates ./app/ in the current directory
extract app.zip -C ./unpacked      # Creates exactly ./unpacked/
extract --list app.zip             # Preview; creates no output directory
extract "archive with spaces.tgz"
extract -- ./-archive.zip
```

Supported extensions, case-insensitively: `.zip`, `.tar`, `.tar.gz`, `.tgz`, `.tar.bz2`, `.tbz2`, `.tar.xz`, and `.txz`. Standalone `.gz`, RAR, 7z, and encrypted ZIP files are not supported.

| Argument | Behavior |
| --- | --- |
| `archive` | Exactly one readable archive |
| `-C DIR`, `--directory DIR`, `--directory=DIR` | Use this exact new destination; its parent must already exist |
| `-l`, `--list` | List entries without extracting; cannot be combined with `-C` |
| `-h`, `--help` | Show help |
| `-V`, `--version` | Show the version loaded in this shell |
| `--` | Stop parsing options |

Options and the archive may be interleaved; repeated destination options use the last value. By default, the archive's compound extension is removed to name a directory under the **current working directory**. An existing directory, file, or symlink at the destination causes the command to stop. It never merges output into an existing directory. The archive remains unchanged and the shell stays in its original directory.

Tab completes supported archive filenames, options, and directories after `-C` or `--directory=`. Completing an existing directory lets you choose a parent path; append a new child name for the destination. Completion never opens or extracts the archive.

## Extraction behavior

The tool accepts ordinary files and directories, and rejects symbolic links, hard links, and special entries. ZIP entries without Unix file-type metadata are treated as ordinary files by unzip. Archive listings are checked for absolute paths, parent-directory components, unsupported entry types, and encrypted ZIP entries before creating the destination. Native tar/unzip path protections remain enabled. `--list` is a read-only preview and can display entries that extraction would reject.

The tool copies the compressed archive into a private temporary directory so inspection and extraction use the same snapshot. Allow temporary space for this copy as well as space for the extracted output. Backend option environment variables are ignored within the tool; caller settings remain unchanged. TAR does not restore archived ownership or full permissions; the new destination is private to the current user.

If extraction fails or is interrupted after the destination is created, partial output stays there and its path is reported. Inspect or remove it before retrying, or choose another destination. Text-based backend listings cannot represent every unusual filename unambiguously; archives with ambiguous listings may be rejected.

## Language and versions

Help, status, errors, and completion descriptions default to English. Run `mst config language zh-CN` or `mst config language en` to save the shared preference; it applies on the next invocation. `MST_LANG=zh-CN extract --help` overrides it once. Archive filenames and backend diagnostics are not translated.

`extract --version` reports the loaded function's source release, revision, and state. `mst update extract` updates the source, version record, and language packs together. With automatic activation disabled, source the printed entry to load the new function.

## Exit codes

| Code | Meaning |
| --- | --- |
| `0` | Successful extraction, preview, help, or version |
| `2` | Invalid arguments or paths, existing destination, unsupported format, or rejected entries |
| `1` | Missing dependency, unreadable/corrupt archive, backend failure, or interruption |
