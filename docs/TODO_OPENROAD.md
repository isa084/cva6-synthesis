# TODO: OpenROAD physical-design phase

The current scope ends after Nangate45 technology mapping and pre-layout
OpenSTA reporting.

A later, separate phase may add an optional OpenROAD flow for:

- floorplanning and placement;
- clock-tree synthesis;
- routing;
- extracted/post-route timing;
- physical area/utilization reports.

Keep this optional so the fast synthesis + raw STA path stays simple. Reuse the
same `synthesis.yaml` design target where possible and add only physical-design
parameters that are genuinely required.

The IIC-OSIC-TOOLS base image already includes OpenROAD, so this should not
require a new container architecture.
