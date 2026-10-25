#!/usr/bin/env python3
"""Generate the static dashboard page from a list of run records.

Usage: python3 generate.py <runs.json | runs_dir> <out_dir>

A runs directory is searched for */latest-success/results.json. The page is
template.html with the records of the newest flow version filled in; all
presentation lives in the template.
"""
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

TEMPLATE = Path(__file__).with_name("template.html")


def main(runs_path, out_dir):
    src = Path(runs_path)
    if src.is_dir():
        runs = [json.loads(f.read_text()) for f in sorted(src.glob("**/latest-success/results.json"))]
    else:
        runs = json.loads(src.read_text())
    fast = [r for r in runs if r["sram_mode"] == "fakeram" and r.get("mode", "fast") == "fast"]
    # The page shows one flow version: the one of the most recent run.
    started = lambda r: datetime.fromisoformat(r.get("run_started") or "1970-01-01T00:00:00+00:00")
    newest = max(fast, key=started) if fast else {}
    data = {"generated": datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC"),
            "flow_version": newest.get("flow_version", ""), "image": newest.get("image", ""),
            "records": [r for r in fast if r["flow_version"] == newest.get("flow_version")]}
    page = TEMPLATE.read_text().replace("/*DATA*/null", json.dumps(data).replace("</", "<\\/"))
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    (out / "index.html").write_text(page, encoding="utf-8")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
