#!/bin/bash
set -euo pipefail
if [ ! -f remote_server/pass ]; then
    read -sp "Enter remote pwd: " PASS
    echo "$PASS" > remote_server/pass
    chmod 600 remote_server/pass
    echo "Installing terminator..."
    sudo apt-get install -y terminator
    cp remote_server/terminator_config ~/.config/terminator/config
    echo "Installing alias..."
    cat <<EOF >> ~/.bashrc

function remote_server_workspace() (
    cd "$PWD"
    ./launch_server_workspace.sh \$@
)
EOF
fi
