#!/usr/bin/env bash
# Start (or replace) the runner containers for one repository.
# Usage: REPO=owner/name [RUNNERS=3] runner/start.sh
# Optional: DENYLIST=<file> (default ~/.config/cva6-synthesis/denylist)
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
: "${REPO:?set REPO to owner/name}"

DENYLIST=${DENYLIST:-${XDG_CONFIG_HOME:-$HOME/.config}/cva6-synthesis/denylist}
[[ -f $DENYLIST ]] || { echo "start.sh: deny-list file not found" >&2; exit 1; }

# Host-specific values are resolved here, at start time, and never committed.
# The runner containers only check out code; the tool containers get the core
# budget (CVA6_SYNTH_CPUS, set by the workflow).
RUNNERS=${RUNNERS:-3}
RUNNER_CPUS=2
RUNNER_TOKEN=$(gh api -X POST "repos/$REPO/actions/runners/registration-token" --jq .token)
export REPO DENYLIST RUNNER_CPUS RUNNER_TOKEN

for i in $(seq 1 "$RUNNERS"); do
    RUNNER_NAME=cva6-synth-runner-$i docker compose -p "cva6-runner-$i" up -d
done
