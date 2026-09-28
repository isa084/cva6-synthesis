# cva6-synthesis

Generic containerized synthesis and raw timing-report flow for compatible CVA6
checkouts.

The CVA6 repository supplies one fork-specific file at its root:

```text
synthesis.yaml
```

This repository is intended to be included as the submodule:

```text
<repo_home>/synthesis
```

The container lifecycle is delegated to the nested `docker-harness` submodule.
`cva6-synthesis` owns only CVA6 synthesis semantics.

## Five-minute quick start

From the CVA6 repository root:

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

Use target keys defined by the parent repository's `synthesis.yaml`. For mapped
area and OpenSTA timing, replace `quick` with `full`. Results are written below
`synthesis/runs/<target>/<mode>/latest-success/`; no persistent container is
left running.

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

Generated data is kept in an ignored directory inside the synthesis submodule:

```text
repo_home/synthesis/runs/<target>/<mode>/<timestamp>/
```

## Setup

From the CVA6 repository root:

```bash
git submodule update --init --recursive
```

Requirements on the host are Docker Engine and Docker Compose v2.24 or newer.
The first run builds the small CVA6-synthesis wrapper image automatically and
pulls its prebuilt IIC-OSIC-TOOLS base image when needed.

## Run

Run a target in quick structural mode without ABC or OpenSTA:

```bash
./synthesis/run.sh --build --mode quick --target TARGET
```

Run a target in full mapped-area and pre-layout timing mode:

```bash
./synthesis/run.sh --build --mode full --target TARGET
```

`full` is the default mode when `--mode` is omitted. `--build` is needed after
the synthesis image or flow changes; it is not needed for every target run.

Force a wrapper-image rebuild:

```bash
./synthesis/run.sh --build --target TARGET
```

The container receives the complete CVA6 checkout read-only at
`/workspace/input` and one new result directory read-write at
`/workspace/output`.

## Raw results

A successful run produces approximately:

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

Full mode replaces `synthesized-netlist.v` with `mapped-netlist.v` and also
produces `dfflibmap.rpt`, `abc.rpt`, and `timing-top10.rpt`.

`latest` points to the newest attempt and `latest-success` to the newest
successful attempt for that target.

`ltp.rpt` is a structural longest-topological-path report. It is not a timing
report. `timing-top10.rpt` is the raw pre-layout OpenSTA report after Nangate45
technology mapping. The timing flow currently applies only the configured main
clock; it does not claim sign-off or post-route frequency accuracy.

## Compare targets

After both targets have completed successfully, compare runs made in the same
mode:

```bash
./synthesis/compare.sh --mode quick REFERENCE_TARGET CANDIDATE_TARGET
./synthesis/compare.sh --mode full REFERENCE_TARGET CANDIDATE_TARGET
./synthesis/compare.sh --mode full --timing-match 'INSTANCE_REGEX' \
    REFERENCE_TARGET CANDIDATE_TARGET
```

Quick mode compares generic Yosys cell counts and identifies the two structural
longest-path reports. These are not technology area or timing results. Full
mode additionally compares mapped cell area and worst OpenSTA slack, identifies
the top-ten timing reports, and can search the candidate report using a
caller-supplied instance-name regular expression. No match means only that the
instance is absent from those ten paths.

The reported delta is `candidate - reference`. The command rejects runs made
from different CVA6 commits, synthesis configurations, modes or flow commits.
Commit or otherwise freeze RTL edits before running both targets for a clean
comparison.

## Adapting another CVA6 fork

Do not edit the flow for ordinary fork differences. Change only the parent
repository's `synthesis.yaml`:

- synthesis target name;
- CVA6 configuration name;
- top module;
- file list;
- preprocessor defines;
- additional top-level source files;
- optional elaboration assertions;
- main clock port and analysis period.

The file list remains the primary RTL integration boundary.

## Tool layer

The wrapper image is based on pinned IIC-OSIC-TOOLS release `2026.07`, which
provides Yosys, the slang Yosys plugin, OpenSTA and OpenROAD. The wrapper adds
only the generic flow files and Nangate45 platform data needed here.

`docker-harness` is intentionally left generic and unchanged.

## TODO: physical design

A later phase can add an optional OpenROAD place-and-route path and post-route
STA. Keep that separate from the current synthesis + pre-layout STA path. The
current raw mapped netlist and configuration are intended to be a clean handoff
point for that future work.
