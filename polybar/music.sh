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
    local artist="$(playerctl metadata artist)"
    local title="$(playerctl metadata title)"
    if [ -n "$artist" ]; then
        echo "$artist - $title"
    else
        echo "$title"
    fi
}

if [ "$player_status" = "Playing" ]; then
    meta="$(metadata)"
    echo "$meta" > /tmp/polybar_music

    # Split the title (metadata) into two parts based on the seeker position.
    # Underline the first part, but not the second.
    length="$(playerctl metadata --format "{{ mpris:length }}")"
    position="$(playerctl metadata --format "{{ position }}")"
    # Strange calculation due to rounding, we want the progress bar to start empty and end full
    let progress_chars=(${#meta} * position + length / 2)/length
    bef=${meta:0:$progress_chars}
    aft=${meta:$progress_chars}

    echo "%{F#FFFFFF}%{u$COLOR_PRIMARY}%{+u}$bef%{-u}$aft%{F-}"
elif [ "$player_status" = "Paused" ]; then
    if [ -f /tmp/polybar_music ]; then
        echo "%{F$COLOR_DISABLED}$(cat /tmp/polybar_music)%{F-}"
    else
        echo "%{F$COLOR_DISABLED}Music paused%{F-}"
    fi
else
    echo "No music is playing"
fi
