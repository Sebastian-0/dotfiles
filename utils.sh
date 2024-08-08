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
        exit 1
    fi
    local name=$1
    if [ ! -L "$HOME/.config/$name" ]; then
        if [ -e "$HOME/.config/$name" ]; then
            echo "WARNING: The folder ~/.config/$name exists! Continuing will delete it."
            echo ""
            read -rp "Press enter to continue..."
        fi
        rm -rf "$HOME/.config/$name"
        ln -s "$PWD/$name" "$HOME/.config/$name"
    fi
}
