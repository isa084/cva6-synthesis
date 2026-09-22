#!/usr/bin/env python3
"""Minimal driver: YAML target -> Yosys synthesis -> OpenSTA raw report."""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys
from typing import Any, NoReturn

import yaml

INPUT_DIR = Path("/workspace/input")
OUTPUT_DIR = Path("/workspace/output")
FLOW_ROOT = Path("/opt/cva6-synthesis")
DEFAULT_CONFIG = INPUT_DIR / "synthesis.yaml"


def fail(message: str) -> NoReturn:
    print(f"cva6-synthesis: {message}", file=sys.stderr)
    raise SystemExit(2)


def load_yaml(path: Path) -> dict[str, Any]:
    try:
        data = yaml.safe_load(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        fail(f"configuration file not found: {path}")
    except yaml.YAMLError as exc:
        fail(f"invalid YAML in {path}: {exc}")
    if not isinstance(data, dict):
        fail(f"expected a YAML mapping in {path}")
    return data


def require_string(mapping: dict[str, Any], key: str, context: str) -> str:
    value = mapping.get(key)
    if not isinstance(value, str) or not value.strip():
        fail(f"{context}.{key} must be a non-empty string")
    if "\n" in value or "\r" in value:
        fail(f"{context}.{key} must not contain newlines")
    return value


def string_list(mapping: dict[str, Any], key: str, context: str) -> list[str]:
    value = mapping.get(key, [])
    if value is None:
        return []
    if not isinstance(value, list) or not all(isinstance(item, str) for item in value):
        fail(f"{context}.{key} must be a list of strings")
    for item in value:
        if "\n" in item or "\r" in item:
            fail(f"{context}.{key} entries must not contain newlines")
    return value


def repo_path(relative: str, context: str) -> Path:
    path = Path(relative)
    if path.is_absolute():
        fail(f"{context} must be relative to the CVA6 repository: {relative}")
    mounted = INPUT_DIR / path
    if not mounted.exists():
        fail(f"{context} does not exist: {relative}")
    return mounted


def require_command(name: str) -> None:
    if shutil.which(name) is None:
        fail(f"required command is not available in the image: {name}")


def run_command(argv: list[str], env: dict[str, str]) -> None:
    print("+ " + " ".join(argv), flush=True)
    subprocess.run(argv, cwd=OUTPUT_DIR, env=env, check=True)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("target", help="target key from /workspace/input/synthesis.yaml")
    args = parser.parse_args()

    if not INPUT_DIR.is_dir():
        fail(f"input mount is missing: {INPUT_DIR}")
    if not OUTPUT_DIR.is_dir() or not os.access(OUTPUT_DIR, os.W_OK | os.X_OK):
        fail(f"output mount is not writable: {OUTPUT_DIR}")

    config = load_yaml(DEFAULT_CONFIG)
    if config.get("schema") != 1:
        fail("synthesis.yaml must contain 'schema: 1'")

    targets = config.get("targets")
    if not isinstance(targets, dict):
        fail("synthesis.yaml.targets must be a mapping")
    target = targets.get(args.target)
    if not isinstance(target, dict):
        available = ", ".join(sorted(str(name) for name in targets))
        fail(f"unknown target '{args.target}' (available: {available})")

    technology_name = config.get("technology")
    if not isinstance(technology_name, str) or not technology_name:
        fail("synthesis.yaml.technology must be a non-empty string")
    technology = load_yaml(FLOW_ROOT / "tech" / f"{technology_name}.yaml")

    timing = config.get("timing")
    if not isinstance(timing, dict):
        fail("synthesis.yaml.timing must be a mapping")
    clock_port = require_string(timing, "clock_port", "timing")
    try:
        clock_period_ns = float(timing.get("clock_period_ns"))
    except (TypeError, ValueError):
        fail("timing.clock_period_ns must be a positive number")
    if clock_period_ns <= 0:
        fail("timing.clock_period_ns must be a positive number")

    context = f"targets.{args.target}"
    config_name = require_string(target, "config", context)
    top = require_string(target, "top", context)
    flist = repo_path(require_string(target, "flist", context), f"{context}.flist")
    defines = string_list(target, "defines", context)
    extra_sources = [
        repo_path(item, f"{context}.extra_sources").as_posix()
        for item in string_list(target, "extra_sources", context)
    ]
    expect_present = string_list(target, "expect_present", context)
    expect_absent = string_list(target, "expect_absent", context)

    liberty = Path(require_string(technology, "liberty", f"technology.{technology_name}"))
    if not liberty.is_file():
        fail(f"Liberty file not found in image: {liberty}")
    tie_high = technology.get("tie_high")
    tie_low = technology.get("tie_low")
    if not isinstance(tie_high, dict) or not isinstance(tie_low, dict):
        fail(f"technology profile '{technology_name}' is missing tie-cell data")

    require_command("yosys")
    require_command("sta")

    mapped_netlist = OUTPUT_DIR / "mapped-netlist.v"
    timing_report = OUTPUT_DIR / "timing-top10.rpt"

    env = os.environ.copy()
    env.update(
        {
            "CVA6_REPO_DIR": INPUT_DIR.as_posix(),
            "HPDCACHE_DIR": (INPUT_DIR / "core/cache_subsystem/hpdcache").as_posix(),
            "TARGET_CFG": config_name,
            "SYNTH_TOP": top,
            "SYNTH_FLIST": flist.as_posix(),
            "SYNTH_DEFINES": "\n".join(defines),
            "SYNTH_EXTRA_SOURCES": "\n".join(extra_sources),
            "SYNTH_EXPECT_PRESENT": "\n".join(expect_present),
            "SYNTH_EXPECT_ABSENT": "\n".join(expect_absent),
            "LIBERTY_PATH": liberty.as_posix(),
            "TIE_HIGH_CELL": require_string(tie_high, "cell", "tie_high"),
            "TIE_HIGH_PIN": require_string(tie_high, "pin", "tie_high"),
            "TIE_LOW_CELL": require_string(tie_low, "cell", "tie_low"),
            "TIE_LOW_PIN": require_string(tie_low, "pin", "tie_low"),
            "MAPPED_NETLIST": mapped_netlist.as_posix(),
            "CLOCK_PORT": clock_port,
            "CLOCK_PERIOD_NS": str(clock_period_ns),
            "TIMING_REPORT": timing_report.as_posix(),
        }
    )

    print(f"target={args.target}")
    print(f"config={config_name}")
    print(f"top={top}")
    print(f"flist={flist}")
    print(f"technology={technology_name}")
    print(f"clock={clock_port} period={clock_period_ns} ns")

    run_command(["yosys", "-c", str(FLOW_ROOT / "flow/synthesize.tcl")], env)
    if not mapped_netlist.is_file():
        fail("Yosys completed without producing mapped-netlist.v")

    run_command(["sta", "-exit", str(FLOW_ROOT / "flow/sta.tcl")], env)
    if not timing_report.is_file():
        fail("OpenSTA completed without producing timing-top10.rpt")

    print(f"raw reports written to {OUTPUT_DIR}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
