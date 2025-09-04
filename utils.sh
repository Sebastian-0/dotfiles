#!/bin/bash

is_ubuntu() {
    grep -q "Ubuntu" /etc/os-release
}

is_arch() {
    grep -q "Manjaro" /etc/os-release
}

symlink_config() {
    if [ $# -ne 1 ]; then
        echo "You must specify a config folder name to link!"
        return 1
    fi
    symlink_path "$HOME/.config" "$1" "$1"
}

symlink_path() {
    if [ $# -ne 3 ]; then
        echo "You must specify a path, target name and dotfile target!"
        return 1
    fi
    local path="$1"
    local name="$2"
    local target="$3"
    if [ ! -L "$path/$name" ]; then
        if [ -e "$path/$name" ]; then
            echo "WARNING: The folder $path/$name exists! Continuing will delete it."
            echo ""
            read -rp "Press enter to continue..."
        fi
        rm -rf "${path:?}/$name"
        ln -s "$PWD/$target" "$path/$name"
    fi
}

nanos_to_str() {
    local time_ns=$1
    shift

    local time_us=$((time_ns / 1000))
    local us=$((time_us % 1000))
    local ms=$(((time_us / 1000) % 1000))
    local s=$(((time_us / 1000000) % 60))
    local m=$(((time_us / 60000000) % 60))
    local h=$((time_us / 3600000000))
    # Goal: always show around 3 digits of accuracy
    if ((h > 0)); then
        text=${h}h${m}m
    elif ((m > 0)); then
        text=${m}m${s}s
    elif ((s >= 10)); then
        text=${s}.$((ms / 100))s
    elif ((s > 0)); then
        text=${s}.$(printf %03d $ms)s
    elif ((ms >= 100)); then
        text=${ms}ms
    elif ((ms > 0)); then
        text=${ms}.$((us / 100))ms
    else
        text=${us}µs
    fi
    echo "$text"
}
