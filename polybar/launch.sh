#!/usr/bin/env bash

# Terminate already running bar instances
# If all your bars have ipc enabled, you can use
polybar-msg cmd quit
# Otherwise you can use the nuclear option:
# killall -q polybar

# Set this value in ~/.xprofile or /etc/environment
bar=${BAR_NAME:-base}

echo "---" | tee -a /tmp/polybar.log
polybar -c ~/.config/polybar/config.ini "$bar" 2>&1 | tee -a /tmp/polybar.log &
disown

echo "Bar launched..."
