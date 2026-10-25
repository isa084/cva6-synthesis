"""ORFS profile: synthesis to floorplan with SRAM macros, results.json."""

from __future__ import annotations

import json
import os
from pathlib import Path
import re
import subprocess

INPUT_DIR = Path("/workspace/input")
OUTPUT_DIR = Path("/workspace/output")
FLOW_ROOT = Path(__file__).resolve().parents[1]
ORFS_FLOW = Path("/OpenROAD-flow-scripts/flow")

# Make target per mode: fast stops at the step that reports the metrics.
MAKE_TARGET = {"fast": "2_1_floorplan", "opt": "floorplan"}
# Time unit of CLOCK_PERIOD and of the reported slack, in ps.
UNIT_PS = {"asap7": 1, "nangate45": 1000}

# Per SRAM mode: upstream files dropped from the file list, and the files of
# sram/rtl that replace them.
TC_WRAPPERS = ["common/local/util/tc_sram_wrapper.sv",
               "common/local/util/tc_sram_wrapper_cache_techno.sv"]
HPD_BEHAV = "core/cache_subsystem/hpdcache/rtl/src/common/macros/behav/"
HPD_SRAMS = [HPD_BEHAV + "hpdcache_sram_1rw.sv", HPD_BEHAV + "hpdcache_sram_wbyteenable_1rw.sv"]
SRAM_MODES = {
    "fakeram": (TC_WRAPPERS + HPD_SRAMS,
                [Path(p).name for p in TC_WRAPPERS + HPD_SRAMS] + ["cva6_sram_1rw_macro.sv"]),
    "flatten": (TC_WRAPPERS,
                [Path(p).name for p in TC_WRAPPERS] + ["cva6_sram_1rw_ff.sv"]),
}


def fail(message: str):
    raise SystemExit(f"cva6-synthesis: {message}")


def expand_flist(path: Path, files: list[str], incdirs: list[str]) -> None:
    for raw in path.read_text().splitlines():
        line = os.path.expandvars(raw.split("//")[0].strip())
        if line.startswith("+incdir+"):
            incdirs.append(line[len("+incdir+"):])
        elif line.startswith("-F "):
            expand_flist(Path(line[3:].strip()), files, incdirs)
        elif line:
            files.append(line)


def mk_var(path: Path, name: str) -> str | None:
    match = re.search(rf"^export {name}\s*=\s*(\S+)", path.read_text(), re.M)
    return match.group(1) if match else None


def read_meta() -> dict[str, str]:
    lines = (OUTPUT_DIR / "metadata.txt").read_text().splitlines()
    return dict(line.split("=", 1) for line in lines if "=" in line)


def write_config(target: dict, tech: str, mode: str, sram: str, config_mk: Path) -> None:
    # Flist variables, as the core manifests expect them.
    os.environ.update(CVA6_REPO_DIR=INPUT_DIR.as_posix(), TARGET_CFG=target["config"],
                      HPDCACHE_DIR=(INPUT_DIR / "core/cache_subsystem/hpdcache").as_posix())
    files: list[str] = []
    incdirs: list[str] = []
    expand_flist(INPUT_DIR / target["flist"], files, incdirs)

    drop, add = SRAM_MODES[sram]
    dropped = {(INPUT_DIR / p).as_posix() for p in drop}
    files = [f for f in files if f not in dropped]
    files += [(FLOW_ROOT / "sram/rtl" / name).as_posix() for name in add]
    files += [(INPUT_DIR / p).as_posix() for p in target.get("extra_sources") or []]

    views = FLOW_ROOT / "sram/views" / tech
    lines = [f"export CVA6_FLOW_DIR = {FLOW_ROOT}",
             "export DESIGN_NICKNAME = cva6",
             f"export NUM_CORES = {max(1, (os.cpu_count() or 2) // 2)}",
             "export VERILOG_FILES = " + " ".join(files),
             "export VERILOG_INCLUDE_DIRS = " + " ".join(incdirs),
             "export VERILOG_DEFINES = " + " ".join(f"-D {d}" for d in target.get("defines") or [])]
    if sram == "fakeram":
        macros = sorted(views.glob("*/*"))
        lines += ["export ADDITIONAL_LEFS = " + " ".join(str(m) for m in macros if m.suffix == ".lef"),
                  "export ADDITIONAL_LIBS = " + " ".join(str(m) for m in macros if m.suffix == ".lib"),
                  "export VERILOG_FILES += " + " ".join(str(m) for m in macros if m.suffix == ".sv")]
    lines += [f"include $(CVA6_FLOW_DIR)/orfs/{name}.mk" for name in ("cva6", tech, mode)]
    config_mk.parent.mkdir(parents=True, exist_ok=True)
    config_mk.write_text("\n".join(lines) + "\n")


