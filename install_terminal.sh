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

echo "Install tdrop..."
if [ -z "$(which tdrop)" ]; then
    if [ "$(is_ubuntu)" = "true" ]; then
        sudo apt-get install -y xdotool x11-utils
    else
        sudo pacman -S --needed xorg-xprop xdotool xorg-xwininfo
    fi
    git clone https://github.com/noctuid/tdrop.git
    cd tdrop
    sudo make install
    cd ..
    rm -rf tdrop
fi

echo "Install Kitty terminal..."
if [ "$(is_ubuntu)" = "true" ]; then
    sudo apt-get install -y kitty
else
    sudo pacman -S --needed kitty
fi
cp kitty/kitty.conf ~/.config/kitty/kitty.conf
