#!/bin/bash
set -euo pipefail

. utils.sh

./install_font.sh

echo "Install git, calc & exa/eza..."
if is_ubuntu; then
    sudo apt-get install -y --no-install-recommends git gitk calc curl # fonts-firacode

    # Install eza from official repo
    if [ ! -f /etc/apt/keyrings/gierens.gpg ]; then
        sudo mkdir -p /etc/apt/keyrings
        wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
        echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list
        sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
        sudo apt update
    fi
    sudo apt install -y --no-install-recommends eza
elif is_arch; then
    sudo pacman -S --needed --noconfirm git tk calc eza # ttf-fira-code
else
    echo "Unsupported OS!"
    exit 1
fi

echo "Install fzf"
# Note that key bindings are registered separately in .bashrc
if is_ubuntu; then
    sudo apt install -y --no-install-recommends fzf
elif is_arch; then
    sudo pacman -S --needed --noconfirm fzf
else
    echo "Unsupported OS!"
    exit 1
fi

echo "Install zoxide"
if is_ubuntu; then
    curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
elif is_arch; then
    sudo pacman -S --needed --noconfirm zoxide
else
    echo "Unsupported OS!"
    exit 1
fi
if ! grep -q zoxide ~/.bashrc; then
    printf "\n" >> ~/.bashrc
    cat << EOF >> ~/.bashrc
# cd aliases
if which zoxide >&/dev/null; then
    eval "\$(zoxide init bash --cmd cd)"
fi
EOF
fi

echo "Install btop..."
if is_ubuntu; then
    sudo apt-get install -y --no-install-recommends btop
elif is_arch; then
    sudo pacman -S --needed --noconfirm btop
else
    echo "Unsupported OS!"
    exit 1
fi
git clone https://github.com/catppuccin/btop
mkdir -p ~/.config/btop/themes
cp -r btop/themes/* ~/.config/btop/themes/
rm -rf btop
