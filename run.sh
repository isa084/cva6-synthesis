#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'USAGE'
Usage:
  ./synthesis/run.sh --target TARGET [--build]

Options:
  --target TARGET  Target key from repo_home/synthesis.yaml (for example baseline or zp)
  --build          Force rebuild of the thin cva6-synthesis wrapper image
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
override_file="${synth_dir}/container/compose.override.yaml"
config_file="${repo_root}/synthesis.yaml"
output_root="${SYNTH_OUTPUT_ROOT:-${synth_dir}/runs}"
tool_image="${CVA6_SYNTH_IMAGE:-cva6-synthesis:local}"
project_name="${CVA6_SYNTH_PROJECT:-cva6-synthesis}"

target=
force_build=false
while (($# > 0)); do
    case "$1" in
        --target)
            (($# >= 2)) || fail "--target requires a value"
            target=$2
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
[[ -f "$config_file" && -r "$config_file" ]] || fail "missing readable ${config_file}"
[[ -x "${harness_dir}/run-tool.sh" ]] || fail \
    "docker-harness submodule is missing; run: git submodule update --init --recursive"
[[ -f "$override_file" ]] || fail "missing Compose override: ${override_file}"

mkdir -p -- "${output_root}/${target}"
output_root=$(realpath -- "$output_root")
run_id=$(date '+%Y-%m-%d_%H-%M-%S')
run_dir="${output_root}/${target}/${run_id}"
[[ ! -e "$run_dir" ]] || fail "run directory already exists: ${run_dir}"
mkdir -- "$run_dir"

metadata_file="${run_dir}/metadata.txt"
{
    printf 'target=%s\n' "$target"
    printf 'start_time=%s\n' "$(date --iso-8601=seconds)"
    printf 'repo_root=%s\n' "$repo_root"
    printf 'tool_image=%s\n' "$tool_image"
    if git -C "$repo_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        printf 'repo_commit=%s\n' "$(git -C "$repo_root" rev-parse HEAD)"
        if [[ -n "$(git -C "$repo_root" status --porcelain --untracked-files=no)" ]]; then
            printf 'repo_dirty=yes\n'
        else
            printf 'repo_dirty=no\n'
        fi
    fi
    if git -C "$synth_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        printf 'cva6_synthesis_commit=%s\n' "$(git -C "$synth_dir" rev-parse HEAD)"
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
ENV

compose_args=(
    --project-directory "$harness_dir"
    --env-file "$env_file"
    -f "${harness_dir}/compose.yaml"
    -f "$override_file"
    -p "$project_name"
)

if "$force_build" || ! docker image inspect "$tool_image" >/dev/null 2>&1; then
    printf 'Building %s ...\n' "$tool_image"
    docker compose "${compose_args[@]}" build tool
fi

printf 'Running target %s\n' "$target"
printf 'Results: %s\n' "$run_dir"

set +e
"${harness_dir}/run-tool.sh" \
    --env-file "$env_file" \
    --project "$project_name" \
    --override "$override_file" \
    -- "$target" 2>&1 | tee "${run_dir}/console.log"
status=${PIPESTATUS[0]}
set -e

{
    printf 'end_time=%s\n' "$(date --iso-8601=seconds)"
    printf 'exit_status=%s\n' "$status"
} >>"$metadata_file"

ln -sfn -- "$run_id" "${output_root}/${target}/latest"
if [[ "$status" -eq 0 ]]; then
    ln -sfn -- "$run_id" "${output_root}/${target}/latest-success"
fi

exit "$status"
