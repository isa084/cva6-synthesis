# Dashboard

Static HTML page (inline CSS, no JavaScript) of CVA6 area and timing results.
Usage: `python3 dashboard/generate.py <runs.json> <out_dir>` writes `<out_dir>/index.html`.

Input: a JSON list of run records, one per (upstream commit, target, technology, sram_mode,
flow_version). Fields: upstream_sha, upstream_date, upstream_title, target, technology, sram_mode,
flow_version, status, stdcell_area_um2, macro_area_um2, total_area_um2, stdcell_kgate, fmax_mhz,
worst_slack_ps, sram_macros, sram_bits, gsim_run, gsim_passed, clock_period_ps, image, reports_url.
v1 shows only `fakeram` records of the newest flow_version; failed runs may have null metrics.
