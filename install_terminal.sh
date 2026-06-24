#!/bin/bash
set -euo pipefail

. utils.sh

./install_font.sh

echo "Install tdrop..."
if ! which tdrop >&/dev/null; then
    if is_ubuntu; then
        sudo apt-get install -y --no-install-recommends xdotool x11-utils gawk make
    else
        sudo pacman -S --needed --noconfirm xorg-xprop xdotool xorg-xwininfo gawk make
    fi
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    git clone https://github.com/noctuid/tdrop.git "$tmp/tdrop"
    (cd "$tmp/tdrop" && sudo make install)
fi

echo "Install Kitty terminal..."
if is_ubuntu; then
    curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin
    sudo ln -fs ~/.local/kitty.app/bin/kitten /usr/bin/kitten
    sudo ln -fs ~/.local/kitty.app/bin/kitty /usr/bin/kitty
elif is_arch; then
    sudo pacman -S --needed --noconfirm kitty
else
    echo "Unsupported OS!"
    exit 1
fi

echo "Copy Kitty configuration..."
symlink_config kitty
