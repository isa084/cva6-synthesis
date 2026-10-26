# Dashboard

This is a static HTML page of CVA6 area and timing results.

- `template.html` holds all the presentation: layout, CSS and a small script
  that draws the tables and charts. It has no external files.
- `generate.py` puts the run records into the template and writes
  `<out_dir>/index.html`. It holds no presentation.

## CI jobs card

The "CI jobs" card shows the next scheduled check, the state of each flow job
of the active or latest `track` run, and the recent runs. The browser reads
this data live from the public GitHub API. The card needs no token and no page
rebuild.

## Change the page without a flow run

1. Get the published records:
   `git fetch origin data && git show FETCH_HEAD:runs.json > runs.json && git show FETCH_HEAD:commits.json > commits.json`
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
worst_slack_ps, sram_macros, clock_period_ps, image, config (the CVA6
configuration of the target), and:

- `params`: the main flow settings, as label and value.
- `paths`: the worst setup path per path group (`in2reg`, `reg2reg`,
  `reg2out`, `in2out`), with `slack_ps`, `start` and `end`.
- `area_tree`: the floorplan area per instance (`name`, `module`, `area`,
  `sram`, `children`). It is null for a flat netlist.
- `gsim_run`, `gsim_passed`, `gsim`: the gate-level simulation (per program:
  `test`, `rtl`, `gate`, `cycles`).

`commits.json` (beside `runs.json`, optional) lists the recent commits of the
tracked upstream branch, newest first: `sha`, `date`, `title`, and `rtl`
(false when the commit does not change the RTL). The trends and the history
show every listed commit from the first one with a result. A commit with
`rtl` false shows the result of the commit before it, with a hollow marker.

The page shows the `fast` records of the newest flow_version. An SRAM model
selector appears when the records have more than one `sram_mode`. Failed runs
can have null metrics.
