#!/bin/bash
# `claudesafe` -- launch Claude Code in the sandbox container.
#
# Bind-mounts the current directory ($PWD) as /workspace/project inside the
# container. Claude runs with --dangerously-skip-permissions; the firewall
# + named-volume ~/.claude + container isolation bound the blast radius.
# Files Claude creates/edits land directly in $PWD on the host.
#
# Usage:
#   claudesafe [task-name] [-- <claude args>]
#   claudesafe --shell               # drop to bash inside the container
#   claudesafe --fresh               # use a per-session ~/.claude volume
#   claudesafe --rebuild             # force rebuild of the image
set -euo pipefail

# Resolve the sandbox dir from the script's own path (works regardless of
# $PWD, which is important since this is symlinked onto $PATH).
SCRIPT="$(readlink -f "$0")"
SANDBOX_DIR="$(dirname "$SCRIPT")"

HOST_UID="$(id -u)"
HOST_GID="$(id -g)"
# Tag per-UID so hosts with different user IDs don't collide on a shared image.
IMAGE="claude-sandbox:uid${HOST_UID}"
VOLUME_BASE="claude-home"

TASK=""
SHELL_MODE=0
FRESH=0
REBUILD=0
CLAUDE_ARGS=()

while [ $# -gt 0 ]; do
    case "$1" in
        --shell) SHELL_MODE=1 ;;
        --fresh) FRESH=1 ;;
        --rebuild) REBUILD=1 ;;
        --)
            shift
            CLAUDE_ARGS=("$@")
            break
            ;;
        -h | --help)
            sed -n '3,12p' "$SCRIPT"
            exit 0
            ;;
        *)
            if [ -z "$TASK" ]; then TASK="$1"; else CLAUDE_ARGS+=("$1"); fi
            ;;
    esac
    shift
done

# Build the image if missing or explicitly asked.
if [ "$REBUILD" = "1" ] || ! docker image inspect "$IMAGE" > /dev/null 2>&1; then
    echo "[claudesafe] building image $IMAGE (HOST_UID=$HOST_UID HOST_GID=$HOST_GID)..."
    docker build --pull \
        --build-arg "HOST_UID=$HOST_UID" \
        --build-arg "HOST_GID=$HOST_GID" \
        -t "$IMAGE" "$SANDBOX_DIR"
fi

WORKSPACE_SRC="$PWD"
echo "[claudesafe] mounting $WORKSPACE_SRC as /workspace/project (changes hit the real folder)"

# Named volume for ~/.claude. --fresh gives a unique volume per session so
# state doesn't persist or collide with parallel containers.
if [ "$FRESH" = "1" ]; then
    VOLUME="${VOLUME_BASE}-$(date +%s)-$$"
    echo "[claudesafe] fresh mode -- using ephemeral volume $VOLUME"
else
    VOLUME="$VOLUME_BASE"
fi

DOCKER_ARGS=(
    --rm -it
    --cap-add=NET_ADMIN
    --cap-add=NET_RAW
    -v "$WORKSPACE_SRC:/workspace/project"
    -v "$VOLUME:/home/node/.claude"
    -v "$SANDBOX_DIR/allowlist.txt:/etc/allowlist.txt:ro"
    -e "TERM=${TERM:-xterm-256color}"
    -e "SANDBOX_TASK=${TASK:-}"
)

# Mount individual host ~/.claude items read-only into /workspace/claude-host/.
# bootstrap.sh links these into the named volume at /home/node/.claude.
# Docker follows host-side symlinks at mount time, so ~/.claude/skills (a
# symlink to the dotfiles ai_shared/skills) resolves to the real directory.
for item in settings.json CLAUDE.md statusline-command.sh skills plugins agents commands; do
    src="$HOME/.claude/$item"
    if [ -e "$src" ]; then
        DOCKER_ARGS+=(-v "$src:/workspace/claude-host/$item:ro")
    fi
done

# Credentials live in the claude-home named volume (written by `claude login`
# inside the container) and are shared across all containers using that volume.
# We deliberately do NOT bind-mount the host's ~/.claude/.credentials.json so
# the host token stays out of the container's reach.

# Pass API key through if set (overrides OAuth).
if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
    DOCKER_ARGS+=(-e "ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY")
fi

if [ "$SHELL_MODE" = "1" ]; then
    DOCKER_ARGS+=(-e "SANDBOX_SHELL=1")
fi

echo "[claudesafe] starting container..."
exec docker run "${DOCKER_ARGS[@]}" "$IMAGE" "${CLAUDE_ARGS[@]}"
