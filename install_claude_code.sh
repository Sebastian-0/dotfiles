#!/bin/bash
set -euo pipefail

. utils.sh

echo "Install claude code..."
curl -fsSL https://claude.ai/install.sh | bash

echo "Copy claude configuration..."
symlink_path "$HOME" .claude claude
