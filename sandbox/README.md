# `claudesafe` -- sandboxed Claude Code

Run Claude Code in a Docker container with `--dangerously-skip-permissions`
so it can install packages, run scripts, and delete files without prompting
-- without the host being at risk.

## What it does

- Builds an Ubuntu-based image (`ubuntu:24.04`) with Claude Code (via
  NodeSource apt), git, Python, and `iptables`/`ipset` for network filtering.
  The runtime user is `ubuntu` (UID 1000), remapped at build time to your
  host UID/GID so bind-mounts stay readable on both sides.
- Applies a default-deny firewall at container start, allowlisting only the
  domains in `allowlist.txt` (plus a hardcoded baseline: `api.anthropic.com`,
  npm, GitHub's published IP ranges, etc.).
- **Bind-mounts `$PWD` as `/workspace/project`** -- Claude's edits land
  directly in the current folder on the host. No worktree, no copy. Works
  whether or not the folder is a git repo. If you want a throwaway copy,
  make one yourself (`cp -r`, `git worktree`, etc.) and `cd` there first.
- Mounts individual items from your host `~/.claude/` (settings.json,
  CLAUDE.md, statusline-command.sh, skills, plugins, agents, commands)
  read-only at `/workspace/claude-host/` and symlinks them into the
  container's `~/.claude/` so behavior matches your host Claude.
- Uses a named volume (`claude-home`) for history/cache/sessions **and**
  credentials. The host's `~/.claude/.credentials.json` is never mounted --
  log in once with `claude login` inside the container and the token persists
  in the volume, shared across every container using it. `--fresh` gives an
  ephemeral volume (and a fresh login).

## Per-project customization

Drop a `.claudesafe/` folder in your project root to extend the sandbox for
that project only:

- **`.claudesafe/Dockerfile`** -- extends the base. The build passes a
  `BASE` build-arg that points at the per-UID base image, so:

  ```dockerfile
  ARG BASE
  FROM ${BASE}

  ARG SANDBOX_USER
  ARG ZIG_VERSION=0.16.0

  USER root
  RUN apt-get update && apt-get install -y --no-install-recommends xz-utils

  USER ${SANDBOX_USER}
  RUN curl -fsSL https://ziglang.org/download/${ZIG_VERSION}/zig-x86_64-linux-${ZIG_VERSION}.tar.xz \
        | tar -xJ -C $HOME
  ENV PATH="/home/${SANDBOX_USER}/zig-x86_64-linux-${ZIG_VERSION}:${PATH}"
  ```

  If you wanna completely replace the base image, e.g. to use a CUDA image, ignore the `BASE`
  arg and `FROM` whatever you want, but copy the firewall + entrypoint scripts over and re-run
  `remap-user.sh` so the `ubuntu` user matches the host UID:

  ```dockerfile
  FROM nvidia/cuda:12.4.1-runtime-ubuntu24.04
  ARG BASE
  ARG HOST_UID
  ARG HOST_GID
  ARG SANDBOX_USER
  COPY --from=${BASE} \
       /usr/local/bin/init-firewall.sh \
       /usr/local/bin/bootstrap.sh \
       /usr/local/bin/remap-user.sh \
       /usr/local/bin/
  # ... install nodejs, claude-code, sudoers ...
  RUN /usr/local/bin/remap-user.sh "$SANDBOX_USER" "$HOST_UID" "$HOST_GID"
  USER ${SANDBOX_USER}
  ENTRYPOINT ["/usr/local/bin/bootstrap.sh"]
  ```

- **`.claudesafe/mounts`** -- one extra `-v` per line, comments with `#`.
  `~` and `$VARS` are expanded.

  ```
  # build cache outside the project
  ~/.cache/ccache:/home/ubuntu/.cache/ccache
  $HOME/models:/models:ro
  ```

## Install

```bash
./install.sh            # symlinks launch.sh to ~/.local/bin/claudesafe
```

Open a new shell (or `source ~/.bashrc`). The first `claudesafe` invocation
triggers the image build (a few minutes; cached afterwards).

## Usage

```bash
claudesafe                           # interactive Claude in $PWD
claudesafe my-task                   # tag the session (used as SANDBOX_TASK env var)
claudesafe --shell                   # drop to bash inside the container
claudesafe --fresh                   # ephemeral ~/.claude volume
claudesafe --rebuild                 # rebuild the image
claudesafe -- -p "do the thing"      # pass args through to `claude`
```

## Customizing the allowlist

Edit `allowlist.txt`. One domain per line. No rebuild needed -- the file is
mounted fresh each run.

If you need broader access for a specific session only, drop additional
domains into `allowlist.txt` and run `claudesafe`; revert the file after.

## What's NOT exposed to the container

- `~/.claude/history.jsonl` (conversation PII)
- `~/.claude/projects/`, `sessions/`, `cache/`, `backups/`, `file-history/`
- Anything outside `$PWD` and the read-only claude-host mounts
- The Docker socket (no docker-in-docker)

Note: `$PWD` is mounted **read-write**. Claude can create, modify, and delete
files in the current folder. Everything outside it is unreachable.

## Authentication

The host's Anthropic token is never exposed to the container. On first run
(or after `--fresh`), Claude will prompt you to log in; the credentials land
in the `claude-home` named volume at `/home/node/.claude/.credentials.json`
and are reused by every subsequent container sharing that volume.

If you'd rather pass an API key instead, export `ANTHROPIC_API_KEY` on the
host before running `claudesafe` -- it's forwarded into the container and
overrides the OAuth flow.
