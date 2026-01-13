#!/bin/bash
# ─────────────────────────────────────────────
# ⚡ Vaporwave Power Menu (Win95 Style)
#    A E S T H E T I C   S H U T D O W N
#    Uses rofi with custom vaporwave theme
#
#    Authentic Win95 shutdown dialog recreation:
#    - Power options at top (Shutdown, Restart)
#    - Session options separate (Log off, Suspend)
#    - Lock screen at bottom (was screensaver in Win95)
# ─────────────────────────────────────────────

# Rofi theme path
THEME="$HOME/dotfiles/rofi/power-menu.rasi"

# Power menu options - Win95 authentic style
# In Windows 95, the shutdown dialog had radio buttons with:
#   ○ Shut down the computer?
#   ○ Restart the computer?
#   ○ Restart in MS-DOS mode?
# Lock was separate (Ctrl+Alt+Del or screensaver)
declare -A options=(
    ["  Shut down"]="shutdown"
    ["  Restart"]="reboot"
    ["  Stand by"]="suspend"
    ["  Log off"]="logout"
    ["  Lock workstation"]="lock"
    ["  Cancel"]="cancel"
)

# Build the menu string (order matters for aesthetics)
# Win95-like order: power actions first, then session, then lock
menu_order=(
    "  Shut down"
    "  Restart"
    "  Stand by"
    "  Log off"
    "  Lock workstation"
    "  Cancel"
)

# Create menu string
menu=""
for item in "${menu_order[@]}"; do
    menu+="$item\n"
done

# Show rofi menu - Win95 style title
chosen=$(echo -e "$menu" | rofi -dmenu -i -p "Shut Down Windows" -theme "$THEME" 2>/dev/null)

# If rofi failed or no selection, exit
[ -z "$chosen" ] && exit 0

# Get action from selection
action="${options[$chosen]}"

# Confirmation for destructive actions - Win95 style Yes/No
confirm_action() {
    local msg="$1"
    confirm=$(echo -e "  Yes\n  No" | rofi -dmenu -i -p "$msg" -theme "$THEME" 2>/dev/null)
    [[ "$confirm" == *"Yes"* ]]
}

# Win95 style "Are you sure?" confirmation
confirm_shutdown() {
    confirm=$(echo -e "  Yes\n  No" | rofi -dmenu -i -p "Are you sure?" -theme "$THEME" 2>/dev/null)
    [[ "$confirm" == *"Yes"* ]]
}

# Execute action
case "$action" in
    shutdown)
        if confirm_shutdown; then
            # Play shutdown sound if available
            [ -f ~/dotfiles/sounds/shutdown.wav ] && paplay ~/dotfiles/sounds/shutdown.wav &
            # Classic Win95 message
            notify-send -u critical -t 3000 --app-name="power-menu" \
                "Windows is shutting down" "It's now safe to turn off your computer."
            sleep 1
            systemctl poweroff
        fi
        ;;
    reboot)
        if confirm_shutdown; then
            [ -f ~/dotfiles/sounds/shutdown.wav ] && paplay ~/dotfiles/sounds/shutdown.wav &
            # Win95 style restart message
            notify-send -u critical -t 2000 --app-name="power-menu" \
                "Windows is restarting" "Please wait while your computer restarts."
            sleep 1
            systemctl reboot
        fi
        ;;
    suspend)
        # Stand by - no confirmation needed (quick action)
        notify-send -u low -t 1500 --app-name="power-menu" \
            "Stand by" "Entering low power mode..."
        sleep 0.5
        systemctl suspend
        ;;
    lock)
        # Lock workstation - Win95/NT style
        # No notification needed - just lock immediately
        if command -v i3lock &>/dev/null; then
            # Use i3lock with vaporwave color
            i3lock -c 1a1a2e
        elif command -v swaylock &>/dev/null; then
            swaylock -c 1a1a2e
        else
            notify-send -u normal -t 2000 --app-name="power-menu" \
                "Lock Workstation" "No screen locker installed."
        fi
        ;;
    logout)
        if confirm_action "Log off Windows?"; then
            notify-send -u normal -t 1500 --app-name="power-menu" \
                "Logging off" "Saving your settings..."
            sleep 0.5
            i3-msg exit 2>/dev/null || swaymsg exit 2>/dev/null || loginctl terminate-user "$USER"
        fi
        ;;
    cancel|*)
        exit 0
        ;;
esac
