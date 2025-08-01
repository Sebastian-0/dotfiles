#!/bin/bash
set -euo pipefail

. utils.sh

./install_font.sh

echo "This script installs i3, assuming you are running Ubuntu or Manjaro!"
echo ""
read -rp "Press enter to start..."

echo "Installing packages..."
if is_ubuntu; then
    sudo apt-get install -y --no-install-recommends i3 feh xss-lock wmctrl scrot picom dunst rofi pulseaudio-utils playerctl brightnessctl polybar flameshot imagemagick yad libsass1 python3-virtualenv

    echo "Building i3lock color..."
    if ! which i3lock >&/dev/null; then
        sudo apt-get install -y --no-install-recommends autoconf gcc make pkg-config libpam0g-dev libcairo2-dev libfontconfig1-dev libxcb-composite0-dev libev-dev libx11-xcb-dev libxcb-xkb-dev libxcb-xinerama0-dev libxcb-randr0-dev libxcb-image0-dev libxcb-util-dev libxcb-xrm-dev libxkbcommon-dev libxkbcommon-x11-dev libjpeg-dev libgif-dev

        git clone https://github.com/Raymo111/i3lock-color.git
        cd i3lock-color
        ./install-i3lock-color.sh
        cd ..
        rm -rf i3lock-color
    else
        echo "... skipping!"
    fi

    echo "Building clipmenu..."
    if ! which clipmenu >&/dev/null; then
        sudo apt-get install -y --no-install-recommends xsel libxcomposite-dev

        git clone https://github.com/cdown/clipnotify.git
        cd clipnotify
        sudo make install
        cd ..
        sudo rm -rf clipnotify

        git clone https://github.com/cdown/clipmenu.git
        cd clipmenu
        sudo make install
        cd ..
        sudo rm -rf clipmenu
    else
        echo "... skipping!"
    fi
elif is_arch; then
    # Manjaro (libsass is needed by GTK theming tool)
    sudo pacman -S --needed --noconfirm i3-wm feh wmctrl picom yay dunst rofi clipmenu playerctl brightnessctl polybar scrot xss-lock flameshot imagemagick yad libsass python-virtualenv
    sudo yay -S --noconfirm --ask 4 --useask --answerclean All --answerdiff None i3lock-color
else
    echo "Unsupported OS!"
    exit 1
fi

echo "Add sudo privileges to brightnessctl..."
sudo chmod +s "$(which brightnessctl)"

echo "Launch clipmenud service..."
if [ ! -f ~/.config/environment.d/clipmenud.conf ]; then
    mkdir -p ~/.config/environment.d/
    ln -s "$PWD/i3/clipmenu/clipmenud.conf" ~/.config/environment.d/clipmenud.conf
    systemctl enable --user clipmenud.service
    systemctl start --user clipmenud.service
else
    echo "... skipping!"
fi

echo "Install rofi themes..."
if [ ! -f ~/.config/rofi/colors/catppuccin.rasi ]; then
    git clone --depth=1 https://github.com/adi1090x/rofi.git
    cd rofi
    ./setup.sh
    cd ..
    rm -rf rofi
    sed -i 's|@import .*|@import "~/.config/rofi/colors/catppuccin.rasi"|g' ~/.config/rofi/launchers/type-4/shared/colors.rasi
    sed -i 's|@import .*|@import "~/.config/rofi/colors/catppuccin.rasi"|g' ~/.config/rofi/powermenu/type-1/shared/colors.rasi
    sed -i "s/theme='style-1'/theme='style-3'/g" ~/.config/rofi/powermenu/type-1/powermenu.sh
    sed -i "s|\si3lock|$HOME/.config/i3/scripts/lock.sh|g" ~/.config/rofi/powermenu/type-1/powermenu.sh
else
    echo "... skipping!"
fi

echo "Install GTK theme..."
if ! compgen -G ~/.local/share/themes/catppuccin*/gtk* >&/dev/null; then
    (
        git clone --recurse-submodules https://github.com/catppuccin/gtk
        cd gtk
        python3 -m venv venv
        . venv/bin/activate
        pip install -r requirements.txt
        python3 install.py mocha blue
        cd -
        rm -rf gtk
    )
else
    echo "... skipping!"
fi

echo "Configure i3..."
symlink_config i3

echo "Configure polybar..."
symlink_config polybar
