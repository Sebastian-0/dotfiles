#!/bin/bash

MARKER=/tmp/polybar_long_date_format

# Copied from polybar config, currently not possible to pass here without an ugly solution:
# https://github.com/polybar/polybar/issues/585
COLOR_PRIMARY="#7AA2F7"
POLYBAR_HEIGHT=75

if [ "$1" = "--calendar" ]; then
    if [ "$(xdotool getwindowfocus getwindowname)" = "yad-calendar" ]; then
        xdotool windowkill "$(xdotool getwindowfocus)"
        exit 0
    fi

    YAD_WIDTH=400
    YAD_HEIGHT=220

    eval "$(xdotool getmouselocation --shell)"

    # Anchor to the primary monitor so popups land on the right edge of the
    # primary screen rather than the right edge of the combined desktop.
    read WIDTH HEIGHT X_OFFSET Y_OFFSET < <(xrandr --query 2> /dev/null | sed -nE 's/.* primary ([0-9]+)x([0-9]+)\+([0-9]+)\+([0-9]+).*/\1 \2 \3 \4/p' | head -1)
    if [ -z "$WIDTH" ]; then
        eval "$(xdotool getdisplaygeometry --shell)"
        X_OFFSET=0
        Y_OFFSET=0
    fi

    X_POS="$((X_OFFSET + WIDTH - YAD_WIDTH - 10))"
    Y_POS="$((Y_OFFSET + HEIGHT - YAD_HEIGHT - POLYBAR_HEIGHT - 10))"

    GTK_THEME="Catppuccin-Mocha-Standard-Blue-Dark" yad --calendar \
        --undecorated --fixed --close-on-unfocus --no-buttons \
        --width="$YAD_WIDTH" --height="$YAD_HEIGHT" --posx="$X_POS" --posy="$Y_POS" \
        --title="yad-calendar" --show-weeks > /dev/null &
    exit 0
fi

if [ "$1" = "--toggle-format" ]; then
    if [ -f "$MARKER" ]; then
        rm "$MARKER"
    else
        touch "$MARKER"
    fi
fi

DATE=""
if [ -f "$MARKER" ]; then
    DATE="$(date +"%Y-%m-%d %H:%M:%S")"
else
    DATE="%{F#afccfa}瑞典 $(TZ='Europe/Stockholm' date +"%H:%M")%{F-} %{F#f2c2c2}中国 $(TZ='Asia/Shanghai' date +"%H:%M")%{F-}"
fi
echo "%{F$COLOR_PRIMARY} %{F-} $DATE"
