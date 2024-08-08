#!/bin/bash
set -euo pipefail

. utils.sh

./install_font.sh

echo "This script installs i3, assuming you are running Ubuntu or Manjaro!"
echo ""
read -rp "Press enter to start..."

if ! which i3 >&/dev/null; then
    echo "Installing packages..."
    if is_ubuntu; then
        sudo apt-get install -y i3 feh xss-lock wmctrl scrot picom dunst rofi pulseaudio-utils playerctl brightnessctl polybar flameshot imagemagick yad libsass1 python3-virtualenv

        # Build i3lock-color
        sudo apt-get install -y autoconf gcc make pkg-config libpam0g-dev libcairo2-dev libfontconfig1-dev libxcb-composite0-dev libev-dev libx11-xcb-dev libxcb-xkb-dev libxcb-xinerama0-dev libxcb-randr0-dev libxcb-image0-dev libxcb-util-dev libxcb-xrm-dev libxkbcommon-dev libxkbcommon-x11-dev libjpeg-dev

        git clone https://github.com/Raymo111/i3lock-color.git
        cd i3lock-color
        ./install-i3lock-color.sh
        cd ..
        rm -rf i3lock-color

        # Clipmenu
        sudo apt-get install -y xsel libxcomposite-dev

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

        # Older Ubuntu
        if grep -q "22.04" /etc/os-release; then
            echo "Manually build i3-gaps..."
            sudo apt-get install -y libcairo2-dev libpango1.0-dev libyajl-dev libxcb-icccm4-dev libxcb-keysyms1-dev libxcb-cursor-dev libstartup-notification0-dev xmlto meson asciidoc
            git clone https://github.com/Airblader/i3 i3-gaps
            cd i3-gaps
            git checkout gaps
            meson -Ddocs=true -Dmans=true ../build
            meson compile -C ../build
            sudo meson install -C ../build
            cd ..
            rm -rf build i3-gaps
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
    mkdir -p ~/.config/environment.d/
    cp i3/clipmenu/clipmenud.conf ~/.config/environment.d/
    systemctl enable --user clipmenud.service
    systemctl start --user clipmenud.service

    echo "Install rofi themes..."
    git clone --depth=1 https://github.com/adi1090x/rofi.git
    cd rofi
    ./setup.sh
    cd ..
    rm -rf rofi
    sed -i 's|@import .*|@import "~/.config/rofi/colors/catppuccin.rasi"|g' ~/.config/rofi/launchers/type-4/shared/colors.rasi
    sed -i 's|@import .*|@import "~/.config/rofi/colors/catppuccin.rasi"|g' ~/.config/rofi/powermenu/type-1/shared/colors.rasi
    sed -i "s/theme='style-1'/theme='style-3'/g" ~/.config/rofi/powermenu/type-1/powermenu.sh
    sed -i "s|\si3lock|$HOME/.config/i3/scripts/lock.sh|g" ~/.config/rofi/powermenu/type-1/powermenu.sh

    echo "Install GTK theme..."
    (
        git clone --recurse-submodules https://github.com/catppuccin/gtk
        cd gtk
        python3 -m venv venv
        . venv/bin/activate
        pip install -r requirements.txt
        python3 install.py mocha
        cd -
        rm -rf gtk
    )

    echo "Log into an i3 session to access your new desktop!"
fi

echo "Configure i3..."
symlink_config i3

echo "Configure polybar..."
symlink_config polybar
