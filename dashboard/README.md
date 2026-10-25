# Dashboard

This is a static HTML page of CVA6 area and timing results. The page has inline
CSS and no JavaScript. To make the page, run
`python3 dashboard/generate.py <runs.json> <out_dir>`. This command writes
`<out_dir>/index.html`.

The input is a JSON list of run records. The list has one record for each
combination of these values: upstream commit, target, technology, sram_mode, and
flow_version.

The fields are:

- upstream_sha
- upstream_date
- upstream_title
- target
- technology
- sram_mode
- flow_version
- status
- stdcell_area_um2
- macro_area_um2
- total_area_um2
- stdcell_kgate
- fmax_mhz
- worst_slack_ps
- sram_macros
- sram_bits
- gsim_run
- gsim_passed
- clock_period_ps
- image
- reports_url

In v1, the page shows only the `fakeram` records of the newest flow_version.
Failed runs can have null metrics.
