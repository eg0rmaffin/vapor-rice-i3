#!/bin/bash
# Test script to verify the graphical-session.target fix
# Run this on the actual machine to verify the watcher starts properly

echo "=== Graphical Session Target Diagnostic ==="
echo ""

# Check if graphical-session.target is active
echo "1. Checking graphical-session.target status:"
systemctl --user is-active graphical-session.target 2>/dev/null
echo "   Full status:"
systemctl --user status graphical-session.target 2>/dev/null | head -5
echo ""

# Check if kbd-backlight-watcher.service is enabled
echo "2. Checking kbd-backlight-watcher.service enabled state:"
systemctl --user is-enabled kbd-backlight-watcher.service 2>/dev/null || echo "   not found"
echo ""

# Check if kbd-backlight-watcher.service is active
echo "3. Checking kbd-backlight-watcher.service status:"
systemctl --user is-active kbd-backlight-watcher.service 2>/dev/null || echo "   not found"
echo "   Full status:"
systemctl --user status kbd-backlight-watcher.service 2>/dev/null | head -10
echo ""

# Check the WantedBy symlink
echo "4. Checking WantedBy symlink exists:"
ls -la ~/.config/systemd/user/graphical-session.target.wants/kbd-backlight-watcher.service 2>/dev/null || echo "   Symlink NOT found"
echo ""

# Check D-Bus environment
echo "5. Checking D-Bus environment in systemd user session:"
systemctl --user show-environment 2>/dev/null | grep -E "DISPLAY|DBUS_SESSION_BUS_ADDRESS" || echo "   D-Bus env NOT imported"
echo ""

# Check if keyboard backlight device exists
echo "6. Checking keyboard backlight device:"
ls -la /sys/class/leds/*kbd* 2>/dev/null || echo "   No keyboard backlight device found"
echo ""

echo "=== Diagnosis ==="
echo ""

TARGET_ACTIVE=$(systemctl --user is-active graphical-session.target 2>/dev/null)
SERVICE_ENABLED=$(systemctl --user is-enabled kbd-backlight-watcher.service 2>/dev/null)
SERVICE_ACTIVE=$(systemctl --user is-active kbd-backlight-watcher.service 2>/dev/null)
DBUS_IMPORTED=$(systemctl --user show-environment 2>/dev/null | grep -c DBUS_SESSION_BUS_ADDRESS)

if [ "$TARGET_ACTIVE" != "active" ]; then
    echo "PROBLEM: graphical-session.target is NOT active!"
    echo "  This means startx/.xinitrc is not starting it."
    echo "  Fix: Add 'systemctl --user start graphical-session.target' to .xinitrc"
    echo "  (after importing D-Bus environment)"
fi

if [ "$SERVICE_ENABLED" != "enabled" ]; then
    echo "PROBLEM: kbd-backlight-watcher.service is NOT enabled!"
    echo "  Fix: Run 'systemctl --user enable kbd-backlight-watcher.service'"
fi

if [ "$SERVICE_ACTIVE" != "active" ]; then
    echo "PROBLEM: kbd-backlight-watcher.service is NOT running!"
    echo "  If target is active and service is enabled, check service logs:"
    echo "  journalctl --user -u kbd-backlight-watcher.service"
fi

if [ "$DBUS_IMPORTED" -eq 0 ]; then
    echo "PROBLEM: DBUS_SESSION_BUS_ADDRESS not in systemd user environment!"
    echo "  Fix: Ensure .xinitrc imports it with:"
    echo "  systemctl --user import-environment DISPLAY DBUS_SESSION_BUS_ADDRESS"
fi

if [ "$TARGET_ACTIVE" = "active" ] && [ "$SERVICE_ENABLED" = "enabled" ] && [ "$SERVICE_ACTIVE" = "active" ] && [ "$DBUS_IMPORTED" -gt 0 ]; then
    echo "All checks passed! The keyboard backlight OSD should work."
    echo "Test by pressing Fn+Space on your keyboard."
fi
