# Deviations

## RTL: reversed part-selects in Sv32 dead code

The slang frontend built into Yosys 0.68 (pinned image) silently drops a
whole `always_comb` block that contains a constant part-select with reversed
bounds, even when the select is in code that is dead for the configuration:
the outputs of the block become undefined and synthesis removes the logic
behind them. With XLEN = 32 (`cv32a6_imac_sv32`), `core/cva6_mmu/cva6_mmu.sv`
(`fetch_vaddr[VLEN-1:GPLEN]` = `[31:34]`, guarded by `IS_XLEN64`) and
`core/cva6_mmu/cva6_ptw.sv` (`pte.ppn[PPNW-1:GPPNW]` = `[21:22]`, guarded by
`RVH`) contain such selects, so the MMU instruction interface and the
page-table walker are lost, instruction fetch never starts, and almost the
whole core is optimised away. A tool-compatibility commit on `ft-synthesis`
writes both selects as the OR-reduction of a right shift, which reads the same
bits when the range is valid and is zero when it is empty, so the logic is
unchanged. The commit can be dropped once the pinned Yosys keeps an
`always_comb` block such as `if (0) y = |v[31:34];` (with `v` declared
`[31:0]`).
