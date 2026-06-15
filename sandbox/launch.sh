#!/bin/bash
# `claudesafe` -- launch Claude Code in the sandbox container.
#
# Bind-mounts the current directory ($PWD) as /workspace/project inside the
# container. Claude runs with --dangerously-skip-permissions; the firewall
# + named-volume ~/.claude + container isolation bound the blast radius.
# Files Claude creates/edits land directly in $PWD on the host.
#
# Per-project customization:
#   .claudesafe/Dockerfile        # built first; becomes the BASE for the claudesafe layer
#   .claudesafe/base-image.sh     # prints a base image name on stdout (last line wins);
#                                 # use when the image is built externally or has a dynamic tag
#   .claudesafe/mounts            # extra -v lines, host:container[:options]
# Dockerfile and base-image.sh are mutually exclusive; base-image.sh wins if both exist.
#
# Usage:
#   claudesafe [task-name] [-- <claude args>]
#   claudesafe --shell               # drop to bash inside the container
#   claudesafe --fresh               # use a per-session ~/.claude volume
#   claudesafe --rebuild             # force rebuild of the image
#   claudesafe --unlock              # re-unlock the sandbox SSH key, then exit
set -euo pipefail

# Resolve the sandbox dir from the script's own path (works regardless of
# $PWD, which is important since this is symlinked onto $PATH).
SCRIPT="$(readlink -f "$0")"
SANDBOX_DIR="$(dirname "$SCRIPT")"

HOST_UID="$(id -u)"
HOST_GID="$(id -g)"
SANDBOX_USER="ubuntu"
CONTAINER_HOME="/home/$SANDBOX_USER"
VOLUME_BASE="claude-home"
GH_VOLUME_BASE="claude-gh"

TASK=""
SHELL_MODE=0
FRESH=0
REBUILD=0
UNLOCK=0
CLAUDE_ARGS=()

while [ $# -gt 0 ]; do
    case "$1" in
        --shell) SHELL_MODE=1 ;;
        --fresh) FRESH=1 ;;
        --rebuild) REBUILD=1 ;;
        --unlock) UNLOCK=1 ;;
        --)
            shift
            CLAUDE_ARGS=("$@")
            break
            ;;
        -h | --help)
            sed -n '3,21p' "$SCRIPT"
            exit 0
            ;;
        *)
            if [ -z "$TASK" ]; then TASK="$1"; else CLAUDE_ARGS+=("$1"); fi
            ;;
    esac
    shift
done

# --- Dedicated sandbox SSH key + its own ssh-agent ------------------------
# A sandbox-only key (separate from your personal one), passphrase-encrypted on
# the host and held in a dedicated, isolated agent. Only the agent socket is
# forwarded in -- key material never enters the container, so Claude can sign
# while unlocked but cannot exfiltrate it. Auto-expires after
# CLAUDESAFE_SSH_EXPIRY seconds (default 10h).
CLAUDE_SSH_KEY="$HOME/.ssh/claudesafe_ed25519"
CLAUDE_SSH_ENV="$HOME/.ssh/claudesafe-agent-env"
CLAUDE_SSH_EXPIRY="${CLAUDESAFE_SSH_EXPIRY:-36000}"

# Ensure the key exists and is loaded in the dedicated agent (generating and
# unlocking interactively as needed). On success leaves SSH_AUTH_SOCK pointing
# at that agent; returns non-zero if the key isn't available.
unlock_sandbox_ssh() {
    # Generate on first use (prompts for a passphrase).
    if [ ! -f "$CLAUDE_SSH_KEY" ]; then
        echo "[claudesafe] no sandbox SSH key found -- generating $CLAUDE_SSH_KEY"
        echo "[claudesafe] set a passphrase to encrypt it at rest:"
        if ssh-keygen -t ed25519 -C "claudesafe-sandbox" -f "$CLAUDE_SSH_KEY"; then
            echo "[claudesafe] ----------------------------------------------------------"
            echo "[claudesafe] Register this public key on GitHub (Settings > SSH keys):"
            cat "$CLAUDE_SSH_KEY.pub"
            echo "[claudesafe] ----------------------------------------------------------"
        else
            echo "[claudesafe] key generation skipped"
        fi
    fi

    # Talk ONLY to the dedicated agent -- the ambient $SSH_AUTH_SOCK may point
    # at your personal agent and would leak that key.
    unset SSH_AUTH_SOCK SSH_AGENT_PID
    if [ -f "$CLAUDE_SSH_ENV" ]; then
        . "$CLAUDE_SSH_ENV" > /dev/null 2>&1 || true
    fi

    # ssh-add -l: 0 = key loaded, 1 = agent up but no key, 2 = no agent.
    local rc=0
    ssh-add -l > /dev/null 2>&1 || rc=$?
    if [ "$rc" = "2" ]; then
        echo "[claudesafe] starting dedicated ssh-agent for the sandbox key..."
        ssh-agent -s > "$CLAUDE_SSH_ENV"
        chmod 600 "$CLAUDE_SSH_ENV"
        . "$CLAUDE_SSH_ENV" > /dev/null
        rc=1
    fi
    if [ "$rc" = "1" ] && [ -f "$CLAUDE_SSH_KEY" ]; then
        echo "[claudesafe] unlocking sandbox SSH key (auto-expires after ${CLAUDE_SSH_EXPIRY}s)..."
        ssh-add -t "$CLAUDE_SSH_EXPIRY" "$CLAUDE_SSH_KEY" || true
    fi

    # Success = the key is now loaded.
    ssh-add -l > /dev/null 2>&1 && [ -n "${SSH_AUTH_SOCK:-}" ] && [ -S "${SSH_AUTH_SOCK:-}" ]
}

