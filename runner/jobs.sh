#!/usr/bin/env bash
# Show the recent track runs, the flow jobs of the active (or latest) run, and the log archive.
# Usage: REPO=owner/name [ARCHIVE=dir] runner/jobs.sh
# Optional: ARCHIVE (default /srv/cva6-runner/archive)
set -euo pipefail

: "${REPO:?set REPO to owner/name}"
ARCHIVE=${ARCHIVE:-/srv/cva6-runner/archive}

echo "Recent runs"
gh run list -R "$REPO" --workflow track.yml --limit 5
active=$(gh run list -R "$REPO" --workflow track.yml --status in_progress --limit 1 --json databaseId --jq '.[0].databaseId // empty')
id=${active:-$(gh run list -R "$REPO" --workflow track.yml --limit 1 --json databaseId --jq '.[0].databaseId // empty')}

if [[ -n $id ]]; then
    echo; echo "Flow jobs of run $id"
    gh run view "$id" -R "$REPO" --json jobs --jq '.jobs[] | select(.name | startswith("flow ")) | [(.conclusion | select(. != "") // .status), (.name | ltrimstr("flow ")), .startedAt] | @tsv'
fi

if [[ -f $ARCHIVE/index.jsonl ]]; then
    echo; echo "Archive: $(wc -l < "$ARCHIVE/index.jsonl") runs"
    tail -n 3 "$ARCHIVE/index.jsonl" | jq -r .file
fi
