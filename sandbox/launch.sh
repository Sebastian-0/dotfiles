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
            sed -n '3,20p' "$SCRIPT"
            exit 0
            ;;
        *)
            if [ -z "$TASK" ]; then TASK="$1"; else CLAUDE_ARGS+=("$1"); fi
            ;;
    esac
    shift
done

WORKSPACE_SRC="$PWD"
OVERLAY_DIR="$WORKSPACE_SRC/.claudesafe"
USER_DOCKERFILE="$OVERLAY_DIR/Dockerfile"
BASE_SCRIPT="$OVERLAY_DIR/base-image.sh"
PROJ_HASH="$(echo -n "$WORKSPACE_SRC" | sha1sum | head -c 12)"

NO_CACHE=""
if [ "$REBUILD" = "1" ]; then
    NO_CACHE="--no-cache"
fi

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
    --gpus all
    -v "$WORKSPACE_SRC:/workspace/project"
    -v "$VOLUME:$CONTAINER_HOME/.claude"
    -v "$GH_VOLUME:$CONTAINER_HOME/.config/gh"
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
