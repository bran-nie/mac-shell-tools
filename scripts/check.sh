#!/bin/sh
# Shared local/CI runner; Python is a test dependency, never a runtime dependency.
set -eu
project_dir=$(CDPATH= cd -P "$(dirname "$0")/.." && pwd)
exec python3 "$project_dir/scripts/ci/run.py" "$@"
