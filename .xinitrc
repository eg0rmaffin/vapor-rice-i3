# ─── Natural Scrolling ──────
TOUCHPAD_ID=$(xinput list | grep -iE 'touchpad' | grep -o 'id=[0-9]\+' | cut -d= -f2)
if [ -n "$TOUCHPAD_ID" ]; then
    xinput set-prop "$TOUCHPAD_ID" "libinput Natural Scrolling Enabled" 1
fi

#export GTK_THEME=Adwaita-dark
export GTK_THEME=catppuccin-mocha-mauve-standard+default
export XCURSOR_THEME=Catppuccin-Mocha-Cursors
#export BASH_ENV="$HOME/.bashrc_i3"
export PATH="$HOME/.local/bin:$PATH"
exec i3 -c "$HOME/.config/i3/config"
