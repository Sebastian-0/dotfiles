# `claudesafe` -- sandboxed Claude Code

Run Claude Code in a Docker container with `--dangerously-skip-permissions`
so it can install packages, run scripts, and delete files without prompting
-- without the host being at risk.

## What it does

- Builds a Debian-based image (`node:20`) with Claude Code, git, Python, and
  `iptables`/`ipset` for network filtering.
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
- Bind-mounts `~/.claude/.credentials.json` **read-only** so you don't have to
  re-authenticate in the container. Read-only prevents corruption / token
  refresh races; exfiltration is bounded by the firewall allowlist.
- Uses a named volume (`claude-home`) for history/cache/sessions. Shareable
  across parallel containers by default; `--fresh` gives an ephemeral one.

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

## Max-isolation mode

To keep your host Anthropic token off-limits from the container entirely,
comment out the `-v "$HOST_CREDS:...":ro"` block in `launch.sh`. You'll be
prompted to log in once per named volume; the login persists across runs.
