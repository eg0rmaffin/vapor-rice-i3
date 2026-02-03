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
# Usage:
#   kbd-backlight-watcher.sh run     - Run in foreground (for systemd)
#   kbd-backlight-watcher.sh start   - Start as background daemon
#   kbd-backlight-watcher.sh stop    - Stop daemon
#   kbd-backlight-watcher.sh status  - Show status

# Don't exit on error - we handle errors gracefully
set +e

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

# Get or discover D-Bus session bus address
# This is needed for notify-send to communicate with dunst
get_dbus_address() {
    # First, try environment variable
    if [ -n "$DBUS_SESSION_BUS_ADDRESS" ]; then
        echo "$DBUS_SESSION_BUS_ADDRESS"
        return
    fi

    # Try standard XDG runtime directory socket (systemd user session)
    local xdg_bus="${XDG_RUNTIME_DIR:-/run/user/$UID}/bus"
    if [ -S "$xdg_bus" ]; then
        echo "unix:path=$xdg_bus"
        return
    fi

    # Try to find from running dbus-daemon process
    local dbus_pid
    dbus_pid=$(pgrep -u "$USER" -x dbus-daemon 2>/dev/null | head -1)
    if [ -n "$dbus_pid" ] && [ -r "/proc/$dbus_pid/environ" ]; then
        local dbus_addr
        dbus_addr=$(grep -z DBUS_SESSION_BUS_ADDRESS "/proc/$dbus_pid/environ" 2>/dev/null | tr -d '\0' | cut -d= -f2-)
        if [ -n "$dbus_addr" ]; then
            echo "$dbus_addr"
            return
        fi
    fi

    # No D-Bus address found
    echo ""
}

# Check if inotifywait is available
check_dependencies() {
    if ! command -v inotifywait >/dev/null 2>&1; then
        echo "Error: inotifywait not found. Please install inotify-tools:"
        echo "  Arch Linux: sudo pacman -S inotify-tools"
        echo "  Ubuntu/Debian: sudo apt install inotify-tools"
        echo "  Fedora: sudo dnf install inotify-tools"
        return 1
    fi
    return 0
}

# OSD notification helper
show_osd() {
    local osd_script="$HOME/.local/bin/kbd-backlight-osd.sh"
    if [ ! -x "$osd_script" ]; then
        return 1
    fi

    # Get D-Bus address (may need to re-discover if environment changed)
    local dbus_addr
    dbus_addr=$(get_dbus_address)

    if [ -z "$dbus_addr" ]; then
        echo "Warning: Cannot find D-Bus session bus address" >&2
        return 1
    fi

    # Set environment and call OSD script
    DBUS_SESSION_BUS_ADDRESS="$dbus_addr" \
    DISPLAY="${DISPLAY:-:0}" \
    "$osd_script"
}

# Run watcher loop (foreground, for systemd or direct use)
run_watcher() {
    # Check for keyboard backlight device
    if [ -z "$KBD_BACKLIGHT" ]; then
        echo "No keyboard backlight device found, nothing to watch"
        exit 0
    fi

    # Check dependencies
    if ! check_dependencies; then
        exit 1
    fi

    local brightness_file="$KBD_BACKLIGHT/brightness"

    echo "Keyboard backlight watcher starting..."
    echo "  Device: $(basename "$KBD_BACKLIGHT")"
    echo "  Watching: $brightness_file"
    echo "  D-Bus: $(get_dbus_address || echo 'not found')"
    echo "  Display: ${DISPLAY:-:0}"

    # Debounce: ignore rapid successive changes (kernel may write multiple times)
    local last_notify=0
    local debounce_ms=100  # Minimum 100ms between notifications

    while true; do
        # Wait for modify event on brightness file
        # If inotifywait fails (e.g., file removed), retry after delay
        if ! inotifywait -q -e modify "$brightness_file" >/dev/null 2>&1; then
            echo "Warning: inotifywait failed, retrying in 5s..." >&2
            sleep 5
            continue
        fi

        # Debounce check using milliseconds
        local now_ms
        now_ms=$(($(date +%s%N 2>/dev/null || echo "0") / 1000000))
        local diff=$((now_ms - last_notify))

        if [ "$diff" -ge "$debounce_ms" ] || [ "$now_ms" -eq 0 ]; then
            # Small delay to let kernel finish writing the value
            sleep 0.02
            show_osd
            last_notify=$now_ms
        fi
    done
}

