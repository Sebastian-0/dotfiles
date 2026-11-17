#!/bin/bash
# The command tmux runs in its first window; bootstrap.sh passes claude's full
# argument list.

tmux set -p @claude 1
claude "$@"

# tmux wipes the screen on exit, taking claude's parting --resume line with
# it; bootstrap.sh prints this file afterwards.
tmux capture-pane -p > "$CLAUDESAFE_LAST_SCREEN" 2> /dev/null
