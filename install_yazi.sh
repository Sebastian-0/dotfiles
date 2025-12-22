#!/bin/bash
set -euo pipefail

. utils.sh

./install_font.sh

echo "Install extension packages..."
if is_ubuntu; then
    sudo apt-get install -y --no-install-recommends ripgrep jq imagemagick fd-find poppler-utils ffmpeg 7zip
elif is_arch; then
    sudo pacman -S --needed --noconfirm ripgrep jq imagemagick fd poppler ffmpeg 7zip
else
    echo "Unsupported OS!"
    exit 1
fi

echo "Install yazi..."
if is_ubuntu; then
    sudo snap install --classic yazi
elif is_arch; then
    sudo pacman -S --needed --noconfirm yazi
else
    echo "Unsupported OS!"
    exit 1
fi

echo "Copy yazi configuration..."
symlink_config yazi

echo "Set up plugins and themes..."
mkdir -p yazi/plugins
mkdir -p yazi/flavors
ya pkg install

# If ya can't run try with /snap/yazi/current/ya

# Installed with this originally
# ya pack -a raikhan/compress
# ya pack -a yazi-rs/flavors:catppuccin-mocha
