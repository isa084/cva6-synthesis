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

`.github/workflows/track.yml`, job `sync`, on a GitHub-hosted runner.

- **Mirror:** `isa084/cva6` `master` is fast-forwarded to upstream `master`.
  It never carries commits of its own, and a non-fast-forward update fails.
  The tracked branch is the repository variable `TRACKED_BRANCH`.
- **Rebase:** `ft-synthesis` is rebased onto it. That branch is upstream plus
  two kinds of commits:
  - tool-compatibility RTL edits, when an open-source tool mishandles a
    construct; each is documented in `docs/DEVIATIONS.md`;
  - one commit adding `synthesis.yaml` (targets, technology, SRAM mode) and
    this repository as the `synthesis/` submodule.
- **Push:** happens only if the rebase is clean. It uses an SSH deploy key
  that can write to the fork and nothing else.

## 2. Plan

Job `sync`, step `Plan`.

- **Comparison:** the upstream commit is compared with the newest one in the
  `data` branch. If no RTL changed (`core common vendor corev_apu`), it is
  recorded as skipped and nothing runs.
- **Matrix:** otherwise the job matrix is built (target × technology).
- **Manual dispatch:** can name a specific commit, targets, technologies,
  mode (`fast` or `opt`) and `force`.

## 3. Flow run

Job `flow`, on the self-hosted runner (`runner/`), one job at a time.

| Step | What happens | Where |
|---|---|---|
| Checkout | `ft-synthesis` of the fork; for an older commit, that commit plus the synthesis files. | `track.yml` |
| Start | Records provenance (upstream commit, flow version, RTL check) and starts a one-shot container: CVA6 mounted read-only, one output directory read-write. | `run.sh`, `docker-harness/`, `container/compose.orfs.yaml` |
| Configure | Expands upstream `core/Flist.cva6`, swaps the SRAM wrappers for macro versions, writes an ORFS `config.mk`. | `flow/orfs.py`, `sram/rtl/` |
| Settings | Shared design settings, per-technology clock and NAND2 area, per-mode synthesis effort. | `orfs/cva6.mk`, `orfs/<tech>.mk`, `orfs/<mode>.mk`, `orfs/constraints.sdc` |
| Elaborate | Yosys with the built-in slang SystemVerilog reader; the RVFI verification port is removed. | ORFS, `orfs/canonicalize.tcl` |
| Synthesise | Mapping to standard cells; SRAMs stay as FakeRAM macros. | ORFS, `sram/views/<tech>/` |
| Floorplan | Die and core sizing, macro footprint, static timing (OpenSTA). | ORFS |
| Results | Area, kGE, fmax, worst slack and macro counts from the ORFS metrics, plus provenance. | `flow/orfs.py` → `results.json` |
| Check | The run directory is searched for workstation-identifying strings (a deny-list kept outside the repository). | `track.yml` |

The tools come from one pinned prebuilt image, `openroad/orfs`, referenced by
digest; nothing is built. The same `run.sh` command reproduces any result
locally:

```bash
git clone --recursive -b ft-synthesis https://github.com/isa084/cva6.git
cd cva6 && ./synthesis/run.sh --target cv32a65x --tech asap7 --mode fast
```

## 4. Publish

Jobs `publish` and `pages`, on a GitHub-hosted runner.

- **Data:** each run's `results.json`, `metrics.json` and `metadata.txt` are
  stored on the `data` branch under `runs/<commit>/<target>/<tech>/<mode>/`,
  and `runs.json` is rebuilt from them. Records are append-only.
- **Dashboard:** `dashboard/generate.py` writes one static page with the values
  in it: a summary table per technology and a 10-commit history per target.
- **Pages:** the page is deployed to GitHub Pages
  (`isa084.github.io/cva6-synthesis/`).

## Further reading

| Topic | File |
|---|---|
| What each number means, run modes, SRAM modes | `docs/RESULTS.md` |
| Differences from the upstream reference flow | `docs/DEVIATIONS.md` |
| Running and securing the self-hosted runner | `runner/README.md` |
| Command-line usage | `README.md` |
| ORFS stages and variables | ORFS `docs/tutorials/FlowTutorial.md`, `docs/user/FlowVariables.md` |
