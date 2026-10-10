# mst_text_en message catalog.
mst_text_en() {
  case $1 in
    help) printf '%s\n' 'Usage: extract [options] archive

Extract one ZIP or TAR archive into a new directory in the current directory.
The default directory is the archive filename without its archive extension.
Supported: .zip .tar .tar.gz .tgz .tar.bz2 .tbz2 .tar.xz .txz (case-insensitive).

  -C DIR, --directory DIR, --directory=DIR  Exact new destination directory
  -l, --list                               List archive contents without extracting
  -V, --version                            Show the loaded tool version
  -h, --help                               Show help
  --                                       Stop parsing options

Examples: extract app.tar.gz; extract app.zip -C ./unpacked; extract --list app.zip
An existing destination is never used; its parent must already exist.
Only ordinary files and directories are accepted; links and special entries are rejected.
Absolute paths and parent-directory components are rejected before extraction.
An archive snapshot uses temporary space; failed extraction keeps partial output.
Encrypted ZIP files are unsupported. Backend diagnostics retain their own language.
Exit codes: 0 success/list/help, 2 invalid input or rejected entries, 1 command failure.' ;;
    success) printf '%s\n' 'Extracted to: %s' ;;
    error.option) printf '%s\n' 'Unknown option: %s' ;;
    error.value) printf '%s\n' '%s requires a nonempty directory.' ;;
    error.archive_count) printf '%s\n' 'Specify exactly one archive.' ;;
    error.list_directory) printf '%s\n' '--list cannot be combined with --directory.' ;;
    error.archive) printf '%s\n' 'Not a readable archive file: %s' ;;
    error.format) printf '%s\n' 'Unsupported archive extension: %s' ;;
    error.exists) printf '%s\n' 'Destination already exists; choose a new directory: %s' ;;
    error.parent) printf '%s\n' 'Destination parent directory does not exist: %s' ;;
    error.dependency) printf '%s\n' 'Required command is missing: %s' ;;
    error.temporary) printf '%s\n' 'Could not create a temporary directory.' ;;
    error.read) printf '%s\n' 'Could not read the archive completely; nothing was extracted.' ;;
    error.path) printf '%s\n' 'Unsupported or unsafe archive path: %s' ;;
    error.type) printf '%s\n' 'Only ordinary files and directories are supported; links, special entries, or ambiguous listings were found.' ;;
    error.encrypted) printf '%s\n' 'Encrypted ZIP entries are unsupported; nothing was extracted.' ;;
    error.create) printf '%s\n' 'Could not create a new destination: %s' ;;
    error.partial) printf '%s\n' 'Extraction failed; partial output was kept at: %s' ;;
    error.interrupted) printf '%s\n' 'Extraction interrupted.' ;;
    completion.help) printf '%s\n' 'Show help' ;;
    completion.version) printf '%s\n' 'Show version' ;;
    completion.list) printf '%s\n' 'List archive contents' ;;
    completion.directory) printf '%s\n' 'New destination directory' ;;
    label.archive) printf '%s\n' 'archive' ;;
    label.directory) printf '%s\n' 'directory' ;;
    *) return 1 ;;
  esac
}
