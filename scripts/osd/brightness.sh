#!/usr/bin/env bash
# ─────────────────────────────────────────────
# 🔆 Vaporwave OSD Brightness Indicator
#    Linked by install.sh → ~/.local/bin/brightness-osd.sh
#    Used by: i3 config brightness keys
#    Stack: sysfs backlight + dunst (libnotify)
# ─────────────────────────────────────────────

# Source OSD panel library
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "$SCRIPT_DIR/osd-panel.sh"

# ─────────────────────────────────────────────
# Detect backlight device (same logic as bin/brightness.sh)
# ─────────────────────────────────────────────
BACKLIGHT_DIR="/sys/class/backlight"
BACKLIGHT_DEVICE=""

# Priority: intel_backlight > amdgpu_bl* > acpi_video* > any (except ideapad)
for pattern in "intel_backlight" "amdgpu_bl" "acpi_video"; do
    for device in "$BACKLIGHT_DIR"/$pattern*; do
        if [ -d "$device" ]; then
            BACKLIGHT_DEVICE="$(basename "$device")"
            break 2
        fi
    done
done

# Fallback - any device except ideapad
if [ -z "$BACKLIGHT_DEVICE" ]; then
    for device in "$BACKLIGHT_DIR"/*; do
        if [ -d "$device" ]; then
            name="$(basename "$device")"
            if [ "$name" != "ideapad" ]; then
                BACKLIGHT_DEVICE="$name"
                break
            fi
        fi
    done
fi

# No backlight found - show error notification
if [ -z "$BACKLIGHT_DEVICE" ]; then
    osd_show_status "brightness-osd" "$OSD_ID_BRIGHTNESS" "❌" "Backlight not found"
    exit 1
fi

# ─────────────────────────────────────────────
# Calculate brightness percentage
# ─────────────────────────────────────────────
MAX_BRIGHTNESS=$(cat "$BACKLIGHT_DIR/$BACKLIGHT_DEVICE/max_brightness")
CURRENT=$(cat "$BACKLIGHT_DIR/$BACKLIGHT_DEVICE/brightness")
PERCENT=$((CURRENT * 100 / MAX_BRIGHTNESS))

# Choose icon based on brightness level
if [ "$PERCENT" -ge 70 ]; then
    ICON="🔆"
elif [ "$PERCENT" -ge 30 ]; then
    ICON="🔅"
else
    ICON="🌑"
fi

osd_show_progress "brightness-osd" "$OSD_ID_BRIGHTNESS" "$ICON" "Brightness $PERCENT%" "$PERCENT"
