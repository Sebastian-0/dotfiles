#!/bin/bash
set -euo pipefail

echo "Install FiraCode nerd font..."
if [ ! -d ~/.local/share/fonts/NerdFonts ]; then
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    git clone --filter=blob:none --sparse https://github.com/ryanoasis/nerd-fonts.git "$tmp/nerd-fonts"
    (
        cd "$tmp/nerd-fonts"
        git sparse-checkout add patched-fonts/FiraCode
        ./install.sh FiraCode
    )
fi
