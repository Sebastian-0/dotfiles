#!/bin/bash
set -euo pipefail

. utils.sh

./install_font.sh

echo "Install Neovim..."
sudo snap install --classic nvim
npm="npm"
if which npm >&/dev/null; then
    npm=
fi
if is_ubuntu; then
    sudo apt-get install -y ripgrep xclip fd-find python3-venv shellcheck $npm
    sudo update-alternatives --install /usr/bin/editor editor "$(which nvim)" 100
    if [ -f ~/.selected_editor ]; then
        echo SELECTED_EDITOR="\"$(which nvim)\"" > ~/.selected_editor
    fi
elif is_arch; then
    sudo pacman -S --needed --noconfirm ripgrep xclip fd shellcheck $npm
else
    echo "Unsupported OS!"
    exit 1
fi
git config --global core.editor "nvim"

echo "Copy configuration..."
if [ ! -L ~/.config/nvim ]; then
    if [ -e ~/.config/nvim ]; then
        echo "WARNING: The folder ~/.config/nvim exists! Continuing will delete it."
        echo ""
        read -rp "Press enter to continue..."
    fi
    rm -rf ~/.config/nvim
    ln -s "$PWD/nvim" ~/.config/nvim
fi
