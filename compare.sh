#!/usr/bin/env bash
set -euo pipefail

fail() {
    printf 'cva6-synthesis: %s\n' "$*" >&2
    exit 2
}

usage() {
    cat <<'USAGE'
Usage:
  ./synthesis/compare.sh [--mode quick|full] [--timing-match REGEX] \
      REFERENCE_TARGET CANDIDATE_TARGET

The reported delta is CANDIDATE_TARGET - REFERENCE_TARGET.
USAGE
}

synth_dir=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
runs_dir="${SYNTH_OUTPUT_ROOT:-${synth_dir}/runs}"
mode=full
timing_match=
targets=()

while (($# > 0)); do
    case "$1" in
        --mode)
            (($# >= 2)) || fail "--mode requires a value"
            mode=$2
            shift 2
            ;;
        --timing-match)
            (($# >= 2)) || fail "--timing-match requires a regular expression"
            timing_match=$2
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            fail "unknown argument '$1'"
            ;;
        *)
            targets+=("$1")
            shift
            ;;
    esac
done

[[ "$mode" == quick || "$mode" == full ]] || fail "--mode must be 'quick' or 'full'"
((${#targets[@]} == 2)) || fail "reference and candidate target names are required"
[[ "$mode" == full || -z "$timing_match" ]] || \
    fail "--timing-match is available only in full mode"
if [[ -n "$timing_match" ]]; then
    regex_status=0
    grep -Eq -- "$timing_match" /dev/null 2>/dev/null || regex_status=$?
    ((regex_status < 2)) || fail "invalid --timing-match regular expression"
fi
reference_target=${targets[0]}
candidate_target=${targets[1]}
for target in "$reference_target" "$candidate_target"; do
    [[ "$target" =~ ^[A-Za-z0-9_.-]+$ ]] || \
        fail "target name contains unsupported characters: ${target}"
done

latest_success() {
    local target=$1
    local link="${runs_dir}/${target}/${mode}/latest-success"
    [[ -e "$link" ]] || fail "no successful '${target}' run found at ${link}"
    realpath -- "$link"
}

extract_area() {
    awk '/Chip area for module/ { print $NF; found = 1; exit }
         END { if (!found) exit 1 }' "$1"
}

extract_cells() {
    awk '$NF == "cells" { print $1; found = 1; exit }
         END { if (!found) exit 1 }' "$1"
}

extract_slack() {
    awk '/slack \((VIOLATED|MET)\)/ { print $1; found = 1; exit }
         END { if (!found) exit 1 }' "$1"
}

extract_loop_warnings() {
    grep -c '^Warning: Detected loop' "$1" || true
}

metadata_value() {
    local file=$1
    local key=$2
    awk -F= -v key="$key" '$1 == key {
        sub(/^[^=]*=/, "")
        print
        found = 1
        exit
    }
    END { if (!found) exit 1 }' "$file"
}

require_same_metadata() {
    local key=$1
    local label=$2
    local reference_value candidate_value
    reference_value=$(metadata_value "${reference_dir}/metadata.txt" "$key") || \
        fail "reference metadata does not contain ${key}; rerun the target"
    candidate_value=$(metadata_value "${candidate_dir}/metadata.txt" "$key") || \
        fail "candidate metadata does not contain ${key}; rerun the target"
    [[ "$reference_value" == "$candidate_value" ]] || \
        fail "${label} differs between runs (${reference_value} != ${candidate_value})"
}

require_metadata_value() {
    local run_dir=$1
    local key=$2
    local expected=$3
    local label=$4
    local actual
    actual=$(metadata_value "${run_dir}/metadata.txt" "$key") || \
        fail "${label} metadata does not contain ${key}; rerun the target"
    [[ "$actual" == "$expected" ]] || \
        fail "${label} metadata has ${key}=${actual}, expected ${expected}"
}

print_row() {
    local label=$1
    local reference=$2
    local candidate=$3
    local delta percent
    read -r delta percent < <(
        awk -v reference="$reference" -v candidate="$candidate" 'BEGIN {
            delta = candidate - reference
            if (reference == 0) {
                printf "%.3f n/a\n", delta
            } else {
                printf "%.3f %+.2f%%\n", delta, 100.0 * delta / reference
            }
        }'
    )
    printf '%-20s %16s %16s %16s %12s\n' \
        "$label" "$reference" "$candidate" "$delta" "$percent"
}

reference_dir=$(latest_success "$reference_target")
candidate_dir=$(latest_success "$candidate_target")

for report in \
    "${reference_dir}/metadata.txt" \
    "${reference_dir}/stat.rpt" \
    "${reference_dir}/ltp.rpt" \
    "${candidate_dir}/metadata.txt" \
    "${candidate_dir}/stat.rpt" \
    "${candidate_dir}/ltp.rpt"; do
    [[ -r "$report" ]] || fail "missing readable report: ${report}"
done

if [[ "$mode" == full ]]; then
    for report in \
        "${reference_dir}/timing-top10.rpt" \
        "${candidate_dir}/timing-top10.rpt"; do
        [[ -r "$report" ]] || fail "missing readable report: ${report}"
    done
fi

require_same_metadata repo_commit "CVA6 commit"
require_same_metadata synthesis_config_sha256 "synthesis configuration"
require_same_metadata cva6_synthesis_commit "cva6-synthesis commit"
require_same_metadata mode "synthesis mode"
require_metadata_value "$reference_dir" target "$reference_target" reference
require_metadata_value "$candidate_dir" target "$candidate_target" candidate
require_metadata_value "$reference_dir" mode "$mode" reference
require_metadata_value "$candidate_dir" mode "$mode" candidate
require_metadata_value "$reference_dir" exit_status 0 reference
require_metadata_value "$candidate_dir" exit_status 0 candidate

reference_cells=$(extract_cells "${reference_dir}/stat.rpt") || fail "could not read reference cell count"
candidate_cells=$(extract_cells "${candidate_dir}/stat.rpt") || fail "could not read candidate cell count"
reference_loops=$(extract_loop_warnings "${reference_dir}/ltp.rpt")
candidate_loops=$(extract_loop_warnings "${candidate_dir}/ltp.rpt")

printf 'Mode: %s\n' "$mode"
printf 'Reference reports: %s\n' "$reference_dir"
printf 'Candidate reports: %s\n\n' "$candidate_dir"
printf '%-20s %16s %16s %16s %12s\n' \
    'Metric' "$reference_target" "$candidate_target" 'Delta' 'Delta %'
printf '%-20s %16s %16s %16s %12s\n' \
    '--------------------' '----------------' '----------------' '----------------' '------------'
print_row 'Total Yosys cells' "$reference_cells" "$candidate_cells"
print_row 'Loop warnings' "$reference_loops" "$candidate_loops"

if [[ "$mode" == full ]]; then
    reference_area=$(extract_area "${reference_dir}/stat.rpt") || fail "could not read reference area"
    candidate_area=$(extract_area "${candidate_dir}/stat.rpt") || fail "could not read candidate area"
    reference_slack=$(extract_slack "${reference_dir}/timing-top10.rpt") || fail "could not read reference slack"
    candidate_slack=$(extract_slack "${candidate_dir}/timing-top10.rpt") || fail "could not read candidate slack"
    print_row 'Cell area' "$reference_area" "$candidate_area"

    slack_delta=$(awk -v reference="$reference_slack" -v candidate="$candidate_slack" \
        'BEGIN { printf "%.3f", candidate - reference }')
    printf '%-20s %16s %16s %16s %12s\n' \
        'Worst slack (ns)' "$reference_slack" "$candidate_slack" "$slack_delta" 'n/a'

    printf '\nReference critical paths: %s\n' "${reference_dir}/timing-top10.rpt"
    printf 'Candidate critical paths: %s\n' "${candidate_dir}/timing-top10.rpt"
    if [[ -n "$timing_match" ]]; then
        if grep -Eiq -- "$timing_match" "${candidate_dir}/timing-top10.rpt"; then
            printf '\nCandidate paths matching /%s/:\n' "$timing_match"
            grep -Ein -- "$timing_match" "${candidate_dir}/timing-top10.rpt"
        else
            printf '\nNo candidate top-ten path matches /%s/.\n' "$timing_match"
        fi
    fi
else
    printf '\nQuick mode omits ABC, technology area, and OpenSTA timing.\n'
    printf 'Structural paths: %s and %s\n' \
        "${reference_dir}/ltp.rpt" "${candidate_dir}/ltp.rpt"
fi

if ((reference_loops > 0 || candidate_loops > 0)); then
    printf '\nWARNING: inspect LTP loop warnings before trusting the longest paths.\n'
fi
