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
    # NOTE:
    # - `luarocks` is required by lazy.nvim (for rockspec) and luaformatter
    # - `python3-pynvim` is required for jupyter-vim (I think?)
    # - `xclip` is required for clipboard support in vim
    # - `ripgrep` and `fd-find` are required by telescope.nvim
    # - `python3-venv` is required by ???
    # - `npm` is required by nvim-treesitter (I think?)
    if is_ubuntu; then
        sudo apt-get install -y --no-install-recommends ripgrep xclip fd-find python3-venv python3-pynvim luarocks $npm
        sudo update-alternatives --install /usr/bin/editor editor "$(which nvim)" 100
        if [ -f ~/.selected_editor ]; then
            echo SELECTED_EDITOR="\"$(which nvim)\"" > ~/.selected_editor
        fi
    elif is_arch; then
        sudo pacman -S --needed --noconfirm ripgrep xclip fd python-virtualenv python-pynvim luarocks $npm
    else
        echo "Unsupported OS!"
        exit 1
    fi
fi

echo "Install LSP dependencies..."
# NOTE:
# - `shellcheck` is needed by bashls for linting
# - `gcc`, `c++`, `cmake` and `ninja` are required by glslls
if is_ubuntu; then
    sudo apt-get install -y --no-install-recommends shellcheck gcc cmake ninja-build g++
elif is_arch; then
    sudo pacman -S --needed --noconfirm shellcheck gcc cmake ninja
else
    echo "Unsupported OS!"
    exit 1
fi

echo "Install formatters..."
if is_ubuntu; then
    sudo apt-get install -y --no-install-recommends shfmt
elif is_arch; then
    sudo pacman -S --needed --noconfirm shfmt
else
    echo "Unsupported OS!"
    exit 1
fi
sudo luarocks install --server=https://luarocks.org/dev luaformatter

echo "Configure nvim..."
symlink_config nvim
git config --global core.editor "nvim"
