#!/bin/bash
# bin/kbd-backlight-watcher.sh - Monitor keyboard backlight changes and show OSD
#
# Why this script exists:
#   On many laptops, Fn+Space (keyboard backlight toggle) is handled entirely by
#   the firmware/kernel, and X11 never receives the XF86KbdLightOnOff keypress.
#   This makes i3 bindings for that key ineffective.
#
#   This watcher monitors the sysfs brightness file for changes using inotify,
#   and triggers the dunst OSD notification whenever the brightness changes,
#   regardless of how it was changed (Fn key, software, etc.).
#
# Dependencies: inotify-tools (inotifywait)
#
# Usage: kbd-backlight-watcher.sh {start|stop|status}

set -e

SCRIPT_NAME="kbd-backlight-watcher"
PIDFILE="/tmp/$SCRIPT_NAME.pid"

# Find keyboard backlight device (same logic as kbd-backlight.sh)
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

# Check if inotifywait is available
check_dependencies() {
    if ! command -v inotifywait >/dev/null 2>&1; then
        echo "Error: inotifywait not found. Please install inotify-tools:"
        echo "  Ubuntu/Debian: sudo apt install inotify-tools"
        echo "  Arch Linux: sudo pacman -S inotify-tools"
        echo "  Fedora: sudo dnf install inotify-tools"
        return 1
    fi
    return 0
}

# OSD notification helper
show_osd() {
    local osd_script="$HOME/.local/bin/kbd-backlight-osd.sh"
    if [ -x "$osd_script" ]; then
        "$osd_script"
    fi
}

# Start the watcher daemon
start_watcher() {
    # Check for keyboard backlight device
    if [ -z "$KBD_BACKLIGHT" ]; then
        echo "No keyboard backlight device found, nothing to watch"
        exit 0
    fi

    # Check dependencies
    if ! check_dependencies; then
        exit 1
    fi

    # Check if already running
    if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
        echo "Watcher already running (PID: $(cat "$PIDFILE"))"
        exit 0
    fi

    local brightness_file="$KBD_BACKLIGHT/brightness"

    echo "Starting keyboard backlight watcher..."
    echo "Watching: $brightness_file"

    # Start watcher in background
    (
        # Debounce: ignore rapid successive changes (kernel may write multiple times)
        local last_notify=0
        local debounce_ms=100  # Minimum 100ms between notifications

        while true; do
            # Wait for modify event on brightness file
            inotifywait -q -e modify "$brightness_file" >/dev/null 2>&1

            # Debounce check
            local now_ms=$(($(date +%s%N) / 1000000))
            local diff=$((now_ms - last_notify))

            if [ "$diff" -ge "$debounce_ms" ]; then
                # Small delay to let kernel finish writing the value
                sleep 0.02
                show_osd
                last_notify=$now_ms
            fi
        done
    ) &

    local pid=$!
    echo "$pid" > "$PIDFILE"
    echo "Watcher started (PID: $pid)"
}

# Stop the watcher daemon
stop_watcher() {
    if [ -f "$PIDFILE" ]; then
        local pid
        pid=$(cat "$PIDFILE")
        if kill -0 "$pid" 2>/dev/null; then
            # Kill the main process and all its children (inotifywait)
            pkill -P "$pid" 2>/dev/null || true
            kill "$pid" 2>/dev/null || true
            rm -f "$PIDFILE"
            echo "Watcher stopped (was PID: $pid)"
        else
            rm -f "$PIDFILE"
            echo "Watcher was not running (stale pidfile removed)"
        fi
    else
        echo "Watcher is not running"
    fi
}

# Check watcher status
status_watcher() {
    if [ -z "$KBD_BACKLIGHT" ]; then
        echo "No keyboard backlight device found on this system"
        exit 0
    fi

    echo "Device: $(basename "$KBD_BACKLIGHT")"
    echo "Brightness file: $KBD_BACKLIGHT/brightness"

    if [ -f "$PIDFILE" ]; then
        local pid
        pid=$(cat "$PIDFILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo "Status: Running (PID: $pid)"
        else
            echo "Status: Not running (stale pidfile)"
        fi
    else
        echo "Status: Not running"
    fi

    if ! command -v inotifywait >/dev/null 2>&1; then
        echo "Warning: inotify-tools not installed"
    fi
}

case "$1" in
    start)
        start_watcher
        ;;
    stop)
        stop_watcher
        ;;
    status)
        status_watcher
        ;;
    restart)
        stop_watcher
        sleep 0.5
        start_watcher
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        echo ""
        echo "Monitor keyboard backlight changes and show dunst OSD notification."
        echo "This works even when Fn+Space is handled directly by firmware/kernel"
        echo "and X11 never receives the keypress."
        echo ""
        echo "Commands:"
        echo "  start   - Start the watcher daemon"
        echo "  stop    - Stop the watcher daemon"
        echo "  restart - Restart the watcher daemon"
        echo "  status  - Show watcher status and device info"
        exit 1
        ;;
esac
