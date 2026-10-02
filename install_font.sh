#!/bin/bash
set -euo pipefail

# v3.5.1
nerd_fonts_commit=b894ea7803af6aade63d60a4381e006098ec9c4d

echo "Install FiraCode nerd font..."
if [ ! -d ~/.local/share/fonts/NerdFonts ]; then
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    git clone --filter=blob:none --sparse https://github.com/ryanoasis/nerd-fonts.git "$tmp/nerd-fonts"
    (
        cd "$tmp/nerd-fonts"
        git checkout "$nerd_fonts_commit"
        git sparse-checkout add patched-fonts/FiraCode
        ./install.sh FiraCode
    )
fi
