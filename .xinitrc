# ─── Natural Scrolling ──────
TOUCHPAD_ID=$(xinput list | grep -iE 'touchpad' | grep -o 'id=[0-9]\+' | cut -d= -f2)
if [ -n "$TOUCHPAD_ID" ]; then
    xinput set-prop "$TOUCHPAD_ID" "libinput Natural Scrolling Enabled" 1
fi

export GTK_THEME=catppuccin-mocha-mauve-standard+default
export GTK_ICON_THEME=Chicago95
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

export PATH="$HOME/.local/bin:$PATH"
eval "$(dbus-launch --sh-syntax --exit-with-session)"

# 🎹 Клавиатура
setxkbmap -layout us,ru -option grp:alt_shift_toggle

# 🔊 Ретро-звук при старте X
paplay ~/dotfiles/sounds/startup.wav 2>/dev/null &

exec i3 -c "$HOME/.config/i3/config"
