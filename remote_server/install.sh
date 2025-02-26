#!/bin/bash
set -eou pipefail

sudo apt-get install -y --no-install-recommends terminator
mkdir -p ~/.config/terminator
cp terminator_config ~/.config/terminator/config

cat << EOF >> ~/.bashrc

function remote_server_workspace() (
    cd $PWD
    ./launch_server_workspace.sh "\$@"
)
EOF
