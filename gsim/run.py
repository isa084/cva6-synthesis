#!/usr/bin/env python3
"""Gate-level simulation of one run, in the Verilator container.

Builds the testbench with the RTL (gsim/rtl.f) and with the measured netlist
(gsim/gate.f, written by flow/orfs.py), runs every program of gsim/tests.txt
on both, writes gsim.log and adds the results to results.json. A program
passes when it exits with status 0 (see gsim/tb/gsim_tb.sv).
"""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

OUTPUT_DIR = Path("/workspace/output")
GSIM = OUTPUT_DIR / "gsim"
FLOW_ROOT = Path(__file__).resolve().parents[1]
TB = FLOW_ROOT / "gsim/tb/gsim_tb.sv"
PROGRAMS = FLOW_ROOT / "gsim/tests/hex"
MAX_CYCLES = 1_000_000
JOBS = os.environ.get("CVA6_SYNTH_CPUS") or str(max(1, (os.cpu_count() or 2) // 2))


def build(kind: str, flist: Path, defines: list[str]) -> Path | None:
    """Verilate and compile the testbench; None if the build fails."""
    obj = GSIM / f"obj_{kind}"
    cmd = ["verilator", "--binary", "--timing", "-j", JOBS, "--top-module", "gsim_tb",
           "-Wno-fatal", "-Wno-lint", "-Wno-style", "-Wno-UNOPTFLAT",
           "--x-assign", "fast", "--x-initial", "fast",
           # Short programs: compile time matters more than simulation speed.
           "-MAKEFLAGS", "OPT_FAST=-O1 OPT_SLOW=-O0 OPT_GLOBAL=-O1",
           # One compiler process per generated file: grouping files needs too much memory.
           "--output-groups", "0",
           *defines, "-f", str(flist), str(TB), "--Mdir", str(obj), "-o", "sim"]
    with open(GSIM / f"build_{kind}.log", "w") as log:
        built = subprocess.run(cmd, stdout=log, stderr=subprocess.STDOUT).returncode == 0
    return obj / "sim" if built else None


def simulate(sim: Path | None, program: str) -> tuple[str, int | None]:
    """(pass | fail | timeout | error, cycles) of one program."""
    if sim is None:
        return "error", None
    out = subprocess.run([str(sim), f"+hex={PROGRAMS / program}.hex", f"+max_cycles={MAX_CYCLES}"],
                         capture_output=True, text=True).stdout
    match = re.search(r"^GSIM (PASS|FAIL|TIMEOUT)(.*)$", out, re.M)
    if not match:
        return "error", None
    cycles = re.search(r"after (\d+) cycles", match.group(2))
    return match.group(1).lower(), int(cycles.group(1)) if cycles else None


def main() -> int:
    programs = (GSIM / "tests.txt").read_text().split()
    sims = {"rtl": build("rtl", GSIM / "rtl.f", []), "gate": build("gate", GSIM / "gate.f", ["-DGATE"])}
    tests = []
    for program in programs:
        rtl, _ = simulate(sims["rtl"], program)
        gate, cycles = simulate(sims["gate"], program)
        tests.append({"test": program, "rtl": rtl, "gate": gate, "cycles": cycles})
    # The builds are large (up to a few GB of generated C++); the logs stay.
    for kind in sims:
        shutil.rmtree(GSIM / f"obj_{kind}", ignore_errors=True)

    lines = [f"{'test':<20} {'rtl':<8} {'gate':<8} cycles"]
    lines += [f"{t['test']:<20} {t['rtl']:<8} {t['gate']:<8} {t['cycles'] or '-'}" for t in tests]
    (OUTPUT_DIR / "gsim.log").write_text("\n".join(lines) + "\n")
    print("\n".join(lines))

    results_file = OUTPUT_DIR / "results.json"
    result = json.loads(results_file.read_text())
    result.update(gsim_run=len(tests), gsim_passed=sum(t["gate"] == "pass" for t in tests), gsim=tests)
    results_file.write_text(json.dumps(result, indent=2) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
