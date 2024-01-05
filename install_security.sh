#!/bin/bash
set -euo pipefail

is_ubuntu() {
    if [ -n "$(grep "Ubuntu" /etc/os-release)" ]; then
        echo "true"
    else
        echo "false"
    fi
}

if [ "$(is_ubuntu)" = "true" ]; then
    sudo apt-get install -y ufw
else
    sudo pacman -S --needed --noconfirm ufw
fi

sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw enable

echo ""
echo "NOTE: By default everything is denied, run 'sudo ufw <allow/limit> <port>/<tcp|udp> to change this."
