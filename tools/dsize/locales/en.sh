# mst_text_en message catalog.
mst_text_en() {
  case $1 in
    help) printf '%s\n' 'Usage: dsize [directory] [options]

Show the largest directory disk-usage totals as a tree, with parents first.
Siblings are ordered largest first. Defaults: directory ., depth 2, up to 25 lines.

  -d N, --depth N, --depth=N  Display depth, decimal integer 0–1000
  -n N, --lines N, --lines=N  Maximum lines, decimal integer 1–1000000
  --flat                     Use the original flat ranking, largest entry last
  -V, --version              Show the loaded tool'\''s version
  -h, --help                 Show help
  --                         Stop options; at most one directory may follow

Directory and options may be interleaved; the last repeated option wins.
Leading zeros are decimal. Depth limits display, not traversal.
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
    error.interrupted) printf '%s\n' 'Scan interrupted; results may be incomplete.' ;;
    error.partial) printf '%s\n' 'Incomplete scan; some directories could not be read or du failed.' ;;
    error.pipeline) printf '%s\n' 'Sorting, truncating, or formatting output failed.' ;;
    label.depth) printf '%s\n' 'depth' ;;
    label.lines) printf '%s\n' 'line count' ;;
    completion.depth) printf '%s\n' 'Display depth, default 2' ;;
    completion.lines) printf '%s\n' 'Maximum lines, default 25' ;;
    completion.flat) printf '%s\n' 'Flat size ranking, largest entry last' ;;
    completion.help) printf '%s\n' 'Show help' ;;
    completion.version) printf '%s\n' 'Show version' ;;
    completion.directory) printf '%s\n' 'directory' ;;
    *) return 1 ;;
  esac
}
