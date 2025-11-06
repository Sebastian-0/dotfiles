#!/bin/bash
set -euo pipefail

cd "$(dirname -- "${BASH_SOURCE[0]}")"

if [ -n "$(pidof -x "$0" -o "$$")" ]; then
    echo "Already running, abort!"
    exit 0
fi

# target="Lakeside"
# target="Lakeside-2"
# target="Big_Sur_Beach"
# target="Firewatch"
# target="A_Certain_Magical_Index"
# target="Minimal-Mojave"
# target="nasa"
target="Ghibli"

while true; do
    images=($(find "$target" | shuf))
    for img in "${images[@]}"; do
        echo "Using image $img"
        if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
            pid="$(pidof swaybg || echo "")"
            swaybg -m fill -i "$img" &
            if [ -n "$pid" ]; then
                kill "$pid"
            fi
        else
            feh --bg-scale --zoom fill "$img"
        fi
        sleep $((30 * 60))
    done
done
