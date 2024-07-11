#!/bin/sh

sleep 0.5

# Icon is based on this site:
# - https://thenounproject.com/icon/geometry-1484969/

screenshot="/tmp/screen.png"
icon="$HOME/Repositories/dotfiles/i3/lock_icon.png"

scrot "$screenshot"

convert "$screenshot" -filter Gaussian -thumbnail 20% -sample 500% "$screenshot"
convert "$screenshot" "$icon" -gravity center -composite "$screenshot"

# BLANK='#00000000'
# CLEAR='#ffffff22'
# DEFAULT='#00897bE6'
# TEXT='#00897bE6'
# WRONG='#880000bb'
# VERIFYING='#00564dE6'

DARK='#1E1D2FE6'
BLANK='#00000000'
TEXT='#D9E0EEE6'
WRONG='#A54242E6'
VERIFYING='#7AA2F7E6'

i3lock \
    --verif-text="" \
    --wrong-text="" \
    --noinput-text="" \
    --time-str="%H:%M" \
    --date-str="" \
    --time-pos="ix:iy-r-20" \
    --ind-pos="x+w/2:y+h/2-13" \
    --time-font="Fira Code Nerd Font SemBd" \
    --time-size=64 \
    --timeoutline-color=$DARK \
    --timeoutline-width=2 \
    --ring-width=4 \
    --radius=105 \
    --insidever-color=$BLANK \
    --ringver-color=$VERIFYING \
    --insidewrong-color=$BLANK \
    --ringwrong-color=$WRONG \
    --inside-color=$BLANK \
    --ring-color=$BLANK \
    --line-color=$BLANK \
    --separator-color=$BLANK \
    --verif-color=$TEXT \
    --wrong-color=$TEXT \
    --time-color=$TEXT \
    --date-color=$TEXT \
    --layout-color=$TEXT \
    --keyhl-color=$DARK \
    --bshl-color=$WRONG \
    --screen 1 \
    --clock \
    --indicator \
    -i "$screenshot" \
    $@

rm "$screenshot"
