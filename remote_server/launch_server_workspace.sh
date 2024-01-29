#!/bin/bash
set -euo pipefail

dir="$PWD"

launch_workers() {
    i3-msg "exec terminator -x $dir/launch_ssh.sh $dir/pass worker-1"
    i3-msg "exec terminator -x $dir/launch_ssh.sh $dir/pass worker-3"
    i3-msg "exec terminator -x $dir/launch_ssh.sh $dir/pass worker-4"
    i3-msg "exec terminator -x $dir/launch_ssh.sh $dir/pass performance"
}

launch_mesh() {
    i3-msg "exec terminator -x $dir/launch_ssh.sh $dir/pass mesh-1"
    i3-msg "exec terminator -x $dir/launch_ssh.sh $dir/pass mesh-2"
    i3-msg "exec terminator -x $dir/launch_ssh.sh $dir/pass mesh-3"
    i3-msg "exec terminator -x $dir/launch_ssh.sh $dir/pass mesh-4"
}

if [ $# = 0 ]; then
    i3-msg "append_layout $dir/server_workspace_16.json"
    launch_workers
    launch_mesh
elif [ "$1" == "--worker" ] || [ "$1" == "-w" ]; then
    i3-msg "append_layout $dir/server_workspace_4.json"
    launch_workers
elif [ "$1" == "--mesh" ] || [ "$1" == "-m" ]; then
    i3-msg "append_layout $dir/server_workspace_4.json"
    launch_mesh
fi
