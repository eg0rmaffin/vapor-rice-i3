# ─── Natural Scrolling ──────
TOUCHPAD_ID=$(xinput list | grep -iE 'touchpad' | grep -o 'id=[0-9]\+' | cut -d= -f2)
if [ -n "$TOUCHPAD_ID" ]; then
    xinput set-prop "$TOUCHPAD_ID" "libinput Natural Scrolling Enabled" 1
fi

export GTK_THEME=catppuccin-mocha-mauve-standard+default
export GTK_ICON_THEME=Chicago95
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# ─── XDG desktop context ───
export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=i3
export XDG_SESSION_DESKTOP=i3

export PATH="$HOME/.local/bin:$PATH"

# ─── Session D-Bus ───
# The systemd user session (started by pam_systemd on TTY login) provides
# the authoritative D-Bus session bus at $XDG_RUNTIME_DIR/bus.
# We do NOT spawn a second bus with dbus-launch — that causes environment
# desync and breaks PipeWire/WirePlumber/dunst/systemd user services.
# Instead, we only import DISPLAY and XDG desktop context so that systemd
# user services can access the X display.
systemctl --user import-environment DISPLAY XDG_CURRENT_DESKTOP

# 🎹 Клавиатура
setxkbmap -layout us,ru -option grp:alt_shift_toggle

# ─── Disable default X11 DPMS/screensaver ───
# xidlehook will manage idle behavior with media-aware detection
# This prevents screen blanking during video/audio playback
xset s off          # Disable screensaver
xset s noblank      # Disable screen blanking
xset -dpms          # Disable DPMS (Display Power Management Signaling)

# 🔊 Ретро-звук при старте X
paplay ~/dotfiles/sounds/startup.wav 2>/dev/null &

exec i3 -c "$HOME/.config/i3/config"
