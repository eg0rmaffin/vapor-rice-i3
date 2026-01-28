#!/usr/bin/env bash
# ─────────────────────────────────────────────
# ⌨️ Vaporwave OSD Keyboard Backlight Indicator
#    Linked by install.sh → ~/.local/bin/kbd-backlight-osd.sh
#    Used by: kbd-backlight.sh
#    Stack: dunst (libnotify)
# ─────────────────────────────────────────────

# Source OSD panel library
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "$SCRIPT_DIR/osd-panel.sh"

# Keyboard backlight OSD ID
OSD_ID_KBD=424

# Find keyboard backlight device
LEDS_DIR="/sys/class/leds"
KBD_BACKLIGHT=""

for pattern in \
    "*::kbd_backlight" \
    "*::keyboard_backlight" \
    "*:white:kbd_backlight" \
    "asus::kbd_backlight" \
    "tpacpi::kbd_backlight" \
    "smc::kbd_backlight" \
    "dell::kbd_backlight" \
    "hp::kbd_backlight" \
    "system76_acpi::kbd_backlight" \
    "chromeos::kbd_backlight"; do
    for device in "$LEDS_DIR"/$pattern; do
        if [ -d "$device" ] && [ -f "$device/brightness" ]; then
            KBD_BACKLIGHT="$device"
            break 2
        fi
    done
done

# Fallback: search for any device containing "kbd" in name
if [ -z "$KBD_BACKLIGHT" ]; then
    for device in "$LEDS_DIR"/*kbd*; do
        if [ -d "$device" ] && [ -f "$device/brightness" ]; then
            KBD_BACKLIGHT="$device"
            break
        fi
    done
fi

# No keyboard backlight found
if [ -z "$KBD_BACKLIGHT" ]; then
    osd_show_status "kbd-backlight-osd" "$OSD_ID_KBD" "⌨️" "No keyboard backlight"
    exit 0
fi

# Get brightness values
MAX_BRIGHTNESS=$(cat "$KBD_BACKLIGHT/max_brightness" 2>/dev/null || echo "1")
CURRENT=$(cat "$KBD_BACKLIGHT/brightness" 2>/dev/null || echo "0")

# Calculate percentage for progress bar
if [ "$MAX_BRIGHTNESS" -gt 0 ]; then
    PERCENT=$((CURRENT * 100 / MAX_BRIGHTNESS))
else
    PERCENT=0
fi

# Choose emoji based on brightness level
if [ "$CURRENT" -eq 0 ]; then
    EMOJI="🌑"
    LABEL="Off"
elif [ "$PERCENT" -le 33 ]; then
    EMOJI="🌘"
    LABEL="Low"
elif [ "$PERCENT" -le 66 ]; then
    EMOJI="🌓"
    LABEL="Medium"
else
    EMOJI="🌕"
    LABEL="High"
fi

osd_show_progress "kbd-backlight-osd" "$OSD_ID_KBD" "⌨️$EMOJI" "Keyboard $LABEL" "$PERCENT"
