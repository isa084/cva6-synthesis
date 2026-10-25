# Deviations

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
