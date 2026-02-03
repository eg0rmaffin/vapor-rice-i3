#!/bin/bash
# bin/kbd-backlight.sh - universal keyboard backlight control for laptops
# Declarative keyboard lighting support with auto-detected brightness levels

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

# Declaratively detect available brightness levels
# Returns array of levels: 0 (off), low, medium (if applicable), max
get_brightness_levels() {
    local levels=()

    # Always include off (0)
    levels+=(0)

    if [ "$MAX_BRIGHTNESS" -eq 1 ]; then
        # Binary on/off only (max=1)
        levels+=($MAX_BRIGHTNESS)
    elif [ "$MAX_BRIGHTNESS" -eq 2 ]; then
        # Three levels: off, low, high
        levels+=(1 2)
    elif [ "$MAX_BRIGHTNESS" -le 4 ]; then
        # Few levels: off, mid, max
        local mid=$((MAX_BRIGHTNESS / 2))
        [ "$mid" -lt 1 ] && mid=1
        levels+=($mid $MAX_BRIGHTNESS)
    else
        # Many levels available: off, low (~33%), high (~66%), max
        local low=$((MAX_BRIGHTNESS / 3))
        local high=$((MAX_BRIGHTNESS * 2 / 3))
        [ "$low" -lt 1 ] && low=1
        [ "$high" -le "$low" ] && high=$((low + 1))
        levels+=($low $high $MAX_BRIGHTNESS)
    fi

    echo "${levels[@]}"
}

# Find the next brightness level in the cycle
# Cycle order: off -> low -> high -> max -> off
get_next_level() {
    local current=$1
    local levels=($(get_brightness_levels))
    local num_levels=${#levels[@]}

    # Find current position in levels array (or closest lower)
    local current_idx=0
    for ((i=0; i<num_levels; i++)); do
        if [ "$current" -ge "${levels[$i]}" ]; then
            current_idx=$i
        fi
    done

    # Move to next level (wrap around to 0)
    local next_idx=$(( (current_idx + 1) % num_levels ))
    echo "${levels[$next_idx]}"
}

# OSD notification helper
show_osd() {
    local osd_script="$HOME/.local/bin/kbd-backlight-osd.sh"
    if [ -x "$osd_script" ]; then
        "$osd_script"
    fi
}

case "$1" in
    up)
        NEW=$((CURRENT + STEP))
        if [ "$NEW" -gt "$MAX_BRIGHTNESS" ]; then
            NEW=$MAX_BRIGHTNESS
        fi
        echo "$NEW" > "$BRIGHTNESS_FILE"
        show_osd
        ;;
    down)
        NEW=$((CURRENT - STEP))
        if [ "$NEW" -lt 0 ]; then
            NEW=0
        fi
        echo "$NEW" > "$BRIGHTNESS_FILE"
        show_osd
        ;;
    toggle)
        # Toggle between 0 and max
        if [ "$CURRENT" -gt 0 ]; then
            echo "0" > "$BRIGHTNESS_FILE"
        else
            echo "$MAX_BRIGHTNESS" > "$BRIGHTNESS_FILE"
        fi
        show_osd
        ;;
    cycle)
        # Cycle through declaratively detected brightness levels
        # off -> low -> high -> off (number of levels depends on hardware)
        NEW=$(get_next_level "$CURRENT")
        echo "$NEW" > "$BRIGHTNESS_FILE"
        show_osd
        ;;
    max)
        echo "$MAX_BRIGHTNESS" > "$BRIGHTNESS_FILE"
        show_osd
        ;;
    off)
        echo "0" > "$BRIGHTNESS_FILE"
        show_osd
        ;;
    get)
        echo "$CURRENT"
        ;;
    levels)
        # Show available brightness levels (declaratively detected)
        LEVELS=($(get_brightness_levels))
        echo "Available brightness levels: ${LEVELS[*]}"
        echo "Max brightness: $MAX_BRIGHTNESS"
        ;;
    notify)
        # Show OSD notification only (without changing brightness)
        # Used when kernel/firmware already handled the brightness change (e.g. Fn+Space)
        # Small delay to let kernel finish writing brightness value before reading it for OSD
        sleep 0.05
        show_osd
        ;;
    status)
        DEVICE_NAME=$(basename "$KBD_BACKLIGHT")
        LEVELS=($(get_brightness_levels))
        echo "Device: $DEVICE_NAME"
        echo "Current: $CURRENT / $MAX_BRIGHTNESS"
        echo "Available levels: ${LEVELS[*]}"
        ;;
    *)
        echo "Usage: $0 {cycle|up|down|toggle|notify|max|off|get|levels|status}"
        echo ""
        echo "Commands:"
        echo "  cycle   - Cycle through brightness levels (off -> low -> high -> off)"
        echo "  up      - Increase keyboard backlight brightness"
        echo "  down    - Decrease keyboard backlight brightness"
        echo "  toggle  - Toggle keyboard backlight on/off"
        echo "  notify  - Show OSD notification only (for Fn-key handled by kernel)"
        echo "  max     - Set keyboard backlight to maximum"
        echo "  off     - Turn off keyboard backlight"
        echo "  get     - Get current brightness value"
        echo "  levels  - Show available brightness levels (declaratively detected)"
        echo "  status  - Show device info and current state"
        exit 1
        ;;
esac
