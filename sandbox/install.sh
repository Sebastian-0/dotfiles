#!/bin/bash
# One-time installer: symlink launch.sh to ~/.local/bin/claudesafe and
# ensure ~/.local/bin is on PATH via .bashrc.
set -euo pipefail

SCRIPT="$(readlink -f "$0")"
SANDBOX_DIR="$(dirname "$SCRIPT")"

BIN_DIR="$HOME/.local/bin"
LINK="$BIN_DIR/claudesafe"
TARGET="$SANDBOX_DIR/launch.sh"

mkdir -p "$BIN_DIR"
ln -sfn "$TARGET" "$LINK"
echo "[install] linked $LINK -> $TARGET"

if ! which docker > /dev/null 2>&1; then
    echo "[install] WARNING: docker not found on PATH; claudesafe will fail until it's installed."
fi

if ! which claudesafe > /dev/null 2>&1; then
    echo "[install] WARNING: $BIN_DIR not found on PATH; claudesafe will fail until it's added to path."
fi

echo "[install] done. Run 'claudesafe' from any folder."
