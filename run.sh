#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'USAGE'
Usage:
  ./synthesis/run.sh --target TARGET [--mode MODE] [--tech TECH] [--build]

Options:
  --target TARGET  Target key from repo_home/synthesis.yaml
  --mode MODE      Yosys profile: quick (no ABC/STA) or full (ABC + STA; default: full)
                   orfs profile: fast or opt (default: fast)
  --tech TECH      orfs profile: asap7 or nangate45 (default: synthesis.yaml technology)
  --build          Force rebuild of the thin cva6-synthesis wrapper image (Yosys profile)
  -h, --help       Show this help
USAGE
}

fail() {
    printf 'cva6-synthesis: %s\n' "$*" >&2
    exit 2
}

synth_dir=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
repo_root=$(CDPATH='' cd -- "${synth_dir}/.." && pwd -P)
harness_dir="${synth_dir}/docker-harness"
config_file="${repo_root}/synthesis.yaml"
output_root="${SYNTH_OUTPUT_ROOT:-${synth_dir}/runs}"
tool_image="${CVA6_SYNTH_IMAGE:-cva6-synthesis:local}"
project_name="${CVA6_SYNTH_PROJECT:-cva6-synthesis}"

target=
mode=
tech=
force_build=false
while (($# > 0)); do
    case "$1" in
        --target)
            (($# >= 2)) || fail "--target requires a value"
            target=$2
            shift 2
            ;;
        --mode)
            (($# >= 2)) || fail "--mode requires a value"
            mode=$2
            shift 2
            ;;
        --tech)
            (($# >= 2)) || fail "--tech requires a value"
            tech=$2
            shift 2
            ;;
        --build)
            force_build=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            fail "unknown argument '$1'"
            ;;
    esac
done

[[ -n "$target" ]] || fail "--target is required"
[[ "$target" =~ ^[A-Za-z0-9_.-]+$ ]] || fail "target contains unsupported characters"
[[ -f "$config_file" && -r "$config_file" ]] || fail "missing readable synthesis.yaml in the repository root"
[[ -x "${harness_dir}/run-tool.sh" ]] || fail \
    "docker-harness submodule is missing; run: git submodule update --init --recursive"

# Top-level keys of synthesis.yaml; no YAML parser on the host.
profile=$(sed -n 's/^profile: *\([a-z0-9]*\).*/\1/p' "$config_file")
technology=$(sed -n 's/^technology: *\([a-z0-9]*\).*/\1/p' "$config_file")

if [[ "$profile" == orfs ]]; then
    mode=${mode:-fast}
    tech=${tech:-$technology}
    [[ "$mode" == fast || "$mode" == opt ]] || fail "--mode must be 'fast' or 'opt' with the orfs profile"
    [[ "$tech" == asap7 || "$tech" == nangate45 ]] || fail "--tech must be 'asap7' or 'nangate45'"
    override_file="${synth_dir}/container/compose.orfs.yaml"
    tool_image=$(sed -n 's/^ *image: *//p' "$override_file")
    gsim_override="${synth_dir}/container/compose.gsim.yaml"
    run_path="${target}/${tech}/${mode}"
else
    mode=${mode:-full}
    [[ "$mode" == quick || "$mode" == full ]] || fail "--mode must be 'quick' or 'full'"
    [[ -z "$tech" ]] || fail "--tech needs the orfs profile"
    override_file="${synth_dir}/container/compose.override.yaml"
    run_path="${target}/${mode}"
fi
[[ -f "$override_file" ]] || fail "missing Compose override: ${override_file}"

mkdir -p -- "${output_root}/${run_path}"
output_root=$(realpath -- "$output_root")
run_id=$(date '+%Y-%m-%d_%H-%M-%S')
run_dir="${output_root}/${run_path}/${run_id}"
[[ ! -e "$run_dir" ]] || fail "run directory already exists: ${run_dir}"
mkdir -- "$run_dir"

metadata_file="${run_dir}/metadata.txt"
{
    printf 'target=%s\n' "$target"
    printf 'mode=%s\n' "$mode"
    [[ "$profile" != orfs ]] || printf 'technology=%s\n' "$tech"
    printf 'start_time=%s\n' "$(date --iso-8601=seconds)"
    printf 'tool_image=%s\n' "$tool_image"
    [[ -z "${gsim_override:-}" ]] || printf 'gsim_image=%s\n' "$(sed -n 's/^ *image: *//p' "$gsim_override")"
    printf 'synthesis_config_sha256=%s\n' "$(sha256sum "$config_file" | awk '{print $1}')"
    if git -C "$repo_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        printf 'repo_commit=%s\n' "$(git -C "$repo_root" rev-parse HEAD)"
        if [[ "$profile" == orfs ]]; then
            # Upstream commit under the ft-synthesis commits. The RTL must equal it
            # except files changed by the tool-compatibility commits (BR-3) on top,
            # so uncommitted RTL changes fail the run.
            upstream_sha=$(git -C "$repo_root" merge-base HEAD "${CVA6_UPSTREAM_REF:-origin/master}")
            printf 'upstream_sha=%s\n' "$upstream_sha"
            printf 'upstream_date=%s\n' "$(git -C "$repo_root" log -1 --format=%cI "$upstream_sha")"
            printf 'upstream_title=%s\n' "$(git -C "$repo_root" log -1 --format=%s "$upstream_sha")"
            printf 'rtl_patched=%s\n' "$(git -C "$repo_root" diff --name-only "$upstream_sha" HEAD -- core common vendor | xargs)"
            if git -C "$repo_root" diff --quiet HEAD -- core common vendor; then
                printf 'rtl_match=yes\n'
            else
                printf 'rtl_match=no\n'
            fi
        fi
        if [[ -n "$(git -C "$repo_root" status --porcelain --untracked-files=no)" ]]; then
            printf 'repo_dirty=yes\n'
        else
            printf 'repo_dirty=no\n'
        fi
    fi
    if git -C "$synth_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        printf 'cva6_synthesis_commit=%s\n' "$(git -C "$synth_dir" rev-parse HEAD)"
        printf 'flow_version=%s\n' "$(git -C "$synth_dir" describe --always --dirty --abbrev=7)"
    fi
    if git -C "$harness_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        printf 'docker_harness_commit=%s\n' "$(git -C "$harness_dir" rev-parse HEAD)"
    fi
} >"$metadata_file"

env_file=$(mktemp "${TMPDIR:-/tmp}/cva6-synthesis.XXXXXX.env")
cleanup() {
    rm -f -- "$env_file"
}
trap cleanup EXIT

cat >"$env_file" <<ENV
INPUT_HOST=${repo_root}
OUTPUT_HOST=${run_dir}
HOST_UID=$(id -u)
HOST_GID=$(id -g)
TOOL_IMAGE=${tool_image}
SYNTH_CONTEXT=${synth_dir}
IIC_OSIC_TOOLS_IMAGE=${IIC_OSIC_TOOLS_IMAGE:-hpretl/iic-osic-tools:2026.07}
CVA6_SYNTH_CPUS=${CVA6_SYNTH_CPUS:-}
ENV

compose_args=(
    --project-directory "$harness_dir"
    --env-file "$env_file"
    -f "${harness_dir}/compose.yaml"
    -f "$override_file"
    -p "$project_name"
)

if [[ "$profile" != orfs ]] && { "$force_build" || ! docker image inspect "$tool_image" >/dev/null 2>&1; }; then
    printf 'Building %s ...\n' "$tool_image"
    docker compose "${compose_args[@]}" build tool
fi

printf 'Running target %s in %s mode\n' "$target" "$mode"
printf 'Results: %s\n' "$run_dir"

set +e
"${harness_dir}/run-tool.sh" \
    --env-file "$env_file" \
    --project "$project_name" \
    --override "$override_file" \
    -- "$target" --mode "$mode" ${tech:+--tech "$tech"} 2>&1 | tee "${run_dir}/console.log"
status=${PIPESTATUS[0]}

# Gate-level simulation of the same run, when the flow wrote its inputs. Its
# results go into results.json; a simulation problem does not fail the run.
if [[ "$status" -eq 0 && -s "${run_dir}/gsim/tests.txt" ]]; then
    # Optional lock file shared by parallel runs: the netlist build needs much
    # memory, so only one simulation runs at a time.
    if [[ -n "${CVA6_SYNTH_GSIM_LOCK:-}" ]]; then
        exec {gsim_lock}>"$CVA6_SYNTH_GSIM_LOCK"
        printf 'Waiting for the gate-level simulation lock\n'
        flock "$gsim_lock"
    fi
    printf 'Gate-level simulation\n'
    "${harness_dir}/run-tool.sh" \
        --env-file "$env_file" \
        --project "$project_name" \
        --override "$gsim_override" -- 2>&1 | tee -a "${run_dir}/console.log"
fi
set -e

{
    printf 'end_time=%s\n' "$(date --iso-8601=seconds)"
    printf 'exit_status=%s\n' "$status"
} >>"$metadata_file"

ln -sfn -- "$run_id" "${output_root}/${run_path}/latest"
if [[ "$status" -eq 0 ]]; then
    ln -sfn -- "$run_id" "${output_root}/${run_path}/latest-success"
fi

exit "$status"
