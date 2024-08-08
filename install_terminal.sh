#!/bin/bash
set -euo pipefail

. utils.sh

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
if is_ubuntu; then
    curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin
    sudo ln -s ~/.local/kitty.app/bin/kitten /usr/bin/kitten
    sudo ln -s ~/.local/kitty.app/bin/kitty /usr/bin/kitty
elif is_arch; then
    sudo pacman -S --needed --noconfirm kitty
else
    echo "Unsupported OS!"
    exit 1
fi

echo "Copy Kitty configuration..."
symlink_config kitty
