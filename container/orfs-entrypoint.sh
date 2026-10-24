#!/usr/bin/env bash
set -euo pipefail

# The container runs as the host numeric UID/GID; use a writable throw-away home.
export HOME=/tmp/cva6-synthesis-home
mkdir -p "$HOME"

set +u
source /OpenROAD-flow-scripts/env.sh
set -u

exec python3 /workspace/input/synthesis/flow/run.py "$@"
