#!/bin/bash
set -euo pipefail

is_ubuntu() {
    if [ -n "$(grep "Ubuntu" /etc/os-release)" ]; then
        echo "true"
    else
        echo "false"
    fi
}

if [ is_ubuntu ]; then
    sudo apt install -y git gitk fonts-firacode yakuake
else
    sudo pacman -S git tk ttf-fira-code yakuake
fi

echo "Vim installation"
sudo snap install --classic nvim
if [ is_ubuntu ]; then
    sudo apt install -y ripgrep xclip fd-find
else
    sudo pacman -S ripgrep xclip fd
fi
