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

echo "Install git, calc & exa/eza..."
if [ "$(is_ubuntu)" = "true" ]; then
    sudo apt-get install -y git gitk calc # fonts-firacode

    # Install eza from official repo
    sudo mkdir -p /etc/apt/keyrings
    wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
    echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list
    sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
    sudo apt update
    sudo apt install -y eza
else
    sudo pacman -S --needed --noconfirm git tk calc eza # ttf-fira-code
fi

echo "Install fzf"
# Note that key bindings are registered separately in .bashrc
if [ "$(is_ubuntu)" = "true" ]; then
    sudo apt install -y fzf
else
    sudo pacman -S --needed --noconfirm fzf
fi

echo "Install zoxide"
if [ "$(is_ubuntu)" = "true" ]; then
    curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
else
    sudo pacman -S --needed --noconfirm zoxide
fi
if [ -z "$(grep zoxide ~/.bashrc)" ]; then
    cat <<EOF >> ~/.bashrc
# cd aliases
if [ "$(which zoxide)" ]; then
    eval "\$(zoxide init bash --cmd cd)"
fi
EOF
fi

echo "Install btop..."
if [ "$(is_ubuntu)" = "true" ]; then
    sudo apt-get install -y btop
else
    sudo pacman -S --needed --noconfirm btop
fi
git clone https://github.com/catppuccin/btop
mkdir -p ~/.config/btop/themes
cp -r btop/themes/* ~/.config/btop/themes/
rm -rf btop
