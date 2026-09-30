#!/bin/bash
# SessionStart hook: replaces this checkout's ~/.claude/projects/<slug>/memory
# with a symlink into $CLAUDE_MEMORY_STORE/<origin url>, so every clone and
# worktree of a repo, on any machine, shares one memory.
# Stdout is added to the session's context, so everything goes to stderr.
set -euo pipefail

STORE_ROOT="${CLAUDE_MEMORY_STORE:-$HOME/.local/share/claude-memory}"

warn() {
    echo "claude-memory-link: $*" >&2
}

# git@github.com:a/b.git, https://user@github.com/a/b and ssh://git@github.com/a/b
# all become github.com/a/b.
repo_key() {
    local url
    url="$(git -C "$1" remote get-url origin 2> /dev/null)" || return 1
    url="${url#*://}"
    url="${url#*@}"
    url="${url%.git}"
    url="${url%/}"
    case "$url" in
        *:*/*) url="${url/://}" ;;
    esac
    case "$url" in
        "" | *..*) return 1 ;;
    esac
    echo "$url"
}

# MEMORY.md gains the lines the store lacks; any other differing file aborts
# before anything is moved.
merge_into_store() {
    local src="$1"
    local dst="$2"
    local f
    local name
    for f in "$src"/*; do
        name="$(basename "$f")"
        if [ "$name" != MEMORY.md ] && [ -e "$dst/$name" ] && ! cmp -s "$f" "$dst/$name"; then
            warn "$name differs between $src and $dst; merge by hand"
            return 1
        fi
    done
    for f in "$src"/*; do
        name="$(basename "$f")"
        if [ "$name" = MEMORY.md ] && [ -e "$dst/MEMORY.md" ]; then
            grep -vxFf "$dst/MEMORY.md" "$f" >> "$dst/MEMORY.md" || true
            rm "$f"
        elif [ -e "$dst/$name" ]; then
            rm "$f"
        else
            mv "$f" "$dst/"
        fi
    done
}

main() {
    local project="${CLAUDE_PROJECT_DIR:-$PWD}"
    local key
    key="$(repo_key "$project")" || exit 0
    local store="$STORE_ROOT/$key"
    local slug="${project//[^A-Za-z0-9]/-}"
    local memory="$HOME/.claude/projects/$slug/memory"

    if [ -n "${INTUI_CONTAINER:-}" ] && ! grep -q " $STORE_ROOT " /proc/self/mounts; then
        warn "$STORE_ROOT is not mounted from the host; add it to MOUNTS"
        exit 0
    fi

    if [ -L "$memory" ]; then
        if [ "$(readlink "$memory")" != "$store" ]; then
            warn "$memory already links to $(readlink "$memory"); left as is"
        fi
        exit 0
    fi

    mkdir -p "$store" "$(dirname "$memory")"
    if [ -d "$memory" ]; then
        shopt -s nullglob dotglob
        merge_into_store "$memory" "$store" || exit 0
        rmdir "$memory"
    fi
    ln -s "$store" "$memory"
}

main "$@"
