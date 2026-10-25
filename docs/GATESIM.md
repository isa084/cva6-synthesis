# Gate-level simulation

The flow simulates the netlist that it measures. The simulation is functional
and has zero delay. It runs after the flow, in a second container, on the same
run directory.

## Inputs

| Input | Source |
|---|---|
| Netlist | `gsim/netlist.v`. OpenROAD writes it from the floorplan database that gives the area and the timing of the run. |
| Cell models | `gsim/cells.v`. Yosys makes them from the Liberty files of the run. |
| Memory models | The FakeRAM behavioural models, `sram/views/<tech>/<macro>/<macro>.v`. |
| Testbench | `gsim/tb/gsim_tb.sv`. |
| Programs | `gsim/tests/hex/<program>.hex`. Each target lists its programs in `tests:` of `synthesis.yaml`. |
| RTL | `gsim/rtl.f`: the file list of the run, with the memory models in place of the macro black boxes. |

`flow/orfs.py` writes `gsim/` in the run directory when the target has `tests:`.
`gsim/run.py` runs in the Verilator image of `container/compose.gsim.yaml`.

## Testbench

The testbench connects the AXI port of `cva6` to a memory model. It loads the
program at `0x80000000`, releases the reset and starts the core at that address.

The program writes its exit status to `tohost`, at `0x60000000`. This address is
outside the cached region of all targets, so the write reaches the bus also with
a write-back data cache. The testbench does not use the RVFI port, because the
flow removes it from the netlist.

A program passes when it exits with status 0. A program that does not exit in
1,000,000 cycles times out.

The same testbench and programs also run on the RTL. The gate-level result must
agree with the RTL result.

## Results

- `gsim.log` in the run directory: one line per program, with the RTL result,
  the gate-level result and the cycle count of the netlist.
- `results.json`: `gsim_run`, `gsim_passed` (gate level), and `gsim` (the
  result per program).

A simulation problem does not fail the run. It shows in the results.

## Run it

`./synthesis/run.sh --target <target>` runs the flow and then the simulation.

To repeat only the simulation on a finished run, from the CVA6 checkout:

```bash
image=$(sed -n 's/^ *image: *//p' synthesis/container/compose.gsim.yaml)
docker run --rm -u "$(id -u):$(id -g)" \
  -v "$PWD:/workspace/input:ro" -v "<run directory>:/workspace/output" \
  --entrypoint /workspace/input/synthesis/container/gsim-entrypoint.sh "$image"
```

## Change the programs

1. Edit `gsim/tests/build.sh`.
2. Build the programs with a RISC-V GCC, for example the one from
   `util/toolchain-builder` of CVA6:
   `CVA6=<cva6 checkout> PREFIX=riscv-none-elf- gsim/tests/build.sh`
3. Commit `gsim/tests/hex/`.

The programs come from the CVA6 repository: `verif/tests/custom/hello_world` and
`verif/tests/riscv-tests/isa`. `gsim/tests/link.ld` puts `tohost` at
`0x60000000`.

## Limits

- Zero delay. There is no timing simulation.
- The memory model does not do AXI atomic operations. The programs do not use
  them.
- The `reference` SRAM mode has no simulation: the instruction cache memories
  are absent.