# --unlock: re-load the key after the timeout without launching a container --
# re-enables git-over-SSH in an already-running session (same agent socket).
if [ "$UNLOCK" = "1" ]; then
    if unlock_sandbox_ssh; then
        echo "[claudesafe] sandbox SSH key is unlocked and ready"
        exit 0
    fi
    echo "[claudesafe] failed to unlock the sandbox SSH key" >&2
    exit 1
fi

WORKSPACE_SRC="$PWD"
OVERLAY_DIR="$WORKSPACE_SRC/.claudesafe"
USER_DOCKERFILE="$OVERLAY_DIR/Dockerfile"
BASE_SCRIPT="$OVERLAY_DIR/base-image.sh"
PROJ_HASH="$(echo -n "$WORKSPACE_SRC" | sha1sum | head -c 12)"

NO_CACHE=""
if [ "$REBUILD" = "1" ]; then
    NO_CACHE="--no-cache"
fi

export DOCKER_BUILDKIT=1

# Step 1: resolve the BASE image. Three sources, in priority order:
#   - .claudesafe/base-image.sh: last line of stdout is the image name. Lets
#     the project compute a dynamic tag (e.g. read a hash from a generated
#     file) or trigger an external build (e.g. `just ci::build-image`).
#   - .claudesafe/Dockerfile: built locally; the resulting image is the base.
#   - neither: default to ubuntu:24.04.
# The claudesafe layer (sandbox/Dockerfile) is then built on top of BASE.
if [ -f "$BASE_SCRIPT" ]; then
    echo "[claudesafe] resolving base image via $BASE_SCRIPT..."
    BASE_OUTPUT="$(cd "$WORKSPACE_SRC" && bash "$BASE_SCRIPT")"
    BASE="$(printf '%s\n' "$BASE_OUTPUT" | awk 'NF{line=$0} END{print line}')"
    if [ -z "$BASE" ]; then
        echo "[claudesafe] error: base-image.sh produced no output" >&2
        exit 1
    fi
    echo "[claudesafe] base image: $BASE"
elif [ -f "$USER_DOCKERFILE" ]; then
    BASE="claude-sandbox-userbase:${PROJ_HASH}-uid${HOST_UID}"
    echo "[claudesafe] building user base $BASE from $USER_DOCKERFILE..."
    docker build $NO_CACHE \
        -f "$USER_DOCKERFILE" \
        -t "$BASE" \
        "$WORKSPACE_SRC"
else
    BASE="ubuntu:24.04"
fi

# Step 2: build the claudesafe layer (sandbox/Dockerfile) on top of BASE.
# Tagged per-project + per-UID so different projects don't collide and hosts
# with different user IDs share nothing.
if [ -f "$USER_DOCKERFILE" ] || [ -f "$BASE_SCRIPT" ]; then
    RUN_IMAGE="claude-sandbox:${PROJ_HASH}-uid${HOST_UID}"
else
    RUN_IMAGE="claude-sandbox:default-uid${HOST_UID}"
fi
echo "[claudesafe] building claudesafe layer $RUN_IMAGE on top of $BASE..."
docker build $NO_CACHE \
    --build-arg "BASE=$BASE" \
    --build-arg "HOST_UID=$HOST_UID" \
    --build-arg "HOST_GID=$HOST_GID" \
    --build-arg "SANDBOX_USER=$SANDBOX_USER" \
    -t "$RUN_IMAGE" \
    "$SANDBOX_DIR"

echo "[claudesafe] mounting $WORKSPACE_SRC as /workspace/project (changes hit the real folder)"

# Named volumes for ~/.claude and ~/.config/gh. --fresh gives a unique volume
# per session so state doesn't persist or collide with parallel containers.
# The gh volume is kept separate from claude-home so wiping one doesn't lose
# the other (auth tokens vs. session/cache state have independent lifecycles).
if [ "$FRESH" = "1" ]; then
    STAMP="$(date +%s)-$$"
    VOLUME="${VOLUME_BASE}-${STAMP}"
    GH_VOLUME="${GH_VOLUME_BASE}-${STAMP}"
    echo "[claudesafe] fresh mode -- using ephemeral volumes $VOLUME, $GH_VOLUME"
