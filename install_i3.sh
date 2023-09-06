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
	    sudo apt-get install -y i3 feh wmctrl

	    # Older Ubuntu
	    if [ -n "$(grep "22.04" /etc/os-release)" ]; then
		sudo add-apt-repository ppa:regolith-linux/release
		sudo apt update
		sudo apt install i3-gaps
	    fi
	else
	    # Manjaro
	    sudo pacman -Syu && sudo pacman -S i3 feh i3-dmenu-desktop morc_menu wmctrl
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

echo "Configure i3..."
if [ -z "$(grep "Plasma compatibility improvements" ~/.config/i3/config)" ]; then
    cat <<-EOF >> ~/.config/i3/config

# Keyboard layout
exec_always setxkbmap -layout se -variant swerty

# Background image
exec feh --bg-scale --zoom fill /home/intuicell/Repositories/dotfiles/background.jpg

# Yakuake
exec yakuake

# Borders
default_border pixel 2

# Colors                border  backgr. text    indicator child_border
client.focused          #4c7899 #cc0099 #ffffff #2e9ef4   #cc0099
client.focused_inactive #333333 #5f676a #ffffff #484e50   #5f676a
client.unfocused        #333333 #222222 #888888 #292d2e   #222222
client.urgent           #2f343a #900000 #ffffff #900000   #900000
client.placeholder      #000000 #0c0c0c #ffffff #000000   #0c0c0c

client.background       #ffffff

# Gaps
gaps inner 10
gaps outer 0

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
