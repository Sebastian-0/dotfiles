#!/bin/bash
# `claudesafe` -- launch Claude Code in the sandbox container.
#
# Bind-mounts the current directory ($PWD) as /workspace/project inside the
# container. Claude runs with --dangerously-skip-permissions; the firewall
# + named-volume ~/.claude + container isolation bound the blast radius.
# Files Claude creates/edits land directly in $PWD on the host.
#
# Per-project customization:
#   .claudesafe/Dockerfile        # extends the base; ARG BASE is set for FROM
#   .claudesafe/mounts            # extra -v lines, host:container[:options]
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
SANDBOX_USER="ubuntu"
CONTAINER_HOME="/home/$SANDBOX_USER"
# Tag per-UID so hosts with different user IDs don't collide on a shared image.
BASE_IMAGE="claude-sandbox-base:uid${HOST_UID}"
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
            sed -n '3,17p' "$SCRIPT"
            exit 0
            ;;
        *)
            if [ -z "$TASK" ]; then TASK="$1"; else CLAUDE_ARGS+=("$1"); fi
            ;;
    esac
    shift
done

WORKSPACE_SRC="$PWD"

# Build the base image if missing or explicitly asked.
if [ "$REBUILD" = "1" ] || ! docker image inspect "$BASE_IMAGE" > /dev/null 2>&1; then
    echo "[claudesafe] building base image $BASE_IMAGE (HOST_UID=$HOST_UID HOST_GID=$HOST_GID)..."
    docker build --pull \
        --build-arg "HOST_UID=$HOST_UID" \
        --build-arg "HOST_GID=$HOST_GID" \
        --build-arg "SANDBOX_USER=$SANDBOX_USER" \
        -t "$BASE_IMAGE" "$SANDBOX_DIR"
fi

# Project-level overlay: $PWD/.claudesafe/Dockerfile FROM ${BASE} adds packages,
# custom installers, or swaps the base image entirely. Built every run; docker
# layer cache makes this cheap when nothing changed.
OVERLAY_DIR="$WORKSPACE_SRC/.claudesafe"
OVERLAY_DOCKERFILE="$OVERLAY_DIR/Dockerfile"
RUN_IMAGE="$BASE_IMAGE"
if [ -f "$OVERLAY_DOCKERFILE" ]; then
    PROJ_HASH="$(echo -n "$WORKSPACE_SRC" | sha1sum | head -c 12)"
    RUN_IMAGE="claude-sandbox-project:${PROJ_HASH}-uid${HOST_UID}"
    echo "[claudesafe] building overlay $RUN_IMAGE from $OVERLAY_DOCKERFILE..."
    docker build \
        --build-arg "BASE=$BASE_IMAGE" \
        --build-arg "HOST_UID=$HOST_UID" \
        --build-arg "HOST_GID=$HOST_GID" \
        --build-arg "SANDBOX_USER=$SANDBOX_USER" \
        -f "$OVERLAY_DOCKERFILE" \
        -t "$RUN_IMAGE" \
        "$OVERLAY_DIR"
fi

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
    -v "$VOLUME:$CONTAINER_HOME/.claude"
    -v "$SANDBOX_DIR/allowlist.txt:/etc/allowlist.txt:ro"
    -e "TERM=${TERM:-xterm-256color}"
    -e "SANDBOX_TASK=${TASK:-}"
)

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

echo "[claudesafe] starting container ($RUN_IMAGE)..."
exec docker run "${DOCKER_ARGS[@]}" "$RUN_IMAGE" "${CLAUDE_ARGS[@]}"
