#!/usr/bin/env bash
# Start (or replace) the runner container for one repository.
# Usage: REPO=owner/name runner/start.sh
# Optional: DENYLIST=<file> (default ~/.config/cva6-synthesis/denylist)
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
: "${REPO:?set REPO to owner/name}"

DENYLIST=${DENYLIST:-${XDG_CONFIG_HOME:-$HOME/.config}/cva6-synthesis/denylist}
[[ -f $DENYLIST ]] || { echo "start.sh: deny-list file not found" >&2; exit 1; }

# Host-specific values are resolved here, at start time, and never committed.
RUNNER_CPUS=$(( $(docker info --format '{{.NCPU}}') / 2 ))
RUNNER_TOKEN=$(gh api -X POST "repos/$REPO/actions/runners/registration-token" --jq .token)
export REPO DENYLIST RUNNER_CPUS RUNNER_TOKEN

docker compose up -d
