#!/usr/bin/env bash
set -euo pipefail

# The container runs as the host numeric UID/GID. Use a writable throw-away
# home rather than depending on a matching passwd entry in the upstream image.
export HOME=/tmp/cva6-synthesis-home
mkdir -p "$HOME"

# The upstream helper is designed to be sourced without nounset enabled.
set +u
source /dockerstartup/scripts/generate_container_user.sh
set -u

if [[ "${1:-}" == "--self-check" ]]; then
    command -v yosys >/dev/null
    command -v sta >/dev/null
    command -v openroad >/dev/null
    python3 -c 'import yaml'
    test -r /opt/OpenROAD-flow-scripts/flow/platforms/nangate45/lib/NangateOpenCellLibrary_typical.lib
    yosys -p 'plugin -i slang; help read_slang' >/dev/null
    printf 'cva6-synthesis: image self-check passed\n'
    exit 0
fi

exec python3 /opt/cva6-synthesis/flow/run.py "$@"
