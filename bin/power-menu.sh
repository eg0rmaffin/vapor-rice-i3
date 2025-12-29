#!/bin/bash
# ─────────────────────────────────────────────
# ⚡ Vaporwave Power Menu (Win95 Style)
#    A E S T H E T I C   S H U T D O W N
#    Uses rofi with custom vaporwave theme
# ─────────────────────────────────────────────

# Rofi theme path
THEME="$HOME/dotfiles/rofi/power-menu.rasi"

# Power menu options with retro icons
declare -A options=(
    ["  Shutdown"]="shutdown"
    ["  Reboot"]="reboot"
    ["  Suspend"]="suspend"
    ["  Lock"]="lock"
    ["  Logout"]="logout"
    ["  Cancel"]="cancel"
)

# Build the menu string (order matters for aesthetics)
menu_order=(
    "  Shutdown"
    "  Reboot"
    "  Suspend"
    "  Lock"
    "  Logout"
    "  Cancel"
)

# Create menu string
menu=""
for item in "${menu_order[@]}"; do
    menu+="$item\n"
done

# Show rofi menu
chosen=$(echo -e "$menu" | rofi -dmenu -i -p "⚡ Power" -theme "$THEME" 2>/dev/null)

# If rofi failed or no selection, exit
[ -z "$chosen" ] && exit 0

# Get action from selection
action="${options[$chosen]}"

# Confirmation for destructive actions
confirm_action() {
    local msg="$1"
    confirm=$(echo -e "  Yes\n  No" | rofi -dmenu -i -p "$msg" -theme "$THEME" 2>/dev/null)
    [[ "$confirm" == *"Yes"* ]]
}

# Execute action
case "$action" in
    shutdown)
        if confirm_action "Shutdown now?"; then
            # Play shutdown sound if available
            [ -f ~/dotfiles/sounds/shutdown.wav ] && paplay ~/dotfiles/sounds/shutdown.wav &
            notify-send -u critical -t 2000 --app-name="power-menu" \
                "⚡ Shutting down..." "It's now safe to turn off your computer"
            sleep 1
            systemctl poweroff
        fi
        ;;
    reboot)
        if confirm_action "Reboot now?"; then
            [ -f ~/dotfiles/sounds/shutdown.wav ] && paplay ~/dotfiles/sounds/shutdown.wav &
            notify-send -u critical -t 2000 --app-name="power-menu" \
                "⚡ Rebooting..." "Windows is restarting"
            sleep 1
            systemctl reboot
        fi
        ;;
    suspend)
        notify-send -u low -t 1500 --app-name="power-menu" \
            "💤 Suspending..." "Sweet vaporwave dreams"
        sleep 0.5
        systemctl suspend
        ;;
    lock)
        # Try different lock commands
        if command -v i3lock &>/dev/null; then
            i3lock -c 1a1a2e
        elif command -v swaylock &>/dev/null; then
            swaylock -c 1a1a2e
        else
            notify-send -u normal -t 2000 --app-name="power-menu" \
                "🔒 Lock" "No screen locker found"
        fi
        ;;
    logout)
        if confirm_action "Logout now?"; then
            notify-send -u normal -t 1500 --app-name="power-menu" \
                "👋 Logging out..." "See you in the vapor"
            sleep 0.5
            i3-msg exit 2>/dev/null || swaymsg exit 2>/dev/null || loginctl terminate-user "$USER"
        fi
        ;;
    cancel|*)
        exit 0
        ;;
esac