# Start the watcher daemon (background)
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
    if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null; then
        echo "Watcher already running (PID: $(cat "$PIDFILE"))"
        exit 0
    fi

    echo "Starting keyboard backlight watcher..."
    echo "  Device: $(basename "$KBD_BACKLIGHT")"
    echo "  Watching: $KBD_BACKLIGHT/brightness"
    echo "  D-Bus: $(get_dbus_address || echo 'not found')"
    echo "  Display: ${DISPLAY:-:0}"

    # Start watcher in background using nohup for persistence
    nohup "$0" run >/dev/null 2>&1 &
    local pid=$!

    # Give it a moment to start
    sleep 0.2

    # Check if it's still running
    if kill -0 "$pid" 2>/dev/null; then
        echo "$pid" > "$PIDFILE"
        echo "Watcher started (PID: $pid)"
    else
        echo "Error: Watcher failed to start"
        exit 1
    fi
}

# Stop the watcher daemon
stop_watcher() {
    # Kill any running instance by name (more reliable than PID file)
    if pkill -f "kbd-backlight-watcher.sh run" 2>/dev/null; then
        echo "Watcher stopped"
    fi

    if [ -f "$PIDFILE" ]; then
        local pid
        pid=$(cat "$PIDFILE" 2>/dev/null)
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
            # Also kill child processes (inotifywait)
            pkill -P "$pid" 2>/dev/null || true
        fi
        rm -f "$PIDFILE"
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

    # Check if running (by process name, more reliable)
    local running_pid
    running_pid=$(pgrep -f "kbd-backlight-watcher.sh run" 2>/dev/null | head -1)

    if [ -n "$running_pid" ]; then
        echo "Status: Running (PID: $running_pid)"
    elif [ -f "$PIDFILE" ]; then
        local pid
        pid=$(cat "$PIDFILE" 2>/dev/null)
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            echo "Status: Running (PID: $pid)"
        else
            echo "Status: Not running (stale pidfile)"
        fi
    else
        echo "Status: Not running"
    fi

    # Check systemd service status
    if systemctl --user is-active kbd-backlight-watcher.service >/dev/null 2>&1; then
        echo "Systemd service: active"
    elif systemctl --user list-unit-files kbd-backlight-watcher.service >/dev/null 2>&1; then
        echo "Systemd service: installed but not active"
    fi

    if ! command -v inotifywait >/dev/null 2>&1; then
        echo ""
        echo "Warning: inotify-tools not installed"
    fi

    # Show D-Bus environment info for debugging
    echo ""
    echo "D-Bus environment:"
    echo "  DISPLAY: ${DISPLAY:-:0}"
    local dbus_addr
    dbus_addr=$(get_dbus_address)
    if [ -n "$dbus_addr" ]; then
        echo "  DBUS_SESSION_BUS_ADDRESS: $dbus_addr"
    else
        echo "  DBUS_SESSION_BUS_ADDRESS: (not found - OSD notifications may not work)"
    fi
}

case "$1" in
    run)
        run_watcher
        ;;
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
        echo "Usage: $0 {run|start|stop|restart|status}"
        echo ""
        echo "Monitor keyboard backlight changes and show dunst OSD notification."
        echo "This works even when Fn+Space is handled directly by firmware/kernel"
        echo "and X11 never receives the keypress."
        echo ""
        echo "Commands:"
        echo "  run     - Run watcher in foreground (for systemd service)"
        echo "  start   - Start the watcher as background daemon"
        echo "  stop    - Stop the watcher daemon"
        echo "  restart - Restart the watcher daemon"
        echo "  status  - Show watcher status and device info"
        echo ""
        echo "Recommended: Use systemd service for automatic startup:"
        echo "  systemctl --user enable --now kbd-backlight-watcher.service"
        exit 1
        ;;
esac
