# ─── Natural Scrolling ──────
TOUCHPAD_ID=$(xinput list | grep -iE 'touchpad' | grep -o 'id=[0-9]\+' | cut -d= -f2)
if [ -n "$TOUCHPAD_ID" ]; then
    xinput set-prop "$TOUCHPAD_ID" "libinput Natural Scrolling Enabled" 1
fi

export GTK_THEME=catppuccin-mocha-mauve-standard+default
export GTK_ICON_THEME=Chicago95

export PATH="$HOME/.local/bin:$PATH"
eval "$(dbus-launch --sh-syntax --exit-with-session)"
exec i3 -c "$HOME/.config/i3/config"
