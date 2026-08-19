#!/bin/bash
# One-time installer: symlink launch.sh to ~/.local/bin/claudesafe and
# ensure ~/.local/bin is on PATH via .bashrc.
set -euo pipefail

SCRIPT="$(readlink -f "$0")"
SANDBOX_DIR="$(dirname "$SCRIPT")"

LOG_PREFIX=install
. "$SANDBOX_DIR/log.sh"

BIN_DIR="$HOME/.local/bin"
LINK="$BIN_DIR/claudesafe"
TARGET="$SANDBOX_DIR/launch.sh"

mkdir -p "$BIN_DIR"
ln -sfn "$TARGET" "$LINK"
log_info "linked $LINK -> $TARGET"

if ! which docker > /dev/null 2>&1; then
    log_warn "docker not found on PATH; claudesafe will fail until it's installed."
fi

if ! which claudesafe > /dev/null 2>&1; then
    log_warn "$BIN_DIR not found on PATH; claudesafe will fail until it's added to path."
fi

COMPLETION_DIR="$HOME/.local/share/bash-completion/completions"
mkdir -p "$COMPLETION_DIR"
ln -sfn "$SANDBOX_DIR/completion.bash" "$COMPLETION_DIR/claudesafe"
log_info "linked $COMPLETION_DIR/claudesafe -> $SANDBOX_DIR/completion.bash"
if [ ! -r /usr/share/bash-completion/bash_completion ]; then
    log_warn "bash-completion not installed; source completion.bash from .bashrc instead"
fi

log_info "done. Run 'claudesafe' from any folder (open a new shell for completion)."
