# Deviations

## Flow: differences from the upstream reference settings

The design settings follow the open-source physical-design flow that upstream
CVA6 proposes: ASAP7, a 4000 ps clock on `clk_i`, 30% input and output delay,
the slang frontend, hierarchical synthesis with a keep size of 10,000 NAND2
equivalents, the RVFI port removed, 55% core utilization and no timing repair.
With these settings, the standard-cell area and the fmax of `cv32a65x` on ASAP7
agree with the published upstream values within 0.1%.

| Item | Upstream reference | This flow | Effect |
|---|---|---|---|
| Flow driver | bazel-orfs | ORFS `make` | None: the same ORFS scripts run. |
| Tools | An older ORFS, Yosys 0.64 | The pinned prebuilt image: ORFS `ef324e5`, Yosys 0.68 | Small differences in synthesis and timing. |
| Cache memories | HPDcache memories as separately placed flip-flop macros; instruction cache memories absent | `fakeram`: FakeRAM macros for every cache memory. `reference`: flip-flop arrays in the netlist, kept as separate modules and counted as macro area; instruction cache memories absent | The macro area of `fakeram` is an SRAM estimate, not a flip-flop array. In `reference`, the arrays are not placed as separate blocks, so their timing can differ. |
| Technologies | ASAP7 | ASAP7 and Nangate45 (3.0 ns) | None for ASAP7. |
| Macro halo (`opt`) | `MACRO_PLACE_HALO=5 5` | `RTLMP_MIN_CHANNEL_SIZE=10 10`; ORFS removed the halo variable | Only for macro placement. |
| Power grid (`opt`) | A design-specific PDN script | The platform PDN; its macro-grid halo is 1.9 µm, not 2.0 µm | Only after the floorplan metrics. |
| Switching activity | A fixed activity for the power metric | Not used; no power metric | None for area and timing. |

The flow adds metrics that the reference does not have: the worst path of each
path group, the area of each instance, and a gate-level simulation of the
measured netlist (`docs/GATESIM.md`).

## RTL: reversed part-selects in Sv32 dead code

The slang frontend in Yosys 0.68 (pinned image) drops a whole `always_comb`
block without a message. This happens when the block contains a constant
part-select with reversed bounds. It also happens when the select is in code
that is dead for the configuration. The outputs of the block become undefined.
Synthesis then removes the logic behind these outputs.

With XLEN = 32 (`cv32a6_imac_sv32`), two files contain such selects:

- `core/cva6_mmu/cva6_mmu.sv` contains `fetch_vaddr[VLEN-1:GPLEN]` = `[31:34]`.
  `IS_XLEN64` guards this select.
- `core/cva6_mmu/cva6_ptw.sv` contains `pte.ppn[PPNW-1:GPPNW]` = `[21:22]`.
  `RVH` guards this select.

As a result, synthesis loses the MMU instruction interface and the page-table
walker. Instruction fetch never starts. Synthesis removes almost the whole core
during optimization.

A tool-compatibility commit on `ft-synthesis` writes both selects as the
OR-reduction of a right shift. This reads the same bits when the range is valid.
It is zero when the range is empty. The logic does not change.

You can drop the commit when the pinned Yosys keeps an `always_comb` block, for
example `if (0) y = |v[31:34];` (with `v` declared `[31:0]`).
