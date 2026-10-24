#!/usr/bin/env bash
# Regenerate sram/views/<tech>/<macro>/ with FakeRAM2.0 from the ORFS source at
# the commit of the pinned image. Run after changing a cfg or the image.
set -euo pipefail

here=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
orfs_ref=ef324e55542359491ab14565748df975766d90f5
image=$(sed -n 's/^ *image: *//p' "${here}/../container/compose.orfs.yaml")

work=$(mktemp -d "${here}/.gen.XXXXXX")
trap 'rm -rf -- "$work"' EXIT
git clone -q --filter=blob:none --no-checkout \
    https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts.git "${work}/orfs"
git -C "${work}/orfs" sparse-checkout set tools/FakeRAM2.0
git -C "${work}/orfs" checkout -q "$orfs_ref"

for tech in asap7 nangate45; do
    rm -rf -- "${here}/views/${tech}"
    mkdir -p -- "${here}/views/${tech}"
    docker run --rm --user "$(id -u):$(id -g)" \
        -e HOME=/tmp -e PYTHONDONTWRITEBYTECODE=1 --entrypoint python3 \
        -v "${work}/orfs/tools/FakeRAM2.0:/gen:ro" \
        -v "${here}/${tech}.cfg:/in.cfg:ro" \
        -v "${here}/views/${tech}:/out" \
        "$image" /gen/run.py /in.cfg --output_dir /out
done
