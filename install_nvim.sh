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
    # - `npm` is required by mason to install the node based language servers
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

echo "Install tree-sitter CLI..."
# NOTE: nvim-treesitter needs tree-sitter-cli >= 0.26.1, which is newer than the distro packages
case "$(uname -m)" in
    x86_64) ts_arch=x64 ;;
    aarch64) ts_arch=arm64 ;;
    *)
        echo "Unsupported architecture for tree-sitter CLI!"
        exit 1
        ;;
esac
tmp="$(mktemp -d)"
wget -qO "$tmp/tree-sitter.gz" "https://github.com/tree-sitter/tree-sitter/releases/download/v0.27.2/tree-sitter-linux-$ts_arch.gz"
gunzip "$tmp/tree-sitter.gz"
chmod +x "$tmp/tree-sitter"
mkdir -p ~/.local/bin
mv "$tmp/tree-sitter" ~/.local/bin/
rm -rf "$tmp"

echo "Install LSP dependencies..."
# NOTE:
# - `shellcheck` is needed by bashls for linting
# - `gcc`, `c++`, `cmake` and `ninja` are required by glslls
# - `openjdk-21` and `maven` are required by java-language-server
if is_ubuntu; then
    sudo apt-get install -y --no-install-recommends shellcheck gcc cmake ninja-build g++ openjdk-21-jdk maven
elif is_arch; then
    sudo pacman -S --needed --noconfirm shellcheck gcc cmake ninja jdk21-openjdk maven
else
    echo "Unsupported OS!"
    exit 1
fi

echo "Install formatters & dependencies..."
# NOTE:
# - 'make' is needed by luaformatter (additionally needs g++, cmake, etc... but those are already installed above)
if is_ubuntu; then
    sudo apt-get install -y --no-install-recommends shfmt make luarocks
elif is_arch; then
    sudo pacman -S --needed --noconfirm shfmt make luarocks
else
    echo "Unsupported OS!"
    exit 1
fi
sudo luarocks install --server=https://luarocks.org/dev luaformatter

echo "Configure nvim..."
symlink_config nvim
git config --global core.editor "nvim"
