#!/bin/bash
set -euo pipefail

. utils.sh

./install_font.sh

echo "Install extension packages..."
if is_ubuntu; then
    sudo apt-get install -y --no-install-recommends ripgrep jq imagemagick fd-find poppler-utils ffmpeg 7zip
fi

echo "Install yazi..."
sudo snap install --classic yazi

echo "Copy yazi configuration..."
symlink_config yazi

echo "Set up plugins and themes..."
mkdir -p yazi/plugins
mkdir -p yazi/flavors
ya pack -i

# If ya can't run try with /snap/yazi/current/ya

# Installed with this originally
# ya pack -a raikhan/compress
# ya pack -a yazi-rs/flavors:catppuccin-mocha
