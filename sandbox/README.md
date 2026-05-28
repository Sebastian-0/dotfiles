# `claudesafe` -- sandboxed Claude Code

Run Claude Code in a Docker container with `--dangerously-skip-permissions`
so it can install packages, run scripts, and delete files without prompting
-- without the host being at risk.

## What it does

- Builds a layered image on top of `ubuntu:24.04` (or a custom base image
  you supply via `.claudesafe/`, see below) with Claude Code (via NodeSource
  apt), git, Python, and `iptables`/`ipset` for network filtering. The runtime
  user is `ubuntu` (UID 1000), remapped at build time to your host UID/GID so
  bind-mounts stay readable on both sides.
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
- Uses a separate named volume (`claude-gh`) for `~/.config/gh`, so a
  one-time `gh auth login` inside the sandbox persists across runs. Kept
  separate from `claude-home` so the two auth domains have independent
  lifecycles. The host's `~/.config/gh` is never mounted; the sandbox holds
  its own gh token, revocable separately. `--fresh` also resets this volume.

## Per-project customization

Drop a `.claudesafe/` folder in your project root. The sandbox is built in two
layers: **(1)** your base image, **(2)** the claudesafe layer
(`sandbox/Dockerfile`) that adds node + claude-code + the firewall on top and
remaps the `ubuntu` user to your host UID/GID. You supply layer 1; claudesafe
always owns layer 2. The base is assumed to be Debian/Ubuntu-derived with a
`ubuntu` user.

Three ways to supply the base:

- **Nothing** -- defaults to `ubuntu:24.04`.

- **`.claudesafe/Dockerfile`** -- a plain Dockerfile claudesafe builds and
  uses as the base. Just `FROM` whatever you want and install your tools; no
  `ARG BASE`, no sudoers, no firewall, no remap. Claudesafe adds those.

  ```dockerfile
  FROM ubuntu:24.04
  ARG ZIG_VERSION=0.16.0

  RUN apt-get update \
      && apt-get install -y --no-install-recommends curl xz-utils \
      && rm -rf /var/lib/apt/lists/*

  USER ubuntu
  RUN curl -fsSL https://ziglang.org/download/${ZIG_VERSION}/zig-x86_64-linux-${ZIG_VERSION}.tar.xz \
        | tar -xJ -C $HOME
  ENV PATH="/home/ubuntu/zig-x86_64-linux-${ZIG_VERSION}:${PATH}"
  ```

- **`.claudesafe/base-image.sh`** -- a script that prints the base image name
  on stdout. The last non-empty line of stdout is taken as the image name; any
  other output (progress logs, etc.) is ignored. Use this when the image has
  a dynamic tag or is produced by an external build:

  ```bash
  #!/bin/bash
  set -euo pipefail
  just ci::build-image >&2
  cat .cache/intui-build-image.txt
  ```

  The script runs with `cwd` set to the project root, so relative paths and
  project commands (like `just ...`) just work. If both `Dockerfile` and
  `base-image.sh` exist, `base-image.sh` wins.

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
- `~/.config/gh` (the sandbox uses its own `gh` identity in `claude-gh`)
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

For GitHub access, run `gh auth login` once inside the sandbox. The token
lands in the `claude-gh` named volume and is reused by every container that
shares it. The host's `~/.config/gh` is never mounted, so the sandbox token
is a distinct identity -- scope it down or revoke it independently of your
host token from GitHub's settings page.
