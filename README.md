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
repo_home/synthesis/runs/<target>/<timestamp>/
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

Run the ZP target:

```bash
./synthesis/run.sh --target zp
```

Run the baseline target:

```bash
./synthesis/run.sh --target baseline
```

Force a wrapper-image rebuild:

```bash
./synthesis/run.sh --build --target zp
```

The container receives the complete CVA6 checkout read-only at
`/workspace/input` and one new result directory read-write at
`/workspace/output`.

## Raw results

A successful run produces approximately:

```text
synthesis/runs/<target>/<timestamp>/
├── metadata.txt
├── console.log
├── read-slang.rpt
├── synth-run-top.rpt
├── dfflibmap.rpt
├── abc.rpt
├── stat.rpt
├── ltp.rpt
├── mapped-netlist.v
└── timing-top10.rpt
```

`latest` points to the newest attempt and `latest-success` to the newest
successful attempt for that target.

`ltp.rpt` is a structural longest-topological-path report. It is not a timing
report. `timing-top10.rpt` is the raw pre-layout OpenSTA report after Nangate45
technology mapping. The timing flow currently applies only the configured main
clock; it does not claim sign-off or post-route frequency accuracy.

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
