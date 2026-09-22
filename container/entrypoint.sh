#!/usr/bin/env bash
set -euo pipefail

# The container runs as the host numeric UID/GID. Use a writable throw-away
# home rather than depending on a matching passwd entry in the upstream image.
export HOME=/tmp/cva6-synthesis-home
mkdir -p "$HOME"
source /dockerstartup/scripts/generate_container_user.sh

exec python3 /opt/cva6-synthesis/flow/run.py "$@"
