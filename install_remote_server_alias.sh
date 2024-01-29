#!/bin/bash
set -euo pipefail
if [ -z "$(grep remote_server_workspace ~/.bashrc)" ]; then
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
