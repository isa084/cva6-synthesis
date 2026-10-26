#!/usr/bin/env bash
# Adds one run directory to the log archive, a single folder for all runs:
#   <archive>/<name>.tar.gz  the text outputs of the run: metadata, results,
#                            configuration, logs, reports, gate-level simulation
#                            logs (no databases, netlists or builds)
#   <archive>/index.jsonl    one line per run, to find and compare runs
# <name> = <start, UTC>_cva6-<upstream commit>_flow-<flow version>_<target>_<tech>_<mode>
# The flow version is the cva6-synthesis commit (git describe), so a change of
# the flow scripts gives a new name, as a change of the CVA6 RTL does.
#
# Usage: archive.sh <run directory> <archive directory>
set -euo pipefail

run_dir=$(realpath -- "$1")
archive=$2
mkdir -p -- "$archive"
meta() { sed -n "s/^$1=//p" "${run_dir}/metadata.txt" | tail -n 1; }

start=$(date -u -d "$(meta start_time)" +%Y%m%dT%H%M%SZ)
name="${start}_cva6-$(meta upstream_sha | cut -c1-7)_flow-$(meta flow_version)_$(meta target)_$(meta technology)_$(meta mode)"

items=()
for item in metadata.txt results.json metrics.json gsim.log console.log config logs reports gsim; do
    [[ -e "${run_dir}/${item}" ]] && items+=("$item")
done
tar -czf "${archive}/${name}.tar.gz" -C "$run_dir" \
    --exclude='gsim/obj_*' --exclude='gsim/netlist.v' --exclude='gsim/cells.v' "${items[@]}"

results="${run_dir}/results.json"
line=$(jq -c -n --arg file "${name}.tar.gz" --arg runner "${RUNNER_NAME:-local}" \
    --rawfile meta "${run_dir}/metadata.txt" \
    --slurpfile res <(if [[ -s "$results" ]]; then cat "$results"; else echo '{}'; fi) '
    ($meta | split("\n") | map(select(test("=")) | capture("^(?<key>[^=]+)=(?<value>.*)$")) | from_entries) as $m
    | ($res[0] // {}) as $r
    | {file: $file, runner: $runner, start: $m.start_time, end: $m.end_time, exit_status: $m.exit_status,
       upstream_sha: $m.upstream_sha, upstream_date: $m.upstream_date, upstream_title: $m.upstream_title,
       repo_commit: $m.repo_commit, flow_commit: $m.cva6_synthesis_commit, flow_version: $m.flow_version,
       target: $m.target, config: $r.config, technology: $m.technology, mode: $m.mode,
       sram_mode: $r.sram_mode, status: $r.status, stdcell_area_um2: $r.stdcell_area_um2,
       total_area_um2: $r.total_area_um2, fmax_mhz: $r.fmax_mhz, worst_slack_ps: $r.worst_slack_ps,
       gsim_run: $r.gsim_run, gsim_passed: $r.gsim_passed, image: $m.tool_image, gsim_image: $m.gsim_image}')
(
    flock 9
    printf '%s\n' "$line" >>"${archive}/index.jsonl"
) 9>"${archive}/.index.lock"
printf 'Archived: %s\n' "${archive}/${name}.tar.gz"
