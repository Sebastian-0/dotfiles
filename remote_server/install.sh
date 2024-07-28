#!/bin/bash
set -eou pipefail

read -sp Enter server password: PASS
echo $PASS > pass
chmod 600 pass

sudo apt-get install -y terminator
mkdir -p ~/.config/terminator
cp terminator_config ~/.config/terminator/config

cat << EOF >> ~/.bashrc

function remote_server_workspace() (
    cd $PWD
    ./launch_server_workspace.sh
)
EOF
