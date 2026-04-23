#!/bin/bash

# Toggle visibility of stalonetray popup
# Similar to date.sh calendar popup pattern

TRAY_WIN_NAME="stalonetray"
POLYBAR_HEIGHT=75
STATE_FILE="/tmp/stalonetray_visible"

if [ "$1" = "--toggle" ]; then
    WIN_ID=$(xdotool search --class "$TRAY_WIN_NAME" | head -1)

    if [ -z "$WIN_ID" ]; then
        exit 0
    fi

    if [ -f "$STATE_FILE" ]; then
        # Currently visible -> send back to scratchpad
        i3-msg "[class=\"$TRAY_WIN_NAME\"] move scratchpad" > /dev/null
        rm -f "$STATE_FILE"
    else
        eval "$(xdotool getdisplaygeometry --shell)"

        TRAY_WIDTH=$(xdotool getwindowgeometry "$WIN_ID" 2> /dev/null | grep -o "Geometry: [0-9]*x[0-9]*" | cut -d' ' -f2 | cut -dx -f1)
        TRAY_HEIGHT=$(xdotool getwindowgeometry "$WIN_ID" 2> /dev/null | grep -o "Geometry: [0-9]*x[0-9]*" | cut -d' ' -f2 | cut -dx -f2)
        TRAY_WIDTH=${TRAY_WIDTH:-100}
        TRAY_HEIGHT=${TRAY_HEIGHT:-40}

        X_POS="$((WIDTH - TRAY_WIDTH - 14))"
        Y_POS="$((HEIGHT - TRAY_HEIGHT - POLYBAR_HEIGHT - 10))"

        i3-msg "[class=\"$TRAY_WIN_NAME\"] scratchpad show, move position $X_POS $Y_POS" > /dev/null
        xdotool windowraise "$WIN_ID"
        touch "$STATE_FILE"
    fi
    exit 0
fi

if [ "$1" = "--launch" ]; then
    killall -q stalonetray
    sleep 0.2
    rm -f "$STATE_FILE"

    stalonetray \
        --config "$HOME/.config/polybar/stalonetrayrc" &
    disown

    # Wait for window, then send to scratchpad (stays in X, hidden by i3)
    sleep 0.5
    i3-msg "[class=\"$TRAY_WIN_NAME\"] move scratchpad" > /dev/null
    exit 0
fi

# Default: output icon for polybar
echo "󰇙"
