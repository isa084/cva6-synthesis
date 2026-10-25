# Dashboard

This is a static HTML page of CVA6 area and timing results.

- `template.html` holds all the presentation: layout, CSS and a small script
  that draws the tables and charts. It has no external files.
- `generate.py` puts the run records into the template and writes
  `<out_dir>/index.html`. It holds no presentation.

## Change the page without a flow run

1. Get the published records:
   `git fetch origin data && git show FETCH_HEAD:runs.json > runs.json`
2. Edit `template.html`.
3. Make the page and open it in a browser:
   `python3 dashboard/generate.py runs.json site && xdg-open site/index.html`
4. Push the change to `master`. The workflow `dashboard.yml` makes the page from
   the `data` branch and deploys it. It does not run the flow. You can also
   start it from the Actions tab.

## Input

The input is a JSON list of run records (`results.json` of each run). The list
has one record for each combination of these values: upstream commit, target,
technology, mode, and flow_version.

The page uses these fields: upstream_sha, upstream_date, upstream_title,
target, technology, sram_mode, mode, flow_version, status, run_started,
stdcell_area_um2, macro_area_um2, total_area_um2, stdcell_kgate, fmax_mhz,
worst_slack_ps, sram_macros, clock_period_ps, image, and:

- `params`: the main flow settings, as label and value.
- `paths`: the worst setup path per path group (`in2reg`, `reg2reg`,
  `reg2out`, `in2out`), with `slack_ps`, `start` and `end`.
- `area_tree`: the floorplan area per instance (`name`, `module`, `area`,
  `sram`, `children`). It is null for a flat netlist.

The page shows only the `fakeram` and `fast` records of the newest
flow_version. Failed runs can have null metrics.
