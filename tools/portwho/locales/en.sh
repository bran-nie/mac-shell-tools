# mst_text_en message catalog.
mst_text_en() {
  case $1 in
    help) printf '%s\n' 'Usage: portwho [port ...] [options]

Show visible TCP listeners with lsof: program, PID, user, and listen address.
With no ports, list all visible TCP listeners. UDP is not included.

  port              One or more decimal ports, 1–65535
  -V, --version     Show the loaded tool version
  -h, --help        Show help
  --                Stop parsing options

Examples: portwho 3000; portwho 80 443; portwho
Leading zeros are decimal; duplicate ports are queried once.
Results are limited by current permissions; no result does not prove a port free.
Output uses native lsof columns. No processes are stopped; sudo is never run.
Exit codes: 0 results/no visible match/help, 2 invalid input, 1 query failure.' ;;
    empty) printf '%s\n' 'No visible TCP listeners matched. Results are limited by current permissions; this does not prove the ports are free.' ;;
    error.option) printf '%s\n' 'Unknown option: %s' ;;
    error.port) printf '%s\n' 'Invalid port: %s (use a decimal integer from 1 to 65535).' ;;
    error.dependency) printf '%s\n' 'Required command is missing: %s' ;;
    error.temporary) printf '%s\n' 'Could not create a temporary directory.' ;;
    error.query) printf '%s\n' 'lsof failed or reported incomplete results.' ;;
    error.interrupted) printf '%s\n' 'Query interrupted; results may be incomplete.' ;;
    completion.help) printf '%s\n' 'Show help' ;;
    completion.version) printf '%s\n' 'Show version' ;;
    completion.port) printf '%s\n' 'TCP port' ;;
    *) return 1 ;;
  esac
}
