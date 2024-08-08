#!/bin/bash
set -euo pipefail

. utils.sh

if is_ubuntu; then
    sudo apt-get install -y ufw
elif is_arch; then
    sudo pacman -S --needed --noconfirm ufw
else
    echo "Unsupported OS!"
    exit 1
fi

sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw enable

echo ""
echo "NOTE: By default everything is denied, run 'sudo ufw <allow/limit> <port>/<tcp|udp> to change this."
