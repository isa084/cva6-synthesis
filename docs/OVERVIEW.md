# How the system works, end to end

This page follows one upstream CVA6 commit from GitHub to a row on the
dashboard. Each step names the file that implements it.

```text
openhwfoundation/cva6 master
        │  daily poll (03:17 UTC) or manual dispatch
        ▼
[1] sync ─────────► isa084/cva6 master        (exact mirror, fast-forward only)
        │           isa084/cva6 ft-synthesis  (rebased: + tool fixes + synthesis files)
        ▼
[2] plan: did RTL change? which targets × technologies?
        ▼
[3] flow (self-hosted runner, one job per target × technology)
        │   run.sh ─► ORFS container ─► synthesis ─► floorplan ─► results.json
        ▼
[4] publish ─────► data branch (results)  ─► dashboard page ─► GitHub Pages
        ▼
isa084.github.io/cva6-synthesis/  ◄── linked from the isa084.github.io blog post
```

## 1. Fork mirror and `ft-synthesis`

The job `sync` in [`.github/workflows/track.yml`](../.github/workflows/track.yml) runs on a GitHub-hosted runner.

- **Mirror:** The job fast-forwards `isa084/cva6` `master` to upstream `master`.
  This branch never carries commits of its own. A non-fast-forward update fails.
  The repository variable `TRACKED_BRANCH` sets the tracked branch.
- **Rebase:** The job rebases `ft-synthesis` onto this mirror. That branch is
  upstream plus two kinds of commits:
  - Tool-compatibility RTL edits, when an open-source tool handles a construct
    incorrectly. [`docs/DEVIATIONS.md`](DEVIATIONS.md) documents each edit.
  - One commit that adds `synthesis.yaml` (targets, technology, SRAM mode) and
    this repository as the `synthesis/` submodule.
- **Push:** The job pushes only if the rebase is clean. It uses an SSH deploy
  key. This key can write to the fork and nothing else.

## 2. Plan

The step `Plan` in the job `sync` does this part.

- **Comparison:** The step compares the upstream commit with the newest commit
  in the `data` branch. If no RTL changed (`core common vendor corev_apu`), the
  step records the commit as skipped. Then nothing runs.
- **Matrix:** Otherwise, the step builds the job matrix (target × technology).
- **Manual dispatch:** In a manual dispatch, you can name a specific commit,
  targets, technologies, the mode (`fast` or `opt`), and `force`.

## 3. Flow run

The job `flow` runs on the self-hosted runners ([`runner/`](../runner/)). Each
runner does one job at a time. The repository variable `FLOW_PARALLEL` sets the
number of jobs that run at the same time.

| Step | What happens | Where |
|---|---|---|
| Checkout | The job checks out `ft-synthesis` of the fork. For an older commit, it checks out that commit and the synthesis files. | `track.yml` |
| Start | The flow records the provenance (upstream commit, flow version, RTL check). Then it starts a one-shot container. The container mounts CVA6 as read-only and one output directory as read-write. | [`run.sh`](../run.sh), [`docker-harness/`](../docker-harness/), [`container/compose.orfs.yaml`](../container/compose.orfs.yaml) |
| Configure | The flow expands the upstream `core/Flist.cva6`. It replaces the SRAM wrappers with macro versions. It writes an ORFS `config.mk`. | [`flow/orfs.py`](../flow/orfs.py), [`sram/rtl/`](../sram/rtl/) |
| Settings | The flow sets the shared design settings, the clock and NAND2 area for each technology, and the synthesis effort for each mode. | `orfs/cva6.mk`, `orfs/<tech>.mk`, `orfs/<mode>.mk`, `orfs/constraints.sdc` |
| Elaborate | Yosys reads the design with the built-in slang SystemVerilog reader. The flow removes the RVFI verification port. | ORFS, `orfs/canonicalize.tcl` |
| Synthesize | The flow maps the design to standard cells. The SRAMs stay as FakeRAM macros. | ORFS, `sram/views/<tech>/` |
| Floorplan | The flow sizes the die and the core. It also sets the macro footprint and runs static timing with OpenSTA. | ORFS |
| Results | The flow takes the area, kGE, fmax, worst slack, and macro counts from the ORFS metrics. It also adds the provenance. | [`flow/orfs.py`](../flow/orfs.py) → `results.json` |
| Check | The job searches the run directory for strings that identify the workstation. A deny-list outside the repository gives these strings. | `track.yml` |

All tools come from one pinned prebuilt image, `openroad/orfs`. The flow
references the image by digest. The flow builds nothing. The same `run.sh`
command reproduces any result on a local machine:

```bash
git clone --recursive -b ft-synthesis https://github.com/isa084/cva6.git
cd cva6 && ./synthesis/run.sh --target cv32a65x --tech asap7 --mode fast
```

## 4. Publish

The jobs `publish` and `pages` run on a GitHub-hosted runner.

- **Data:** The job stores the `results.json`, `metrics.json`, and `metadata.txt`
  of each run on the `data` branch under `runs/<commit>/<target>/<tech>/<mode>/`.
  It rebuilds `runs.json` from these files. Records are append-only.
- **Dashboard:** [`dashboard/generate.py`](../dashboard/generate.py) puts the records into
  [`dashboard/template.html`](../dashboard/template.html) and writes one static
  page. For the selected technology and target, the page shows the results
  table, the area breakdown, the timing paths, the trends and the history.
  The workflow [`dashboard.yml`](../.github/workflows/dashboard.yml) rebuilds
  the page from the `data` branch after a change to `dashboard/`, without a
  flow run.
- **Pages:** The job deploys the page to GitHub Pages
  (`isa084.github.io/cva6-synthesis/`).

## Further information

| Topic | File |
|---|---|
| The meaning of each number, run modes, and SRAM modes | [`docs/RESULTS.md`](RESULTS.md) |
| Differences from the upstream reference flow | [`docs/DEVIATIONS.md`](DEVIATIONS.md) |
| How to run and secure the self-hosted runners | [`runner/README.md`](../runner/README.md) |
| How to use the command line | [`README.md`](../README.md) |
| ORFS stages and variables | ORFS `docs/tutorials/FlowTutorial.md`, `docs/user/FlowVariables.md` |
