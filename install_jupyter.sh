#!/bin/bash
set -euo pipefail

. utils.sh

# TODO: Improve syntax highlight
# - Currently it's not possible to change colors for stack traces, etc... because they are hard coded, see:
#   https://github.com/ipython/ipython/issues/289

if is_ubuntu; then
    sudo apt-get -yq install jupyter-qtconsole python3-pickleshare
else
    echo "Not implemented!"
    exit 1
fi
pip3 install --break-system-packages catppuccin

symlink_path "$HOME" .jupyter jupyter
