#!/bin/bash
set -euo pipefail

is_ubuntu() {
    if [ -n "$(grep "Ubuntu" /etc/os-release)" ]; then
        echo "true"
    else
        echo "false"
    fi
}

echo "Install Neovim..."
sudo snap install --classic nvim
if [ "$(is_ubuntu)" = "true" ]; then
    sudo apt-get install -y ripgrep xclip fd-find python3-venv npm
else
    sudo pacman -S --needed ripgrep xclip fd npm
fi
git config --global core.editor "nvim"

echo "Copy configuration..."
cp -Tr nvim ~/.config/nvim
