#!/bin/bash
set -euo pipefail

is_ubuntu() {
    if [ -n "$(grep "Ubuntu" /etc/os-release)" ]; then
        echo "true"
    else
        echo "false"
    fi
}

echo "Install git, yakuake, calc & exa/eza..."
if [ "$(is_ubuntu)" = "true" ]; then
    sudo apt-get install -y git gitk yakuake calc # fonts-firacode

    # Install eza from official repo
    sudo mkdir -p /etc/apt/keyrings
    wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
    echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list
    sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
    sudo apt update
    sudo apt install -y eza
else
    sudo pacman -S --needed git tk yakuake calc eza # ttf-fira-code
fi

echo "Install btop..."
if [ "$(is_ubuntu)" = "true" ]; then
    sudo apt-get install -y btop
else
    sudo pacman -S --needed btop
fi
git clone https://github.com/catppuccin/btop
mkdir -p ~/.config/btop/themes
cp -r btop/themes/* ~/.config/btop/themes/
rm -rf btop

echo "Install FiraCode nerd font..."
if [ ! -d ~/.local/share/fonts/NerdFonts ]; then
    git clone --filter=blob:none --sparse https://github.com/ryanoasis/nerd-fonts.git
    cd nerd-fonts
    git sparse-checkout add patched-fonts/FiraCode
    ./install.sh FiraCode
    cd ..
    rm -rf nerd-fonts
fi

echo "Install Catppuccin theme for Konsole..."
if [ ! -f ~/.local/share/konsole/Catppuccin-Mocha.colorscheme ]; then
    git clone --depth 1 https://github.com/catppuccin/konsole.git
    cp konsole/*.colorscheme ~/.local/share/konsole/
    rm -rf konsole
fi
