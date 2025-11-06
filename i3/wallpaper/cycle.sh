#!/bin/bash
set -euo pipefail

# Based on the images in this repo:
# https://github.com/manishprivet/dynamic-gnome-wallpapers

cd "$(dirname -- "${BASH_SOURCE[0]}")"

if [ -n "$(pidof -x "$0" -o "$$")" ]; then
    echo "Already running, abort!"
    exit 0
fi

# target="Lakeside"
target="Lakeside-2"
# target="Big_Sur_Beach"
# target="Firewatch"
# target="A_Certain_Magical_Index"

debug=false

if [ ! -d "$target" ]; then
    echo "Downloading images for $target..."
    wget -q -O "$target.zip" "https://cdn.manishk.dev/v2%2F$target.zip"
    unzip -d "$target" "$target.zip" "*.jpg"
    rm "$target.zip"
fi

num_img="$(ls -l $target/* | wc -l)"

function next_image() {
    max_minutes=$((24 * 60))
    minutes=$(($(date "+10#%H * 60 + 10#%M")))
    image=$((num_img * minutes / max_minutes + 1))
    echo $image
}

function next_image_dbg() {
    echo "$((count % num_img + 1))"
}

count=0
while true; do
    if [ "$debug" = "true" ]; then
        img="$(next_image_dbg)"
        sleep_time=3
    else
        img="$(next_image)"
        sleep_time=60
    fi
    echo "Using image $target-$img"
    if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
        pid="$(pidof swaybg || echo "")"
        swaybg -m fill -i "$target/$target-$img.*"
        if [ -n "$pid" ]; then
            kill "$pid"
        fi
    else
        feh --bg-scale --zoom fill "$target/$target-$img.*"
    fi
    sleep $sleep_time
    ((++count))
done
