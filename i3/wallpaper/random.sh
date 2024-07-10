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
    images=( $(ls "$target" | shuf) )
    for img in ${images[@]}; do
        echo "Using image $img"
        feh --bg-scale --zoom fill "$target/$img"
        sleep $((30*60))
    done
done
