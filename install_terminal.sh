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
if ! which tdrop >&/dev/null; then
    if [ "$(is_ubuntu)" = "true" ]; then
        sudo apt-get install -y xdotool x11-utils gawk
    else
        sudo pacman -S --needed --noconfirm xorg-xprop xdotool xorg-xwininfo gawk
    fi
    git clone https://github.com/noctuid/tdrop.git
    cd tdrop
    sudo make install
    cd ..
    rm -rf tdrop
fi

echo "Install Kitty terminal..."
if [ "$(is_ubuntu)" = "true" ]; then
    curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin
    sudo ln -s ~/.local/kitty.app/bin/kitten /usr/bin/kitten
    sudo ln -s ~/.local/kitty.app/bin/kitty /usr/bin/kitty
else
    sudo pacman -S --needed --noconfirm kitty
fi

echo "Copy Kitty configuration..."
if [ ! -L ~/.config/kitty ]; then
    if [ -e ~/.config/kitty ]; then
        echo "WARNING: The folder ~/.config/kitty exists! Continuing will delete it."
        echo ""
        read -rp "Press enter to continue..."
    fi
    rm -rf ~/.config/kitty
    ln -s "$PWD/kitty" ~/.config/kitty
fi
