#!/bin/bash
# experiments/detect-backlight.sh - Detect and test backlight devices

echo "=== Backlight Device Detection ==="
echo ""

BACKLIGHT_DIR="/sys/class/backlight"

echo "1. Checking DMI product information:"
PRODUCT=$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo "unknown")
VENDOR=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || echo "unknown")
echo "   Vendor: $VENDOR"
echo "   Product: $PRODUCT"
echo ""

echo "2. Listing all backlight devices:"
if [ -d "$BACKLIGHT_DIR" ]; then
    for device in "$BACKLIGHT_DIR"/*; do
        if [ -d "$device" ]; then
            name="$(basename "$device")"
            echo "   Found: $name"
            if [ -f "$device/max_brightness" ] && [ -f "$device/brightness" ]; then
                max=$(cat "$device/max_brightness")
                current=$(cat "$device/brightness")
                echo "      Max: $max, Current: $current"
            fi
        fi
    done
else
    echo "   No backlight devices found!"
fi
echo ""

echo "3. Checking for NVIDIA GPU:"
if lspci | grep -i 'vga\|3d\|display' | grep -i 'nvidia' &>/dev/null; then
    echo "   NVIDIA GPU detected:"
    lspci | grep -i 'vga\|3d\|display' | grep -i 'nvidia'
else
    echo "   No NVIDIA GPU detected"
fi
echo ""

echo "4. Checking for integrated GPU:"
if lspci | grep -i 'vga\|3d\|display' | grep -i 'intel' &>/dev/null; then
    echo "   Intel GPU detected:"
    lspci | grep -i 'vga\|3d\|display' | grep -i 'intel'
elif lspci | grep -i 'vga\|3d\|display' | grep -i 'amd\|ati\|radeon' &>/dev/null; then
    echo "   AMD GPU detected:"
    lspci | grep -i 'vga\|3d\|display' | grep -i 'amd\|ati\|radeon'
else
    echo "   No integrated GPU detected"
fi
echo ""

echo "5. Checking loaded kernel modules:"
echo "   nvidia_wmi_ec_backlight: $(lsmod | grep nvidia_wmi_ec_backlight || echo 'not loaded')"
echo "   nvidia: $(lsmod | grep '^nvidia ' || echo 'not loaded')"
echo ""

echo "6. Current kernel parameters (backlight-related):"
cat /proc/cmdline | grep -o 'acpi_backlight=[^ ]*' || echo "   No acpi_backlight parameter set"
echo ""

echo "=== Recommended Actions ==="
echo ""

# Check if we have nvidia_wmi_ec device
if [ -d "$BACKLIGHT_DIR/nvidia_wmi_ec_backlight" ]; then
    echo "✅ nvidia_wmi_ec_backlight device found!"
    echo "   This is the preferred device for NVIDIA hybrid laptops."
elif lspci | grep -i 'nvidia' &>/dev/null; then
    echo "⚠️  NVIDIA GPU detected but nvidia_wmi_ec_backlight not available."
    echo "   Try adding kernel parameter: acpi_backlight=nvidia_wmi_ec"
    echo "   If that doesn't work, try: acpi_backlight=native or acpi_backlight=video"
fi

# Check for intel_backlight
if [ -d "$BACKLIGHT_DIR/intel_backlight" ]; then
    echo "✅ intel_backlight device found!"
    echo "   This should work for Intel integrated graphics."
fi

# Check for AMD backlight
if [ -d "$BACKLIGHT_DIR/amdgpu_bl0" ] || [ -d "$BACKLIGHT_DIR/amdgpu_bl1" ]; then
    echo "✅ amdgpu backlight device found!"
    echo "   This should work for AMD integrated graphics."
fi

# Check for problematic ideapad
if [ -d "$BACKLIGHT_DIR/ideapad" ]; then
    if ! ls "$BACKLIGHT_DIR"/intel_backlight "$BACKLIGHT_DIR"/amdgpu_bl* "$BACKLIGHT_DIR"/nvidia_wmi_ec* 2>/dev/null | grep -q .; then
        echo "⚠️  Only ideapad backlight found - this is usually a fake device!"
        echo "   Try adding kernel parameter: acpi_backlight=native"
    fi
fi

echo ""
echo "=== End of Detection ==="
