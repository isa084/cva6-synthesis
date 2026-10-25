# TODO: OpenROAD physical-design phase

The current scope ends after the flow maps the design to Nangate45 technology
and makes the pre-layout OpenSTA report.

A later, separate phase can add an optional OpenROAD flow for these tasks:

- floorplanning and placement
- clock-tree synthesis
- routing
- extracted post-route timing
- physical area and utilization reports

Keep this phase optional. This keeps the fast synthesis and raw STA path simple.
Where possible, reuse the same `synthesis.yaml` design target. Add only the
physical-design parameters that the phase needs.

The IIC-OSIC-TOOLS base image already includes OpenROAD. Therefore this phase
should not need a new container architecture.
