#!/bin/bash
set -euo pipefail

is_ubuntu() {
    if [ -n "$(grep "Ubuntu" /etc/os-release)" ]; then
        echo "true"
    else
        echo "false"
    fi
}

is_at_least_version() {
    version="$1"
    plasma_version="$(plasmashell --version | cut -d ' ' -f2)"
    latest="$(echo -e "$plasma_version\n$version" | sort -V | tail -n1)"
    if [ "$latest" = "$version" ]; then
        echo "false"
    else
        echo "true"
    fi
}

echo "This script installs i3, assuming you are using KDE as the desktop manager on Ubuntu or Manjaro!"
echo ""
echo "This might be an outdated script, see: https://github.com/heckelson/i3-and-kde-plasma for the latest info!"
echo ""
read -p "Press enter to start..."

if [ -z "$(which i3)" ]; then
    echo "Installing packages..."
    if [ "$(is_ubuntu)" = "true" ]; then
        # Ubuntu
        sudo apt-get install -y i3 feh wmctrl scrot picom

        # Build i3lock-color
        sudo apt-get install autoconf gcc make pkg-config libpam0g-dev libcairo2-dev libfontconfig1-dev libxcb-composite0-dev libev-dev libx11-xcb-dev libxcb-xkb-dev libxcb-xinerama0-dev libxcb-randr0-dev libxcb-image0-dev libxcb-util-dev libxcb-xrm-dev libxkbcommon-dev libxkbcommon-x11-dev libjpeg-dev

        git clone https://github.com/Raymo111/i3lock-color.git
        cd i3lock-color
        ./install-i3lock-color.sh
        cd ..
        rm -rf i3lock-color

        # Older Ubuntu
        if [ -n "$(grep "22.04" /etc/os-release)" ]; then
            sudo add-apt-repository ppa:regolith-linux/release
            sudo apt update
            sudo apt install i3-gaps
        fi
    else
        # Manjaro
        sudo pacman -Syu && sudo pacman -S i3 feh i3-dmenu-desktop morc_menu wmctrl picom
    fi
    echo "Log into an i3 session and relaunch this script to continue installation!"
    exit
fi

echo "Creating session entry..."
cat <<EOF > plasma-i3.desktop
[Desktop Entry]
Type=XSession
Exec=env KDEWM=/usr/bin/i3 /usr/bin/startplasma-x11
DesktopNames=KDE
Name=Plasma with i3
Comment=Plasma with i3
EOF
sudo mv plasma-i3.desktop /usr/share/xsessions/plasma-i3.desktop

if [ "$(is_at_least_version 5.25)" = "true" ]; then
    kwriteconfig5 --file startkderc --group General --key systemdBoot false
fi

echo "Configure i3lock..."
if [ ! -f ~/.config/i3/scripts/lock.sh ]; then
    mkdir ~/.config/i3/scripts
    cat <<-'EOF' >> ~/.config/i3/scripts/lock.sh
#!/bin/sh

BLANK='#00000000'
CLEAR='#ffffff22'
DEFAULT='#00897bE6'
TEXT='#00897bE6'
WRONG='#880000bb'
VERIFYING='#00564dE6'

i3lock \
--insidever-color=$CLEAR     \
--ringver-color=$VERIFYING   \
\
--insidewrong-color=$CLEAR   \
--ringwrong-color=$WRONG     \
\
--inside-color=$BLANK        \
--ring-color=$DEFAULT        \
--line-color=$BLANK          \
--separator-color=$DEFAULT   \
\
--verif-color=$TEXT          \
--wrong-color=$TEXT          \
--time-color=$TEXT           \
--date-color=$TEXT           \
--layout-color=$TEXT         \
--keyhl-color=$WRONG         \
--bshl-color=$WRONG          \
\
--screen 1                   \
--blur 9                     \
--clock                      \
--indicator                  \
--time-str="%H:%M:%S"        \
--date-str="%A, %Y-%m-%d"    \
--keylayout 1                \
EOF
fi

# TODO Replace fixed path with $HOME and subtitution for / to \/
echo "Configure i3..."
if [ -z "$(grep "Plasma compatibility improvements" ~/.config/i3/config)" ]; then
    sed -i 's/i3lock/\/home\/intuicell\/.config\/i3\/scripts\/lock.sh/g' ~/.config/i3/config
    sed -i 's/i3-sensible-terminal/konsole/g' ~/.config/i3/config
    cat <<-EOF >> ~/.config/i3/config

# Execute programs
exec_always setxkbmap -layout se -variant swerty
exec_always picom -f
exec feh --bg-scale --zoom fill /home/intuicell/Repositories/dotfiles/background.jpg
exec yakuake

# Borders
default_border pixel 3

# Colors                border  backgr. text    indicator child_border
client.focused          #4c7899 #e65c00 #ffffff #2e9ef4   #e65c00
client.focused_inactive #333333 #5f676a #ffffff #484e50   #5f676a
client.unfocused        #333333 #222222 #888888 #292d2e   #222222
client.urgent           #2f343a #900000 #ffffff #900000   #900000
client.placeholder      #000000 #0c0c0c #ffffff #000000   #0c0c0c

client.background       #ffffff

# Gaps
gaps inner 10
gaps outer 0

# Keybinds
bindsym \$mod+Shift+S exec spectacle
bindsym \$mod+Ctrl+L exec $HOME/.config/i3/scripts/lock.sh

# Misc
focus_follows_mouse no

# Plasma compatibility improvements
for_window [window_role="pop-up"] floating enable
for_window [window_role="task_dialog"] floating enable

for_window [class="yakuake"] floating enable
for_window [class="systemsettings"] floating enable
for_window [class="plasmashell"] floating enable;
for_window [class="Plasma"] floating enable; border none
for_window [title="plasma-desktop"] floating enable; border none
for_window [title="win7"] floating enable; border none
for_window [class="krunner"] floating enable; border none
for_window [class="Kmix"] floating enable; border none
for_window [class="Klipper"] floating enable; border none
for_window [class="Plasmoidviewer"] floating enable; border none
for_window [class="(?i)*nextcloud*"] floating disable
for_window [class="plasmashell" window_type="notification"] border none, move position 70 ppt 81 ppt
no_focus [class="plasmashell" window_type="notification"]
EOF

    if [ "$(is_at_least_version 5.27)" = "true" ]; then
        echo 'for_window [title="Desktop @ QRect.*"] kill; floating enable; border none' >> ~/.config/i3/config
    else
        echo 'for_window [title="Desktop — Plasma"] kill; floating enable; border none' >> ~/.config/i3/config
    fi
fi
