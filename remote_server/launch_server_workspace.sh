#!/bin/bash
set -euo pipefail

dir="$PWD"

cleanup() {
    echo "Cleaning up..."
    rm -f /tmp/remote_pass
}
trap cleanup EXIT

read -sp "Enter remote password: " PASS
echo $PASS > /tmp/remote_pass

launch_workers() {
    i3-msg "exec terminator -x $dir/launch_ssh.sh /tmp/remote_pass worker-1"
    i3-msg "exec terminator -x $dir/launch_ssh.sh /tmp/remote_pass worker-2"
    i3-msg "exec terminator -x $dir/launch_ssh.sh /tmp/remote_pass worker-3"
    i3-msg "exec terminator -x $dir/launch_ssh.sh /tmp/remote_pass performance"
}

launch_mesh() {
    i3-msg "exec terminator -x $dir/launch_ssh.sh /tmp/remote_pass mesh-1"
    i3-msg "exec terminator -x $dir/launch_ssh.sh /tmp/remote_pass mesh-2"
    i3-msg "exec terminator -x $dir/launch_ssh.sh /tmp/remote_pass mesh-3"
    i3-msg "exec terminator -x $dir/launch_ssh.sh /tmp/remote_pass mesh-4"
    i3-msg "exec terminator -x $dir/launch_ssh.sh /tmp/remote_pass mesh-5"
}

if [ $# = 0 ]; then
    i3-msg "append_layout $dir/server_workspace_9.json"
    launch_workers
    launch_mesh
elif [ "$1" == "--worker" ] || [ "$1" == "-w" ]; then
    i3-msg "append_layout $dir/server_workspace_4.json"
    launch_workers
elif [ "$1" == "--mesh" ] || [ "$1" == "-m" ]; then
    i3-msg "append_layout $dir/server_workspace_5.json"
    launch_mesh
elif [ "$1" == "--core" ] || [ "$1" == "-c" ]; then
    i3-msg "append_layout $dir/server_workspace_1.json"
    i3-msg "exec terminator -x $dir/launch_ssh.sh /tmp/remote_pass core"
fi

sleep 2
