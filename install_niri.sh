#!/bin/bash
set -euo pipefail

. utils.sh

./install_font.sh

# Remaining TODO to get shit working:
# - random.sh (and probably cycle.sh) don't work, maybe it's the wrong cwd but it should cd correctly. I don't know why it's broken
# - flameshot does not support wayland. We are using the built in but it's much worse than flameshot (no delay, no edit tools), see: https://github.com/flameshot-org/flameshot/issues/3605
# - waybar is very old and does not have the workspace module, compiling it is a pain but maybe we can use the PPA???
#   - I want to style it myself
#   - When making the bar rounded the missing pieces are black for some reason. It works if nested components are rounded though if the background is transparent.
#   - Waybar launches from systemd when installed through Ubuntu, do I want that? Good: I get log in journald. Bad: I'm not in control of launching it
# - Rofi supports wayland in 2.0.0 but then we need to compile ourselves and that requires a mountain of packages
#   - Current version of Rofi closes itself all the time
# - niri does not support scratch buffers and so ndrop does not work optimally.
#   - Atm the terminal does not disappear again.
#   - Repeated F12 pressing causes it to fly back in
# - Arch support missing
# - Configure swaylock to look acceptable, maybe use hyprlock instead?
# - Install mako to handle notifications instead of dunst
# - Remote desktop does not work (Nomachine supports Wayland so it should work)
# - Missing niri config
#   * Hard code workspaces for keys 1 through 0, or make custom ones for the browser, etc...maku
# - Niri limitations
#   - When launching windows they are always in a new column, cannot start launching within the same column
#   - When entering and then exiting fullscreen the window will become a new column, not return to its old one
#   - Keyboard layout can only be set statically in the niri config, so if swerty becomes unavailable I need to log out and back in to get it to load again! I also cannot change layout dynamically

# Current undo
# sudo apt-get remove -y libpipewire-0.3-dev libdbus-1-dev libinput-dev libseat-dev libdisplay-info-dev libgbm-dev libsystemd-dev
# sudo apt-get remove -y fuzzel

if ! which niri > /dev/null; then
    # Dependencies
    rustup update
    sudo apt-get install --no-install-recommends -yq gcc clang libudev-dev libgbm-dev libxkbcommon-dev libegl1-mesa-dev libwayland-dev libinput-dev libdbus-1-dev libsystemd-dev libseat-dev libpipewire-0.3-dev libpango1.0-dev libdisplay-info-dev

    # Temporary dependency until we get rofi working
    sudo apt-get install --no-install-recommends -yq fuzzel

    # Build and install
    git clone https://github.com/YaLTeR/niri.git --branch v25.08
    cd niri
    cargo build --release
    sudo cp ./target/release/niri /usr/bin/niri
    sudo cp ./resources/niri-session /usr/bin/niri-session
    sudo cp ./resources/niri.desktop /usr/share/wayland-sessions/niri.desktop
    sudo cp ./resources/niri-portals.conf /usr/share/xdg-desktop-portal/niri-portals.conf
    sudo cp ./resources/niri.service /etc/systemd/user/niri.service
    sudo cp ./resources/niri-shutdown.target /etc/systemd/user/niri-shutdown.target
    cd ..
    rm -rf niri
fi

if ! which xwayland-satellite > /dev/null; then
    # Dependencies
    rustup update

    # Build and install
    git clone https://github.com/YaLTeR/niri.git --branch v25.08
    git clone https://github.com/Supreeeme/xwayland-satellite.git --branch v0.7
    cd xwayland-satellite
    cargo build --release
    sudo cp ./xwayland-satellite/target/release/xwayland-satellite /usr/bin/xwayland-satellite
    cd ..
    rm -rf xwayland-satellite
fi

# Install utilities to make things work

# For nvim
sudo apt-get install --no-install-recommends -yq wl-clipboard

# For background
sudo apt-get install --no-install-recommends -yq swaybg

# For locking
sudo apt-get install --no-install-recommends -yq swaylock

# For dropdown
if ! which ndrop >&/dev/null; then
    if is_ubuntu; then
        sudo apt-get install -yq --no-install-recommends scdoc
    else
        sudo pacman -S --needed --noconfirm scdoc
    fi
    git clone https://github.com/Schweber/ndrop.git
    cd ndrop
    git checkout 0feb899
    sudo make install
    cd ..
    rm -rf ndrop
fi

# For clipboard history
sudo apt-get install -yq --no-install-recommends cliphist

# Status bar
sudo apt-get install -yq --no-install-recommends waybar pavucontrol

# TODO Manual install requires too many deps, use the PPA?
# if ! which waybar > /dev/null; then
#     sudo apt-get install -yq --no-install-recommends cmake meson scdoc wayland-protocols libgtkmm-3.0-dev libxkbregistry-dev
#
#     git clone https://github.com/Alexays/Waybar --branch 0.14.0
#     cd Waybar
#     meson setup build
#     ninja -C build
#     # ./build/waybar
#     # ninja -C build install
#     cd ..
#     # rm -rf Waybar
# fi

echo "Configure niri..."
symlink_config niri

echo "Configure waybar..."
symlink_config waybar
