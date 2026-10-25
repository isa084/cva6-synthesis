# Self-hosted runner

This is a containerized GitHub Actions runner for
`.github/workflows/track.yml`. It uses the prebuilt
`ghcr.io/actions/actions-runner` image. `compose.yaml` pins this image by
digest. This setup builds nothing.

## Start

You need these items:

- Docker with Compose v2
- the GitHub CLI, authenticated with admin rights on the repository
- a writable directory `/srv/cva6-runner` that you share with Docker (Docker
  Desktop: Settings, Resources, File sharing)
- a deny-list file

To start the runner, run this command:

```bash
REPO=owner/name ./runner/start.sh
```

`start.sh` requests a registration token with `gh`. Then it runs
`docker compose up -d`. The container mounts `/var/run/docker.sock`. Docker
Desktop maps this socket to its engine socket. The runner has the name
`cva6-synth-runner` and the label `cva6-synthesis`.

The commits contain nothing that is host-specific. The values for the
repository, the token, and the CPU count are environment variables. You set them
at start time.

To stop the runner, run `docker rm -f cva6-synth-runner`. The runner then shows
as offline until the next start.

The deny-list is a text file with one string on each line (user name, host name,
home path). The file stays outside any repository. The default file is
`~/.config/cva6-synthesis/denylist`. To use another file, set `DENYLIST`.
Docker mounts the file read-only at `/etc/cva6-denylist`. The workflow fails
when a run directory contains any string of the file.

## Start at login (optional)

1. Create `~/.config/systemd/user/cva6-runner.service` with this content:

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

2. Run `systemctl --user enable --now cva6-runner`.

## Layout and limits

- The container hostname and the runner name are generic. The runner home is
  `/home/runner`. The work directory is `/srv/cva6-runner/_work`. The container
  mounts it at the same path that the host uses. This lets the tool containers
  that start through the Docker socket mount the job files.
- Jobs reach Docker through the mounted socket. This socket is root-equivalent
  on the Docker host. These three measures keep this acceptable:
  - registration to one repository only
  - triggers from `schedule` and `workflow_dispatch` only
  - the approval requirement for fork pull-request workflows
- The container removes the registration token from the environment before jobs
  start.
- Inside containers, the socket of Docker Desktop is root-only. `compose.yaml`
  gives the socket to the `docker` group of the image. Do not add the container
  user to group 0. The virtiofs daemon of Docker Desktop crashed after a
  directory with group 0 was created on the `/srv/cva6-runner` share. After the
  crash, the engine hangs until you restart Docker Desktop.
- CPU: The runner container can use only half of the cores. The flow itself runs
  ORFS with half of the cores (`NUM_CORES` in `flow/orfs.py`). No cgroup limits
  the tool containers.
