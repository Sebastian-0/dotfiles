#!/bin/bash

player_status=$(playerctl status 2> /dev/null)

# Copied from polybar config, currently not possible to pass here without an ugly solution:
# https://github.com/polybar/polybar/issues/585
COLOR_DISABLED="#707880"
COLOR_PRIMARY="#7AA2F7"

if [ "$1" = "--play-pause-icon" ]; then
    if [ "$player_status" = "Playing" ]; then
        echo "%{F$COLOR_PRIMARY}󰏤%{F-}"
    elif [ "$player_status" = "Paused" ]; then
        echo "%{F$COLOR_PRIMARY}󰐊%{F-}"
    else
        echo "%{F$COLOR_DISABLED}󰐊%{F-}"
    fi
    exit 0
fi

if [ "$1" = "--next-icon" ]; then
    if [ "$player_status" = "Playing" ] || [ "$player_status" = "Paused" ]; then
        echo "%{F$COLOR_PRIMARY}󰒭%{F-}"
    else
        echo "%{F$COLOR_DISABLED}󰒭%{F-}"
    fi
    exit 0
fi

if [ "$1" = "--prev-icon" ]; then
    if [ "$player_status" = "Playing" ] || [ "$player_status" = "Paused" ]; then
        echo "%{F$COLOR_PRIMARY}󰒮%{F-}"
    else
        echo "%{F$COLOR_DISABLED}󰒮%{F-}"
    fi
    exit 0
fi

function metadata() {
    artist="$(playerctl metadata artist)"
    title="$(playerctl metadata title)"
    if [ -n "$artist" ]; then
        echo "$artist - $title"
    else
        echo "$title"
    fi
}

if [ "$player_status" = "Playing" ]; then
    echo "$(metadata)" > /tmp/polybar_music
    echo "%{F#FFFFFF}$(metadata)%{F-}"
elif [ "$player_status" = "Paused" ]; then
    echo "%{F$COLOR_DISABLED}$(cat /tmp/polybar_music)%{F-}"
else
    echo "No music is playing"
fi
