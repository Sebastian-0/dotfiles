#!/bin/bash
set -euo pipefail

is_ubuntu() {
    if [ -n "$(grep "Ubuntu" /etc/os-release)" ]; then
        echo "true"
    else
        echo "false"
    fi
}

./install_font.sh

echo "Install yakuake..."
if [ "$(is_ubuntu)" = "true" ]; then
    sudo apt-get install -y yakuake
else
    sudo pacman -S --needed yakuake
fi

echo "Install Catppuccin theme for Konsole..."
if [ ! -f ~/.local/share/konsole/Catppuccin-Mocha.colorscheme ]; then
    git clone --depth 1 https://github.com/catppuccin/konsole.git
    cp konsole/*.colorscheme ~/.local/share/konsole/
    rm -rf konsole
fi
