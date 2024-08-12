#!/bin/bash
set -euo pipefail

. utils.sh

./install_font.sh

echo "Install Neovim..."
if ! which nvim >&/dev/null; then
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
fi

echo "Configure nvim..."
symlink_config nvim
git config --global core.editor "nvim"
