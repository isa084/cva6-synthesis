#!/usr/bin/env python3
"""Generate a static HTML dashboard from a list of run records.

Usage: python3 generate.py <runs.json | runs_dir> <out_dir>

A runs directory is searched for */latest-success/results.json.
"""
import json
import sys
from datetime import datetime, timezone
from html import escape
from pathlib import Path

METHOD_URL = "https://github.com/isa084/cva6-synthesis/blob/master/docs/RESULTS.md"
COMMIT_URL = "https://github.com/openhwfoundation/cva6/commit/"
TECHS = ["asap7", "nangate45"]
HISTORY = 10

CSS = """
:root{--bg:#fff;--fg:#1c2128;--muted:#667085;--line:#d8dee4;--head:#f1f4f7;--link:#0b5cad;--bad:#b42318;--good:#13794a}
@media(prefers-color-scheme:dark){:root{--bg:#14181d;--fg:#e6e9ee;--muted:#9aa4b2;--line:#2c333b;--head:#1d232a;--link:#6cb2ff;--bad:#ff8a80;--good:#6fd39b}}
body{margin:0 auto;max-width:1100px;padding:16px;background:var(--bg);color:var(--fg);
font:16px/1.5 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif}
a{color:var(--link)}h1{font-size:1.6rem}h2{margin-top:2rem}h3{font-size:1rem;margin:1.5rem 0 .5rem}
.wrap{overflow-x:auto}table{border-collapse:collapse;width:100%;font-size:.9rem}
th,td{padding:6px 10px;border-bottom:1px solid var(--line);text-align:right;white-space:nowrap}
th{background:var(--head)}th:first-child,td:first-child,.l{text-align:left}
.bad{color:var(--bad)}.good{color:var(--good)}.muted,footer{color:var(--muted);font-size:.85rem}
code{font-size:.85rem}footer{margin-top:2.5rem}
"""

COLS = ["Commit", "Date", "Status", "Std-cell area (µm²)", "Total area (µm²)",
        "kGE", "Fmax (MHz)", "WNS (ps)", "Gate sim"]


def num(v, dec=0):
    return "—" if v is None else f"{v:,.{dec}f}"


def cells(r):
    sha = r["upstream_sha"]
    status = r["status"]
    sim = "—" if r.get("gsim_run") is None else f'{r.get("gsim_passed", 0)}/{r["gsim_run"]}'
    cls = "good" if status in ("ok", "success") else "bad"
    return [
        f'<a href="{COMMIT_URL}{escape(sha)}">{escape(sha[:8])}</a>',
        escape(r["upstream_date"][:10]),
        f'<span class="{cls}">{escape(status)}</span>',
        num(r.get("stdcell_area_um2")), num(r.get("total_area_um2")),
        num(r.get("stdcell_kgate"), 1), num(r.get("fmax_mhz"), 1),
        num(r.get("worst_slack_ps"), 1), sim,
    ]


def table(head, rows):
    th = "".join(f"<th>{h}</th>" for h in head)
    body = "".join("<tr>" + "".join(f"<td>{c}</td>" for c in row) + "</tr>" for row in rows)
    return f'<div class="wrap"><table><tr>{th}</tr>{body}</table></div>'


def delta(new, old):
    if new is None or not old:
        return "—"
    pct = (new - old) / old * 100
    return f'<span class="{"bad" if pct > 0 else "good"}">{pct:+.2f}%</span>' if pct else "0.00%"


def tech_section(tech, recs):
    targets = sorted({r["target"] for r in recs})
    by_target = {t: sorted((r for r in recs if r["target"] == t),
                           key=lambda r: r["upstream_date"], reverse=True) for t in targets}
    out = [f"<h2>{escape(tech)}</h2>", "<h3>Latest commit per target</h3>"]
    rows = [[escape(t)] + cells(by_target[t][0]) for t in targets]
    out.append(table(["Target"] + COLS, rows))
    for t in targets:
        hist = by_target[t][:HISTORY]
        rows = []
        for i, r in enumerate(hist):
            prev = hist[i + 1]["total_area_um2"] if i + 1 < len(hist) else None
            rows.append(cells(r) + [delta(r.get("total_area_um2"), prev)])
        out.append(f"<h3>{escape(t)} history</h3>")
        out.append(table(COLS + ["Area change"], rows))
    return "\n".join(out)


def main(runs_path, out_dir):
    src = Path(runs_path)
    if src.is_dir():
        runs = [json.loads(f.read_text()) for f in sorted(src.glob("**/latest-success/results.json"))]
    else:
        runs = json.loads(src.read_text())
    fake = [r for r in runs if r["sram_mode"] == "fakeram" and r.get("mode", "fast") == "fast"]
    version = max((r["flow_version"] for r in fake), default="")
    shown = [r for r in fake if r["flow_version"] == version]
    images = ", ".join(sorted({r["image"] for r in shown if r.get("image")})) or "—"
    sections = [tech_section(t, [r for r in shown if r["technology"] == t])
                for t in TECHS if any(r["technology"] == t for r in shown)]
    now = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    page = f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>CVA6 area and timing</title><style>{CSS}</style></head>
<body>
<h1>CVA6 area and timing</h1>
<p>Results come from the ORFS flow run to the floorplan stage with top module
<code>cva6</code> and no timing repair, so timing is indicative (pre-layout).
Run mode: fast (complete flow, cheapest settings; detailed <code>opt</code> results to follow). SRAM mode: fakeram (cache memories as SRAM macros). Flow version: {escape(version)}. Tool image: {escape(images)}.
<a href="{METHOD_URL}">Method and reproduction</a></p>
{chr(10).join(sections)}
<footer>
<p>Generated {now}.</p>
<p>Reproduce:<br>
<code>git clone --recursive -b ft-synthesis https://github.com/isa084/cva6.git</code><br>
<code>./synthesis/run.sh --target &lt;target&gt;</code></p>
</footer>
</body></html>
"""
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    (out / "index.html").write_text(page, encoding="utf-8")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
