# Results: what the numbers mean

The results come from the ORFS profile. This profile runs
OpenROAD-flow-scripts on the CVA6 `cva6` module (core only) through the
floorplan stage. Every run writes `results.json` next to its raw ORFS metrics
(`metrics.json`).

## Metrics

| Field | Meaning |
|---|---|
| `stdcell_area_um2` | The area of all standard cells after floorplan. The area of the SRAM macros is not included. |
| `macro_area_um2` | The area of the SRAM macros. The FakeRAM macro views give this area. |
| `total_area_um2` | The standard-cell area plus the macro area. |
| `stdcell_kgate` | The standard-cell area divided by the NAND2 area of the technology, in thousands (kGE). For ASAP7, NAND2x1 RVT = 0.0874 µm². For Nangate45, the flow reads the NAND2_X1 area from the Liberty file. |
| `fmax_mhz` | The highest clock frequency that the worst path allows. OpenSTA gives this value after floorplan. |
| `worst_slack_ps` | The worst setup slack at the configured clock period. A negative value means that the path is too slow. |
| `sram_macros`, `sram_bits` | The number of SRAM macro instances and the total number of bits that they hold. |
| `clock_period_ps` | The constraint that the flow uses. The value is 4000 ps for ASAP7 and 3000 ps for Nangate45. |
| `paths` | The worst setup path of each path group (`in2reg`, `reg2reg`, `reg2out`, `in2out`): slack, startpoint and endpoint. "Core fmax" on the dashboard is 1 / (clock period − `reg2reg` slack). |
| `area_tree` | The floorplan area of each instance of the hierarchical netlist, with its SRAM part. A module below the keep size is part of its parent. Null for a flat netlist. |
| `gsim_run`, `gsim_passed`, `gsim` | The gate-level simulation: the number of programs, the number that pass on the netlist, and the RTL and gate-level result of each program. See `docs/GATESIM.md`. |

Each record also has provenance data:

- upstream commit
- flow version
- image digest
- technology
- run mode
- SRAM mode

## What they do and do not represent

- Pre-layout: The flow has no placement, no clock tree, and no routing. It does
  not model wire delays. The timing values give an indication. They show the
  trends between commits.
- No timing repair: The flow does not resize the netlist or add buffers to meet
  the timing. Thus the timing shows the RTL and not the optimization effort.
- The flow removes the RVFI verification port (`rvfi_probes_o`) before
  synthesis. The flow does not count the logic that only drives this port.
- The SRAM macros are FakeRAM models. They give plausible area and timing
  estimates. They are not silicon memory compilers. ASAP7 is a predictive PDK.
  It is not manufacturable.
- The flow builds byte-enabled memories from 8-bit lane macros. This makes the
  macro footprint slightly larger than the footprint of a write-mask SRAM.
- Some lanes only hold alignment padding. One example is the upper bytes of a
  45-bit tag word that `sram.sv` stores in a 64-bit cut. Nothing reads such a
  lane, so synthesis removes it. `sram_macros` and `sram_bits` count the
  remaining lanes.

## Run modes

| Mode | Settings | Typical time per target |
|---|---|---|
| `fast` | The synthesis of `opt` (hierarchical; modules above 10,000 NAND2 equivalents stay separate; an ABC script for timing). The run stops after the floorplan metrics step, with no timing repair (`orfs/fast.mk`). | minutes |
| `opt` | The reference settings: hierarchical synthesis, an ABC script for timing, and the reference floorplan settings (`orfs/opt.mk`). | hours |

The flow never mixes `fast` results and `opt` results in one series.

## SRAM modes

Set the mode for each target with `sram:` in the `synthesis.yaml` file of the
repository that uses the flow.

| Mode | Effect |
|---|---|
| `fakeram` | The cache memories become FakeRAM macros (default). |
| `flatten` | The flow synthesizes the memories as flip-flops inside the core. The macro area is 0. |
| `blackbox` | The netlist of `fakeram`. The reported area leaves out the SRAM macros. |
| `reference` | The upstream SRAM models. The HPDcache memories are flip-flop arrays. The flow keeps them as separate modules (`SYNTH_KEEP_MODULES`) and reports their area as macro area. The memories behind `tc_sram` are absent, because the upstream model is under `translate_off`. |

In `fakeram`, `blackbox` and `flatten`, the flow replaces the SRAM wrapper modules (`tc_sram_wrapper`,
`tc_sram_wrapper_cache_techno`, `hpdcache_sram_1rw`,
`hpdcache_sram_wbyteenable_1rw`) with the versions in `sram/rtl/`. The flow does
not edit the upstream files.

## Other macros

To use different SRAM shapes or another macro generator:

1. Do one of these steps:
   - Add the shape to `sram/<tech>.cfg`. Then run `sram/generate.sh`.
   - Put your own `.lef`, `.lib`, and `.v` views in
     `sram/views/<tech>/<macro>/`.
2. Map the shape to the macro in `sram/rtl/cva6_sram_1rw_macro.sv`.

## Reproduce

```bash
git clone --recursive -b ft-synthesis https://github.com/isa084/cva6.git
cd cva6
./synthesis/run.sh --target cv32a65x --tech asap7 --mode fast
```

The flow writes the results to
`synthesis/runs/<target>/<tech>/<mode>/latest-success/`.
