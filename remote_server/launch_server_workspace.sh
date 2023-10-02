#!/bin/bash
set -euo pipefail

dir="$PWD"

i3-msg "append_layout $dir/server_workspace.json"
i3-msg "exec terminator -x $dir/launch_ssh.sh $dir/pass worker-1"
i3-msg "exec terminator -x $dir/launch_ssh.sh $dir/pass worker-3"
i3-msg "exec terminator -x $dir/launch_ssh.sh $dir/pass worker-4"
i3-msg "exec terminator -x $dir/launch_ssh.sh $dir/pass performance"
i3-msg "exec terminator -x $dir/launch_ssh.sh $dir/pass mesh-1"
i3-msg "exec terminator -x $dir/launch_ssh.sh $dir/pass mesh-2"
i3-msg "exec terminator -x $dir/launch_ssh.sh $dir/pass mesh-3"
