ARG IIC_OSIC_TOOLS_IMAGE=hpretl/iic-osic-tools:2026.07
FROM ${IIC_OSIC_TOOLS_IMAGE}

USER root

# The upstream entrypoint adds the prebuilt EDA launchers dynamically. This
# wrapper replaces that entrypoint, so expose the same tool directory directly.
ENV PATH="/foss/tools/bin:${PATH}"

# docker-harness supplies these build args. They are intentionally not used by
# this wrapper image because runtime UID/GID selection is handled by Compose.
ARG HOST_UID
ARG HOST_GID

# IIC-OSIC-TOOLS already provides Yosys, yosys-slang, OpenSTA and OpenROAD.
# Add only the small YAML dependency needed by this repository's config loader.
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates git python3 python3-yaml \
    && rm -rf /var/lib/apt/lists/*

# Match the Nangate45 platform files to the ORFS revision recorded by the
# prebuilt OpenROAD installation in the IIC image.
RUN test -r /foss/tools/openroad/ORFS_COMMIT \
    && ORFS_REF="$(cat /foss/tools/openroad/ORFS_COMMIT)" \
    && git clone --filter=blob:none --no-checkout \
        https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts.git \
        /opt/OpenROAD-flow-scripts \
    && git -C /opt/OpenROAD-flow-scripts sparse-checkout set flow/platforms/nangate45 \
    && git -C /opt/OpenROAD-flow-scripts checkout --detach "$ORFS_REF" \
    && rm -rf /opt/OpenROAD-flow-scripts/.git

COPY flow /opt/cva6-synthesis/flow
COPY tech /opt/cva6-synthesis/tech
COPY container/entrypoint.sh /opt/cva6-synthesis/entrypoint.sh
RUN chmod 0755 /opt/cva6-synthesis/entrypoint.sh \
    && /opt/cva6-synthesis/entrypoint.sh --self-check

WORKDIR /workspace/output
ENTRYPOINT ["/opt/cva6-synthesis/entrypoint.sh"]
