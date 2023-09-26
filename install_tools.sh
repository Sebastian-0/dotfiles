#!/bin/bash
set -euo pipefail

is_ubuntu() {
    if [ -n "$(grep "Ubuntu" /etc/os-release)" ]; then
        echo "true"
    else
        echo "false"
    fi
}

if [ "$(is_ubuntu)" = "true" ]; then
    sudo apt-get install -y git gitk yakuake # fonts-firacode
else
    sudo pacman -S --needed git tk yakuake # ttf-fira-code
fi

echo "Vim installation"
sudo snap install --classic nvim
if [ "$(is_ubuntu)" = "true" ]; then
    sudo apt-get install -y ripgrep xclip fd-find python3-venv
else
    sudo pacman -S --needed ripgrep xclip fd
fi

echo "Install FiraCode nerd font..."
git clone --filter=blob:none --sparse https://github.com/ryanoasis/nerd-fonts.git
cd nerd-fonts
git sparse-checkout add patched-fonts/FiraCode
./install.sh FiraCode
cd ..
rm -rf nerd-fonts