def nand2_area(tech_mk: Path) -> float:
    area = mk_var(tech_mk, "NAND2_AREA")
    if area:
        return float(area)
    liberty = Path(mk_var(tech_mk, "NAND2_LIBERTY") or "").read_text()
    return float(re.search(r"cell \(NAND2_X1\)\s*\{.*?area\s*:\s*([\d.]+)", liberty, re.S).group(1))


def sram_masters(odb: Path) -> list[tuple[int, int, int]]:
    """(depth, width, instances) per SRAM macro master in the floorplan."""
    out = subprocess.run(["openroad", "-no_splash", "-exit", str(FLOW_ROOT / "flow/macros.tcl")],
                         env={**os.environ, "ODB_FILE": str(odb)}, check=True,
                         capture_output=True, text=True).stdout
    return [tuple(map(int, m)) for m in re.findall(r"^SRAM cva6_sram_(\d+)x(\d+) (\d+)$", out, re.M)]


def run(target_name: str, target: dict, config: dict, tech: str | None, mode: str | None) -> int:
    tech = tech or config["technology"]
    mode = mode or "fast"
    sram = target.get("sram", "fakeram")
    if tech not in UNIT_PS:
        fail(f"unknown technology '{tech}'")
    if mode not in MAKE_TARGET:
        fail(f"--mode must be fast or opt with the orfs profile, not '{mode}'")
    if sram not in SRAM_MODES:
        fail(f"sram mode '{sram}' is not implemented")

    meta = read_meta()
    tech_mk = FLOW_ROOT / "orfs" / f"{tech}.mk"
    period_ps = round(float(mk_var(tech_mk, "CLOCK_PERIOD")) * UNIT_PS[tech])
    result = {"upstream_sha": meta["upstream_sha"], "upstream_date": meta["upstream_date"],
              "upstream_title": meta["upstream_title"], "target": target_name,
              "technology": tech, "sram_mode": sram, "mode": mode,
              "flow_version": meta["flow_version"], "status": "failed",
              "stdcell_area_um2": None, "macro_area_um2": None, "total_area_um2": None,
              "stdcell_kgate": None, "fmax_mhz": None, "worst_slack_ps": None,
              "sram_macros": None, "sram_bits": None, "clock_period_ps": period_ps,
              "image": meta["tool_image"], "run_started": meta["start_time"],
              "gsim_run": None, "gsim_passed": None,
              "reports_url": ""}
    try:
        if meta["rtl_match"] != "yes":
            fail("RTL has uncommitted changes")
        config_mk = OUTPUT_DIR / "config/config.mk"
        write_config(target, tech, mode, sram, config_mk)
        subprocess.run(["make", "-C", str(ORFS_FLOW), f"DESIGN_CONFIG={config_mk}",
                        f"WORK_HOME={OUTPUT_DIR}", MAKE_TARGET[mode]], check=True)

        base = f"{tech}/cva6/base"
        metrics_file = OUTPUT_DIR / f"logs/{base}/2_1_floorplan.json"
        metrics = json.loads(metrics_file.read_text())
        (OUTPUT_DIR / "metrics.json").write_text(metrics_file.read_text())
        stdcell = metrics["floorplan__design__instance__area__stdcell"]
        masters = sram_masters(OUTPUT_DIR / f"results/{base}/2_1_floorplan.odb")
        result.update(
            status="success", stdcell_area_um2=stdcell,
            macro_area_um2=metrics["floorplan__design__instance__area__macros"],
            total_area_um2=metrics["floorplan__design__instance__area"],
            stdcell_kgate=stdcell / nand2_area(tech_mk) / 1000,
            fmax_mhz=metrics["floorplan__timing__fmax"] / 1e6,
            worst_slack_ps=metrics["floorplan__timing__setup__ws"] * UNIT_PS[tech],
            sram_macros=sum(n for _, _, n in masters),
            sram_bits=sum(d * w * n for d, w, n in masters))
    finally:
        (OUTPUT_DIR / "results.json").write_text(json.dumps(result, indent=2) + "\n")
    return 0