else
    VOLUME="$VOLUME_BASE"
    GH_VOLUME="$GH_VOLUME_BASE"
fi

DOCKER_ARGS=(
    --rm -it
    --cap-add=NET_ADMIN
    --cap-add=NET_RAW
    -v "$WORKSPACE_SRC:/workspace/project"
    -v "$VOLUME:$CONTAINER_HOME/.claude"
    -v "$GH_VOLUME:$CONTAINER_HOME/.config/gh"
    -v "$SANDBOX_DIR/allowlist.txt:/etc/allowlist.txt:ro"
    -e "TERM=${TERM:-xterm-256color}"
    -e "SANDBOX_TASK=${TASK:-}"
)

# Only request GPUs when Docker actually has the nvidia container runtime
if docker info --format '{{json .Runtimes}}' 2> /dev/null | grep -q nvidia; then
    echo "[claudesafe] nvidia runtime detected -- enabling --gpus all"
    DOCKER_ARGS+=(--gpus all)
else
    echo "[claudesafe] no nvidia runtime -- starting without GPU access"
fi

# Mount main git folder if we are in a worktree. Note that the main worktree
# is mounted on the path where it exists on the host to make the .git symlink happy
if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    GIT_COMMON_DIR="$(readlink -f "$(git rev-parse --git-common-dir)")"
    case "$GIT_COMMON_DIR" in
        "$WORKSPACE_SRC" | "$WORKSPACE_SRC"/*) ;;
        *)
            echo "[claudesafe] git worktree detected -- mounting shared git dir $GIT_COMMON_DIR"
            DOCKER_ARGS+=(-v "$GIT_COMMON_DIR:$GIT_COMMON_DIR")
            ;;
    esac
fi

# Mount individual host ~/.claude items read-only into /workspace/claude-host/.
# bootstrap.sh links these into the named volume at $HOME/.claude.
# Docker follows host-side symlinks at mount time, so ~/.claude/skills (a
# symlink to the dotfiles ai_shared/skills) resolves to the real directory.
for item in settings.json CLAUDE.md statusline-command.sh skills plugins agents commands; do
    src="$HOME/.claude/$item"
    if [ -e "$src" ]; then
        DOCKER_ARGS+=(-v "$src:/workspace/claude-host/$item:ro")
    fi
done

# Project-level extra mounts: $PWD/.claudesafe/mounts, one host:container[:opts]
# per line. Lines starting with '#' are comments. ~ and $VARS are expanded.
MOUNTS_FILE="$OVERLAY_DIR/mounts"
if [ -f "$MOUNTS_FILE" ]; then
    while IFS= read -r raw || [ -n "$raw" ]; do
        line="${raw%%#*}"
        line="$(printf '%s' "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        [ -z "$line" ] && continue
        # eval to expand ~ and $VARS; the file is user-controlled local config.
        expanded="$(eval printf '%s' "\"$line\"")"
        echo "[claudesafe] extra mount: $expanded"
        DOCKER_ARGS+=(-v "$expanded")
    done < "$MOUNTS_FILE"
fi

# Unlock the sandbox key and forward only its agent socket (key stays on host).
if unlock_sandbox_ssh; then
    echo "[claudesafe] forwarding sandbox ssh-agent ($SSH_AUTH_SOCK)"
    DOCKER_ARGS+=(
        -v "$SSH_AUTH_SOCK:/ssh-agent.sock"
        -e "SSH_AUTH_SOCK=/ssh-agent.sock"
    )
else
    echo "[claudesafe] sandbox SSH key unavailable -- continuing without git-over-SSH"
fi

# Credentials live in the claude-home named volume (written by `claude login`
# inside the container) and are shared across all containers using that volume.
# We deliberately do NOT bind-mount the host's ~/.claude/.credentials.json so
# the host token stays out of the container's reach.
#
# Same pattern for GitHub: the claude-gh volume holds ~/.config/gh (written by
# `gh auth login` inside the container). The host's gh config is never
# exposed; the sandbox's gh token is its own identity, revocable separately.

# Pass API key through if set (overrides OAuth).
if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
    DOCKER_ARGS+=(-e "ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY")
fi

if [ "$SHELL_MODE" = "1" ]; then
    DOCKER_ARGS+=(-e "SANDBOX_SHELL=1")
fi

echo "[claudesafe] starting container ($RUN_IMAGE)..."
exec docker run "${DOCKER_ARGS[@]}" "$RUN_IMAGE" "${CLAUDE_ARGS[@]}"
