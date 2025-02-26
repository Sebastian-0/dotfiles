#!/bin/bash
set -euo pipefail

. utils.sh

echo "Install fcitx5..."
if is_ubuntu; then
    sudo apt-get install -y --no-install-recommends fcitx5 fcitx5-chinese-addons fcitx5-configtool
else
    sudo pacman -S --needed --noconfirm fcitx5 fcitx5-chinese-addons fcitx5-configtool
fi

echo "Copy fcitx5 configuration..."
symlink_config fcitx5

# TODO Modify ~/.profile or xprofile
echo ""
echo "Installation done! Please add the below to your ~/.profile or ~/.xprofile"
echo ""
echo "export GLFW_IM_MODULE=ibus"
echo "export GTK_IM_MODULE=fcitx"
echo "export QT_IM_MODULE=fcitx"
echo "export XMODIFIERS=@im=fcitx"
echo "export SDL_IM_MODULE=fcitx"
