# Self-hosted runner

A containerised GitHub Actions runner for `.github/workflows/track.yml`. It
uses the prebuilt `ghcr.io/actions/actions-runner` image, pinned by digest in
`compose.yaml`; nothing is built.

## Start

Requirements: Docker with Compose v2, the GitHub CLI authenticated with admin
rights on the repository, `/srv/cva6-runner` writable and shared with Docker
(Docker Desktop: Settings, Resources, File sharing), and a deny-list file.

```bash
REPO=owner/name ./runner/start.sh
```

`start.sh` requests a registration token with `gh` and runs
`docker compose up -d`. The container mounts `/var/run/docker.sock`, which
Docker Desktop maps to its engine socket. The runner is
named `cva6-synth-runner` with label `cva6-synthesis`. Nothing host-specific is
committed: repository, token and CPU count are environment
variables set at start time. Stop with `docker compose -f runner/compose.yaml down`
(the runner then shows as offline until the next start).

The deny-list is a text file with one string per line (user name, host name,
home path) kept outside any repository. It defaults to
`~/.config/cva6-synthesis/denylist`; set `DENYLIST` to use another file. It is
mounted read-only at `/etc/cva6-denylist`, and the workflow fails when a run
directory contains any of its strings.

## Start at login (optional)

Create `~/.config/systemd/user/cva6-runner.service`, then run
`systemctl --user enable --now cva6-runner`:

```ini
[Unit]
Description=CVA6 synthesis runner

[Service]
Type=oneshot
RemainAfterExit=yes
Environment=REPO=owner/name
ExecStart=%h/cva6-synthesis/runner/start.sh

[Install]
WantedBy=default.target
```

## Layout and limits

- Container hostname and runner name are generic; the runner home is
  `/home/runner`; the work directory is `/srv/cva6-runner/_work`, mounted at
  the same path in the container and on the host so tool containers started
  through the Docker socket can mount job files.
- Jobs reach Docker through the mounted socket, which is root-equivalent on
  the Docker host. Registration to one repository only, triggers limited to
  `schedule` and `workflow_dispatch`, and the approval requirement for fork
  pull-request workflows are what keep this acceptable.
- The registration token is removed from the environment before jobs start.
- Docker Desktop's socket is root-only inside containers; `compose.yaml`
  gives it to the image's `docker` group. Do not add the container user to
  group 0: creating a directory on the `/srv/cva6-runner` share with group 0
  was observed to crash Docker Desktop's virtiofs daemon, after which the
  engine hangs until Docker Desktop is restarted.
- CPU: the runner container is limited to half the cores. The flow itself runs
  ORFS with half the cores (`NUM_CORES` in `flow/orfs.py`); tool containers are
  not limited by cgroup.
