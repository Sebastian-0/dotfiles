#!/bin/bash
set -euo pipefail

. utils.sh

./install_font.sh

echo "Install rustup and rust..."
if ! which rustup > /dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
fi
rustup update

echo "Install extension packages..."
if is_ubuntu; then
    sudo apt-get install ripgrep jq imagemagick fd-find poppler-utils ffmpeg 7zip
fi

echo "Install yazi..."
cargo install --locked yazi-fm yazi-cli

echo "Copy yazi configuration..."
symlink_config yazi

echo "Set up plugins and themes..."
mkdir -p yazi/plugins
mkdir -p yazi/flavors
ya pack -i

# Installed with this originally
# ya pack -a raikhan/compress
# ya pack -a yazi-rs/flavors:catppuccin-mocha
