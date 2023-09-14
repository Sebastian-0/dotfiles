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
    sudo apt install -y git gitk fonts-firacode yakuake scrot xclip
else
    sudo pacman -S git tk ttf-fira-code xclip
fi
sudo snap install --classic nvim
