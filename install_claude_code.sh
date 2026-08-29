#!/bin/bash
set -euo pipefail

. utils.sh

echo "Copy claude configuration..."
symlink_path "$HOME" .claude claude

echo "Install claude code..."
curl -fsSL https://claude.ai/install.sh | bash
