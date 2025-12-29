#!/bin/bash
# bin/kbd-backlight.sh - universal keyboard backlight control for laptops
# Declarative keyboard lighting support

set -e

# Find keyboard backlight device in /sys/class/leds
LEDS_DIR="/sys/class/leds"

KBD_BACKLIGHT=""

# Search for common keyboard backlight patterns
# Priority: specific names first, then generic patterns
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
    echo "No keyboard backlight device found"
    exit 1
fi

# Get max brightness
MAX_BRIGHTNESS=$(cat "$KBD_BACKLIGHT/max_brightness" 2>/dev/null || echo "1")
BRIGHTNESS_FILE="$KBD_BACKLIGHT/brightness"

# Current brightness
CURRENT=$(cat "$BRIGHTNESS_FILE")

# Calculate step (at least 1 step, use ~20% of max or minimum 1)
STEP=$((MAX_BRIGHTNESS / 5))
[ "$STEP" -lt 1 ] && STEP=1

case "$1" in
    up)
        NEW=$((CURRENT + STEP))
        if [ "$NEW" -gt "$MAX_BRIGHTNESS" ]; then
            NEW=$MAX_BRIGHTNESS
        fi
        echo "$NEW" > "$BRIGHTNESS_FILE"
        ;;
    down)
        NEW=$((CURRENT - STEP))
        if [ "$NEW" -lt 0 ]; then
            NEW=0
        fi
        echo "$NEW" > "$BRIGHTNESS_FILE"
        ;;
    toggle)
        # Toggle between 0 and max
        if [ "$CURRENT" -gt 0 ]; then
            echo "0" > "$BRIGHTNESS_FILE"
        else
            echo "$MAX_BRIGHTNESS" > "$BRIGHTNESS_FILE"
        fi
        ;;
    max)
        echo "$MAX_BRIGHTNESS" > "$BRIGHTNESS_FILE"
        ;;
    off)
        echo "0" > "$BRIGHTNESS_FILE"
        ;;
    get)
        echo "$CURRENT"
        ;;
    status)
        DEVICE_NAME=$(basename "$KBD_BACKLIGHT")
        echo "Device: $DEVICE_NAME"
        echo "Current: $CURRENT / $MAX_BRIGHTNESS"
        ;;
    *)
        echo "Usage: $0 {up|down|toggle|max|off|get|status}"
        echo ""
        echo "Commands:"
        echo "  up      - Increase keyboard backlight brightness"
        echo "  down    - Decrease keyboard backlight brightness"
        echo "  toggle  - Toggle keyboard backlight on/off"
        echo "  max     - Set keyboard backlight to maximum"
        echo "  off     - Turn off keyboard backlight"
        echo "  get     - Get current brightness value"
        echo "  status  - Show device info and current state"
        exit 1
        ;;
esac
