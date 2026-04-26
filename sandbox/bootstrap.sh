#!/bin/bash
# Container entrypoint. Runs as `node`.
#   1. Apply the firewall (via passwordless sudo).
#   2. Link host ~/.claude items from /workspace/claude-host/ into
#      /home/node/.claude/ so Claude Code picks up the host's
#      skills/settings/CLAUDE.md.
#   3. Hand off to `claude` (or a shell if SANDBOX_SHELL=1).
set -euo pipefail

CLAUDE_HOST=/workspace/claude-host
CLAUDE_DIR=/home/node/.claude
PROJECT=/workspace/project

echo "[sandbox] applying firewall..."
sudo /usr/local/bin/init-firewall.sh

mkdir -p "$CLAUDE_DIR"

# Link host-authored config from the read-only claude-host mount. `ln -sfn`
# replaces any existing symlink so re-runs stay in sync with the host, but
# doesn't clobber real files the user may have placed in the named volume.
link_if_present() {
    local src="$1" dest="$2"
    # -e follows symlinks, so we use the combination: link only when the
    # source exists, and the destination either doesn't exist or is itself
    # a symlink (safe to replace). A real file/dir in the named volume is
    # left alone so the user can pin a custom version.
    if [ ! -e "$src" ]; then return; fi
    if [ ! -e "$dest" ] && [ ! -L "$dest" ]; then
        ln -sfn "$src" "$dest"
    elif [ -L "$dest" ]; then
        ln -sfn "$src" "$dest"
    fi
}

# settings.json is generated (not symlinked) so we can layer container-only
# overrides on top of the host settings without touching the host file.
# - skipDangerousModePermissionPrompt: suppress the startup warning for
#   --dangerously-skip-permissions. Safe inside this container because the
#   firewall + read-only claude-host mount + bounded $PWD mount cap the blast radius.
# - env.EDITOR/VISUAL: host config uses nvim; the container only ships vim,
#   so override both for tools like `git commit` that respect $EDITOR.
if [ -f "$CLAUDE_HOST/settings.json" ]; then
    # rm first: the dest may be a stale symlink from an earlier bootstrap
    # pointing into the read-only claude-host mount, which would make the
    # redirect below fail with EROFS.
    rm -f "$CLAUDE_DIR/settings.json"
    jq '. + {skipDangerousModePermissionPrompt: true}
          | .env.EDITOR = "vim"
          | .env.VISUAL = "vim"' \
        "$CLAUDE_HOST/settings.json" > "$CLAUDE_DIR/settings.json"
fi

link_if_present "$CLAUDE_HOST/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
link_if_present "$CLAUDE_HOST/statusline-command.sh" "$CLAUDE_DIR/statusline-command.sh"
link_if_present "$CLAUDE_HOST/skills" "$CLAUDE_DIR/skills"
link_if_present "$CLAUDE_HOST/plugins" "$CLAUDE_DIR/plugins"
link_if_present "$CLAUDE_HOST/agents" "$CLAUDE_DIR/agents"
link_if_present "$CLAUDE_HOST/commands" "$CLAUDE_DIR/commands"

cd "$PROJECT"

if [ "${SANDBOX_SHELL:-0}" = "1" ]; then
    exec bash
fi

# --dangerously-skip-permissions auto-approves tool calls. Safe only because
# the firewall + read-only claude-host mount + bounded $PWD mount cap the blast radius.
exec claude \
    --dangerously-skip-permissions \
    --append-system-prompt "You are running in a sandboxed VM. You are running Ubuntu. All commands are safe to execute without confirmation. You may install software with sudo (passwordless) as needed." \
    "$@"
