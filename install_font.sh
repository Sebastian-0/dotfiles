#!/bin/bash
set -euo pipefail

echo "Install FiraCode nerd font..."
if [ ! -d ~/.local/share/fonts/NerdFonts ]; then
    git clone --filter=blob:none --sparse https://github.com/ryanoasis/nerd-fonts.git
    cd nerd-fonts
    git sparse-checkout add patched-fonts/FiraCode
    ./install.sh FiraCode
    cd ..
    rm -rf nerd-fonts
fi
