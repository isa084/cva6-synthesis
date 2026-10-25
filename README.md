# cva6-synthesis

This repository contains a generic synthesis flow and a raw timing-report flow
for compatible CVA6 checkouts. The flow runs in a container.

The CVA6 repository supplies one file that is specific to the fork. The file is
at the root of the CVA6 repository:

```text
synthesis.yaml
```

Include this repository as the submodule:

```text
<repo_home>/synthesis
```

The nested `docker-harness` submodule controls the container lifecycle.
`cva6-synthesis` owns only the CVA6 synthesis semantics.

## Five-minute quick start

Run these commands in the root directory of the CVA6 repository:

```bash
git submodule update --init --recursive
docker version
docker compose version
REFERENCE_TARGET=reference_target_name
CANDIDATE_TARGET=candidate_target_name
./synthesis/run.sh --build --mode quick --target "$REFERENCE_TARGET"
./synthesis/run.sh --mode quick --target "$CANDIDATE_TARGET"
./synthesis/compare.sh --mode quick "$REFERENCE_TARGET" "$CANDIDATE_TARGET"
```

Use the target keys that the `synthesis.yaml` file of the parent repository
defines. To get the mapped area and the OpenSTA timing, replace `quick` with
`full`. The flow writes the results below
`synthesis/runs/<target>/<mode>/latest-success/`. No persistent container
continues to run.

## Expected checkout

```text
repo_home/
├── synthesis.yaml
├── core/
├── corev_apu/
├── ...
└── synthesis/              # this repository
    ├── run.sh
    ├── flow/
    ├── tech/
    ├── container/
    └── docker-harness/     # nested submodule
```

The flow keeps the generated data in a directory that Git ignores. The
directory is inside the synthesis submodule:

```text
repo_home/synthesis/runs/<target>/<mode>/<timestamp>/
```

## Setup

Run this command in the root directory of the CVA6 repository:

```bash
git submodule update --init --recursive
```

The host needs Docker Engine and Docker Compose v2.24 or newer. The first run
builds the small CVA6-synthesis wrapper image automatically. When it is
necessary, the first run also pulls the prebuilt IIC-OSIC-TOOLS base image of
the wrapper image.

## Run

Run a target in quick structural mode without ABC or OpenSTA:

```bash
./synthesis/run.sh --build --mode quick --target TARGET
```

Run a target in full mode to get the mapped area and the pre-layout timing:

```bash
./synthesis/run.sh --build --mode full --target TARGET
```

If you do not use `--mode`, the default mode is `full`. Use `--build` after the
synthesis image or the flow changes. You do not need `--build` for every target
run.

Force a rebuild of the wrapper image:

```bash
./synthesis/run.sh --build --target TARGET
```

The container gets the complete CVA6 checkout at `/workspace/input`. This path
is read-only. The container also gets one new result directory at
`/workspace/output`. This path is read-write.

## Raw results

A successful run produces about these files:

```text
synthesis/runs/<target>/<mode>/<timestamp>/
├── metadata.txt
├── console.log
├── read-slang.rpt
├── synth-run-top.rpt
├── stat.rpt
├── ltp.rpt
└── synthesized-netlist.v       # quick mode
```

In full mode, `mapped-netlist.v` replaces `synthesized-netlist.v`. Full mode
also produces `dfflibmap.rpt`, `abc.rpt`, and `timing-top10.rpt`.

`latest` points to the newest attempt for that target. `latest-success` points
to the newest successful attempt for that target.

`ltp.rpt` is a structural report of the longest topological path. It is not a
timing report. `timing-top10.rpt` is the raw pre-layout OpenSTA report. The flow
makes this report after it maps the design to the Nangate45 technology. At this
time, the timing flow applies only the configured main clock. It does not claim
sign-off accuracy or post-route frequency accuracy.

## Compare targets

After both targets complete successfully, compare the runs in the same mode:

```bash
./synthesis/compare.sh --mode quick REFERENCE_TARGET CANDIDATE_TARGET
./synthesis/compare.sh --mode full REFERENCE_TARGET CANDIDATE_TARGET
./synthesis/compare.sh --mode full --timing-match 'INSTANCE_REGEX' \
    REFERENCE_TARGET CANDIDATE_TARGET
```

Quick mode compares the generic Yosys cell counts. It also identifies the two
structural longest-path reports. These are not technology area results or
timing results.

Full mode also compares the mapped cell area and the worst OpenSTA slack. It
identifies the top-ten timing reports. It can also search the candidate report
with a regular expression for instance names that the caller supplies. No match
means only that the instance is not in those ten paths.

The reported delta is `candidate - reference`. The command rejects runs that use
different CVA6 commits, synthesis configurations, modes, or flow commits. Commit
or freeze the RTL edits before you run both targets. This gives a clean
comparison.

## ORFS profile

If `synthesis.yaml` has `profile: orfs`, `run.sh` runs the OpenROAD-flow-scripts
flow from synthesis to floorplan. The flow runs in the pinned prebuilt
`openroad/orfs` image. The compose file for this image is
`container/compose.orfs.yaml`. The flow does not build an image. The command is:

```bash
./synthesis/run.sh --target TARGET [--tech asap7|nangate45] [--mode fast|opt]
```

The ORFS profile has two modes:

- `fast` (default): stops at the floorplan metrics step with the cheapest
  settings
- `opt`: uses the reference flow settings

Each target sets `sram:` to one of these values:

- `fakeram` (default): FakeRAM macros for every cache memory
- `flatten`: the flow implements the memories as flip-flops

The run directory is `synthesis/runs/<target>/<tech>/<mode>/<timestamp>/`. It
contains these items:

- `results.json` (area, kGate, fmax, worst slack, macro count, bit count,
  provenance)
- the raw ORFS metrics (`metrics.json`)
- the ORFS logs, reports, and results

The RTL must equal the upstream commit plus the tool-compatibility commits on
`ft-synthesis`. The variable `CVA6_UPSTREAM_REF` names the upstream commit. Its
default is `origin/master`. `metadata.txt` lists the tool-compatibility commits
as `rtl_patched`. If the RTL has uncommitted changes, the run fails.

`sram/generate.sh` generates the FakeRAM macro views in `sram/views` from
`sram/<tech>.cfg`.

## Adapt another CVA6 fork

Do not edit the flow for ordinary fork differences. Change only these items in
the `synthesis.yaml` file of the parent repository:

- synthesis target name
- CVA6 configuration name
- top module
- file list
- preprocessor defines
- additional top-level source files
- optional elaboration assertions
- main clock port and analysis period

The file list is still the main boundary for RTL integration.

## Tool layer

The wrapper image uses the pinned IIC-OSIC-TOOLS release `2026.07` as its base.
This release provides Yosys, the slang Yosys plugin, OpenSTA, and OpenROAD. The
wrapper adds only the generic flow files and the Nangate45 platform data that
this flow needs.

`docker-harness` stays generic and unchanged. This is on purpose.

## TODO: physical design

A later phase can add an optional OpenROAD place-and-route path and post-route
STA. Keep this separate from the current synthesis and pre-layout STA path. The
plan is to use the current raw mapped netlist and configuration as a clean
handoff point for this future work.
