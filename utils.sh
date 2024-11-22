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
