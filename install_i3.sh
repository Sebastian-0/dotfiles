#!/bin/bash
set -euo pipefail

is_ubuntu() {
    if [ -n "$(grep "Ubuntu" /etc/os-release)" ]; then
        echo "true"
    else
        echo "false"
    fi
}

./install_font.sh

echo "This script installs i3, assuming you are using KDE as the desktop manager on Ubuntu or Manjaro!"
echo ""
echo "This might be an outdated script, see: https://github.com/heckelson/i3-and-kde-plasma for the latest info!"
echo ""
read -p "Press enter to start..."

if [ -z "$(which i3)" ]; then
    echo "Installing packages..."
    if [ "$(is_ubuntu)" = "true" ]; then
        # Ubuntu
        sudo apt-get install -y i3 feh xss-lock wmctrl scrot picom dunst rofi pulseaudio-utils playerctl xbacklight polybar flameshot

        # Build i3lock-color
        sudo apt-get install -y autoconf gcc make pkg-config libpam0g-dev libcairo2-dev libfontconfig1-dev libxcb-composite0-dev libev-dev libx11-xcb-dev libxcb-xkb-dev libxcb-xinerama0-dev libxcb-randr0-dev libxcb-image0-dev libxcb-util-dev libxcb-xrm-dev libxkbcommon-dev libxkbcommon-x11-dev libjpeg-dev

        git clone https://github.com/Raymo111/i3lock-color.git
        cd i3lock-color
        ./install-i3lock-color.sh
        cd ..
        rm -rf i3lock-color

        # Clipmenu
        sudo apt-get install -y xsel

        git clone https://github.com/cdown/clipnotify.git
        cd clipnotify
        sudo make install
        cd ..
        sudo rm -rf clipnotify

        git clone https://github.com/cdown/clipmenu.git
        cd clipmenu
        sudo make install
        cd ..
        sudo rm -rf clipmenu

        # Older Ubuntu
        if [ -n "$(grep "22.04" /etc/os-release)" ]; then
            echo "Manually build i3-gaps..."
            sudo apt-get install -y libcairo2-dev libpango1.0-dev libyajl-dev libxcb-icccm4-dev libxcb-keysyms1-dev libxcb-cursor-dev libstartup-notification0-dev xmlto meson asciidoc
            git clone https://github.com/Airblader/i3 i3-gaps
            cd i3-gaps
            git checkout gaps
            meson -Ddocs=true -Dmans=true ../build
            meson compile -C ../build
            sudo meson install -C ../build
            cd ..
            rm -rf build i3-gaps
        fi
    else
        # Manjaro
        sudo pacman -S --needed --noconfirm i3 feh wmctrl picom yay dunst rofi clipmenu playerctl xorg-xbacklight polybar scrot xss-lock flameshot
        sudo yay -S --noconfirm --ask 4 --useask --answerclean All --answerdiff None i3lock-color
    fi

    echo "Launch clipmenud service..."
    systemctl enable --user clipmenud.service
    systemctl start --user clipmenud.service

    echo "Install rofi themes..."
    git clone --depth=1 https://github.com/adi1090x/rofi.git
    cd rofi
    ./setup.sh
    cd ..
    rm -rf rofi
    sed -i 's|@import .*|@import "~/.config/rofi/colors/catppuccin.rasi"|g' ~/.config/rofi/launchers/type-4/shared/colors.rasi
    sed -i 's|@import .*|@import "~/.config/rofi/colors/catppuccin.rasi"|g' ~/.config/rofi/powermenu/type-1/shared/colors.rasi
    sed -i "s/theme='style-1'/theme='style-3'/g" ~/.config/rofi/powermenu/type-1/powermenu.sh
    sed -i "s|\si3lock|$HOME/.config/i3/scripts/lock.sh|g" ~/.config/rofi/powermenu/type-1/powermenu.sh

    echo "Install Polybar theme..."
    mkdir ~/.config/polybar
    cp -r polybar/* ~/.config/polybar/

    echo "Log into an i3 session and relaunch this script to continue installation!"
    exit
fi

echo "Configure i3lock..."
if [ ! -d ~/.config/i3/scripts ]; then
    cp -r i3/scripts ~/.config/i3/scripts
fi

echo "Configure i3..."
if [ -z "$(grep "#### Custom configuration ####" ~/.config/i3/config)" ]; then
    sed -i "s|i3lock|$HOME/.config/i3/scripts/lock.sh|g" ~/.config/i3/config
    sed -i 's/i3-sensible-terminal/kitty/g' ~/.config/i3/config
    sed -i 's|bindsym $mod+d exec --no-startup-id dmenu_run|bindsym $mod+d exec --no-startup-id ~/.config/rofi/launchers/type-4/launcher.sh|g' ~/.config/i3/config
    sed -i 's/bindsym $mod+h split h/bindsym $mod+b split h/g' ~/.config/i3/config
    sed -i 's/bindsym $mod+v split v/bindsym $mod+g split v/g' ~/.config/i3/config

    sed -i 's/bindsym $mod+j focus left/bindsym $mod+h focus left/g' ~/.config/i3/config
    sed -i 's/bindsym $mod+k focus down/bindsym $mod+j focus down/g' ~/.config/i3/config
    sed -i 's/bindsym $mod+l focus up/bindsym $mod+k focus up/g' ~/.config/i3/config
    sed -i 's/bindsym $mod+odiaeresis focus right/bindsym $mod+l focus right/g' ~/.config/i3/config
    sed -i 's/bindsym $mod+semicolon focus right/bindsym $mod+l focus right/g' ~/.config/i3/config

    sed -i 's/bindsym $mod+Shift+j move left/bindsym $mod+Shift+h move left/g' ~/.config/i3/config
    sed -i 's/bindsym $mod+Shift+k move down/bindsym $mod+Shift+j move down/g' ~/.config/i3/config
    sed -i 's/bindsym $mod+Shift+l move up/bindsym $mod+Shift+k move up/g' ~/.config/i3/config
    sed -i 's/bindsym $mod+Shift+odiaeresis move right/bindsym $mod+Shift+l move right/g' ~/.config/i3/config
    sed -i 's/bindsym $mod+Shift+semicolon move right/bindsym $mod+Shift+l move right/g' ~/.config/i3/config

    sed -i 's/bindsym j resize shrink width 10 px or 10 ppt/bindsym h resize shrink width 10 px or 10 ppt/g' ~/.config/i3/config
    sed -i 's/bindsym k resize grow height 10 px or 10 ppt/bindsym j resize grow height 10 px or 10 ppt/g' ~/.config/i3/config
    sed -i 's/bindsym l resize shrink height 10 px or 10 ppt/bindsym k resize shrink height 10 px or 10 ppt/g' ~/.config/i3/config
    sed -i 's/bindsym semicolon resize grow width 10 px or 10 ppt/bindsym l resize grow width 10 px or 10 ppt/g' ~/.config/i3/config
    sed -i 's/bindsym odiaeresis resize grow width 10 px or 10 ppt/bindsym l resize grow width 10 px or 10 ppt/g' ~/.config/i3/config

    sed -i 's/bindsym XF86AudioRaiseVolume .* +10% .*$/bindsym XF86AudioRaiseVolume exec --no-startup-id pactl set-sink-volume @DEFAULT_SINK@ +5% \&\& $refresh_i3status/g' ~/.config/i3/config
    sed -i 's/bindsym XF86AudioLowerVolume .* -10% .*$/bindsym XF86AudioLowerVolume exec --no-startup-id pactl set-sink-volume @DEFAULT_SINK@ -5% \&\& $refresh_i3status/g' ~/.config/i3/config

    sed -zi 's/bar {\n.*\n}//g' ~/.config/i3/config
    cat <<-EOF >> ~/.config/i3/config

#### Custom configuration ####

# Execute programs
exec_always --no-startup-id $HOME/.config/polybar/launch.sh
exec_always --no-startup-id setxkbmap -layout se -variant swerty
exec_always --no-startup-id picom -f -i 0.95 --opacity-rule "100:class_g = 'i3lock'"
exec --no-startup-id $PWD/i3/wallpaper/cycle.sh
exec --no-startup-id yakuake
exec --no-startup-id dunst

# Borders
default_border pixel 3

# Colors                border  backgr. text    indicator child_border
client.focused          #4c7899 #430194 #ffffff #2e9ef4   #430194
client.focused_inactive #333333 #5f676a #ffffff #484e50   #5f676a
client.unfocused        #333333 #222222 #888888 #292d2e   #222222
client.urgent           #2f343a #900000 #ffffff #900000   #900000
client.placeholder      #000000 #0c0c0c #ffffff #000000   #0c0c0c

client.background       #ffffff

# Gaps
gaps inner 10
gaps outer 0

# Keybinds
bindsym F12 exec tdrop -ma -w 90% -x 5% kitty
bindsym \$mod+Shift+S exec flameshot launcher
bindsym \$mod+Ctrl+L exec $HOME/.config/i3/scripts/lock.sh
bindsym \$mod+N exec dunstctl history-pop
bindsym \$mod+V exec "CM_LAUNCHER=rofi clipmenu -i -theme $HOME/.config/rofi/launchers/type-4/style-1.rasi -theme-str 'window {width: 1000px;} listview {scrollbar: true;} scrollbar {margin: 0px 0px 0px 10px;}'"
bindsym \$mod+X exec ~/.config/rofi/powermenu/type-1/powermenu.sh

# Media player controls
bindsym XF86AudioPlay exec playerctl play-pause
bindsym XF86AudioPause exec playerctl play-pause
bindsym XF86AudioNext exec playerctl next
bindsym XF86AudioPrev exec playerctl previous

# Sreen brightness controls
bindsym XF86MonBrightnessUp exec xbacklight -inc 20
bindsym XF86MonBrightnessDown exec xbacklight -dec 20

# Misc
focus_follows_mouse no
EOF
fi
