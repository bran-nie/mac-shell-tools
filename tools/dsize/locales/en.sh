# mst_text_en message catalog.
mst_text_en() {
  case $1 in
    help) printf '%s\n' 'Usage: dsize [directory] [options]

Show the largest directory disk-usage totals as a tree, with parents first.
Siblings are ordered largest first. Defaults: directory ., depth 2, up to 25 lines.

  -d N, --depth N, --depth=N  Display depth, decimal integer 0–1000
  -n N, --lines N, --lines=N  Maximum lines, decimal integer 1–1000000
  -e PATTERN, --exclude PATTERN, --exclude=PATTERN
                             Skip matching names at any level; repeatable
  -i PATTERN, --include PATTERN, --include=PATTERN
                             Select first-level subdirectory names; repeatable
  --flat                     Use the original flat ranking, largest entry last
  -V, --version              Show the loaded tool'\''s version
  -h, --help                 Show help
  --                         Stop options; at most one directory may follow

Directory and options may be interleaved.
For depth and line limits, the last repeated option wins. Filter rules accumulate.
Leading zeros are decimal. Depth limits display, not traversal.
Exclusions skip files/directories and remove their usage from parent totals.
Use names or quoted globs such as "cache*", without /. Exclude can match the root.
Include selects only first-level real subdirectories and counts their subtrees.
With include, the root sums selected subtrees; root files are not included.
Exclude takes priority. No matches produce no output. Depth is relative to the root.
The line limit includes the root and parents; tree sizes use readable units.
Results are directory totals; file usage is included in its containing directory.
Parent totals include children and cannot be added together. No files are deleted.
Exit codes: 0 success/help, 2 invalid input, 1 incomplete scan or command failure.' ;;
    error.integer) printf '%s\n' '%s must be a decimal integer (%s–%s).' ;;
    error.range) printf '%s\n' '%s must be in the range %s–%s.' ;;
    error.value) printf '%s\n' '%s requires a value.' ;;
    error.directory_count) printf '%s\n' 'Only one directory is allowed.' ;;
    error.option) printf '%s\n' 'Unknown option: %s' ;;
    error.missing) printf '%s\n' 'Path does not exist: %s' ;;
    error.directory) printf '%s\n' 'Not a directory: %s' ;;
    error.dependency) printf '%s\n' 'Required command is missing: %s' ;;
    error.exclude_empty) printf '%s\n' 'Exclude patterns must not be empty.' ;;
    error.exclude_path) printf '%s\n' 'Exclude patterns match names, not paths; remove / from: %s' ;;
    error.exclude_backend) printf '%s\n' 'Exclusions require macOS du or GNU coreutils du.' ;;
    error.include_empty) printf '%s\n' 'Include patterns must not be empty.' ;;
    error.include_path) printf '%s\n' 'Include patterns match first-level directory names, not paths: %s' ;;
    error.pattern) printf '%s\n' 'Invalid name pattern: %s' ;;
    error.interrupted) printf '%s\n' 'Scan interrupted; results may be incomplete.' ;;
    error.partial) printf '%s\n' 'Incomplete scan; some directories could not be read or du failed.' ;;
    error.pipeline) printf '%s\n' 'Sorting, truncating, or formatting output failed.' ;;
    label.depth) printf '%s\n' 'depth' ;;
    label.lines) printf '%s\n' 'line count' ;;
    label.exclude) printf '%s\n' 'name pattern' ;;
    label.include) printf '%s\n' 'directory name pattern' ;;
    completion.depth) printf '%s\n' 'Display depth, default 2' ;;
    completion.lines) printf '%s\n' 'Maximum lines, default 25' ;;
    completion.flat) printf '%s\n' 'Flat size ranking, largest entry last' ;;
    completion.exclude) printf '%s\n' 'Skip matching names and their disk usage; repeatable' ;;
    completion.include) printf '%s\n' 'Select first-level subdirectories and their usage; repeatable' ;;
    completion.help) printf '%s\n' 'Show help' ;;
    completion.version) printf '%s\n' 'Show version' ;;
    completion.directory) printf '%s\n' 'directory' ;;
    *) return 1 ;;
  esac
}
