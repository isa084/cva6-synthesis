# Results: what the numbers mean

Results come from the ORFS profile: OpenROAD-flow-scripts run on the CVA6
`cva6` module (core only) through the floorplan stage. Every run writes
`results.json` next to its raw ORFS metrics (`metrics.json`).

## Metrics

| Field | Meaning |
|---|---|
| `stdcell_area_um2` | Area of all standard cells after floorplan, excluding SRAM macros. |
| `macro_area_um2` | Area of the SRAM macros (from the FakeRAM macro views). |
| `total_area_um2` | Standard-cell area plus macro area. |
| `stdcell_kgate` | Standard-cell area divided by the NAND2 area of the technology, in thousands (kGE). ASAP7: NAND2x1 RVT = 0.0874 µm²; Nangate45: NAND2_X1 area read from the Liberty file. |
| `fmax_mhz` | Highest clock frequency the worst path allows, from OpenSTA after floorplan. |
| `worst_slack_ps` | Worst setup slack at the configured clock period (negative = path too slow). |
| `sram_macros`, `sram_bits` | Number of SRAM macro instances and total bits they hold. |
| `clock_period_ps` | Constraint used: ASAP7 4000 ps; Nangate45 3000 ps. |

Each record also carries provenance: upstream commit, flow version, image
digest, technology, run mode and SRAM mode.

## What they do and do not represent

- Pre-layout: no placement, clock tree or routing; wire delays are not
  modelled. Timing is indicative and tracks trends between commits.
- No timing repair: the netlist is not resized or buffered to meet timing, so
  timing reflects the RTL rather than optimisation effort.
- The RVFI verification port (`rvfi_probes_o`) is removed before synthesis;
  logic that only drives it is not counted.
- SRAM macros are FakeRAM models: plausible area and timing estimates, not
  silicon memory compilers. ASAP7 is a predictive (non-manufacturable) PDK.
- Byte-enabled memories are built from 8-bit lane macros, which slightly
  enlarges the macro footprint compared with a write-mask SRAM.

## Run modes

| Mode | Settings | Typical time per target |
|---|---|---|
| `fast` | Flat synthesis, area-oriented ABC script, no floorplan timing repair (`orfs/fast.mk`). | minutes |
| `opt` | Reference settings: hierarchical synthesis, timing-oriented ABC, reference floorplan settings (`orfs/opt.mk`). | hours |

`fast` and `opt` results are never mixed in one series.

## SRAM modes

Set per target with `sram:` in the consuming repository's `synthesis.yaml`.

| Mode | Effect |
|---|---|
| `fakeram` | Cache memories become FakeRAM macros (default). |
| `flatten` | Memories are synthesised as flip-flops inside the core; macro area is 0. |

The flow replaces the SRAM wrapper modules (`tc_sram_wrapper`,
`tc_sram_wrapper_cache_techno`, `hpdcache_sram_1rw`,
`hpdcache_sram_wbyteenable_1rw`) with the versions in `sram/rtl/`; upstream
files are not edited.

## Other macros

To use different SRAM shapes or another macro generator:

1. Add the shape to `sram/<tech>.cfg` and run `sram/generate.sh`, or place
   your own `.lef`, `.lib` and `.v` views in `sram/views/<tech>/<macro>/`.
2. Map the shape to the macro in `sram/rtl/cva6_sram_1rw_macro.sv`.

## Reproduce

```bash
git clone --recursive -b ft-synthesis https://github.com/isa084/cva6.git
cd cva6
./synthesis/run.sh --target cv32a65x --tech asap7 --mode fast
```

Results are written to `synthesis/runs/<target>/<tech>/<mode>/latest-success/`.
