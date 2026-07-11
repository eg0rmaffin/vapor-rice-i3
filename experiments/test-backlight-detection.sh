#!/bin/bash
# experiments/test-backlight-detection.sh
# Diagnostic script for backlight detection on Lenovo Legion and similar laptops
# Usage: bash ~/dotfiles/experiments/test-backlight-detection.sh

set -e

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
CYAN="\033[0;36m"
RESET="\033[0m"

echo -e "${CYAN}┌────────────────────────────────────────────┐${RESET}"
echo -e "${CYAN}│     💡 Backlight Detection Diagnostic      │${RESET}"
echo -e "${CYAN}└────────────────────────────────────────────┘${RESET}"

# ─── 1. Hardware identification ───
echo ""
echo -e "${CYAN}=== Hardware ===${RESET}"
PRODUCT=$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo "unknown")
PRODUCT_FAMILY=$(cat /sys/class/dmi/id/product_family 2>/dev/null || echo "unknown")
BIOS_VERSION=$(cat /sys/class/dmi/id/bios_version 2>/dev/null || echo "unknown")
echo "Product name:   $PRODUCT"
echo "Product family: $PRODUCT_FAMILY"
echo "BIOS version:   $BIOS_VERSION"

# GPU detection
echo ""
echo -e "${CYAN}=== GPUs ===${RESET}"
if command -v lspci &>/dev/null; then
    lspci | grep -iE 'vga|3d|display' || echo "(none found)"
else
    echo "(lspci not available)"
fi

# ─── 2. Kernel command line ───
echo ""
echo -e "${CYAN}=== Kernel Command Line ===${RESET}"
cat /proc/cmdline 2>/dev/null || echo "(unavailable)"
echo ""
# Extract acpi_backlight param
ACPI_BL=$(grep -oP 'acpi_backlight=\S+' /proc/cmdline 2>/dev/null || echo "(not set)")
echo "acpi_backlight: $ACPI_BL"

# ─── 3. Available backlight interfaces ───
echo ""
echo -e "${CYAN}=== Backlight Interfaces ===${RESET}"
BACKLIGHT_DIR="/sys/class/backlight"
if [ -d "$BACKLIGHT_DIR" ]; then
    for device in "$BACKLIGHT_DIR"/*; do
        [ -d "$device" ] || continue
        name=$(basename "$device")
        max=$(cat "$device/max_brightness" 2>/dev/null || echo "?")
        cur=$(cat "$device/brightness" 2>/dev/null || echo "?")
        actual=$(cat "$device/actual_brightness" 2>/dev/null || echo "?")
        type=$(cat "$device/type" 2>/dev/null || echo "?")

        # Check if device is linked to a display connector
        bl_connector="?"
        if [ -L "$device/device" ]; then
            dev_path=$(readlink -f "$device/device")
            # Look for card*/card*-eDP-* symlink
            for conn in "$dev_path"/drm/card*/card*-*; do
                [ -d "$conn" ] && bl_connector=$(basename "$conn")
            done
        fi

        echo -e "  ${GREEN}$name${RESET}"
        echo "    type=$type  brightness=$cur/$max  actual=$actual  connector=$bl_connector"
    done
    [ "$(ls -A "$BACKLIGHT_DIR" 2>/dev/null)" ] || echo "  (none)"
else
    echo "  /sys/class/backlight does not exist"
fi

# ─── 4. nvidia_wmi_ec module status ───
echo ""
echo -e "${CYAN}=== NVIDIA WMI EC Backlight Module ===${RESET}"
if lsmod 2>/dev/null | grep -q nvidia_wmi_ec; then
    echo -e "  ${GREEN}nvidia_wmi_ec_backlight module is LOADED${RESET}"
elif modinfo nvidia_wmi_ec_backlight &>/dev/null 2>&1; then
    echo -e "  ${YELLOW}nvidia_wmi_ec_backlight module AVAILABLE but not loaded${RESET}"
    echo "  (need kernel param acpi_backlight=nvidia_wmi_ec to activate)"
else
    echo -e "  ${RED}nvidia_wmi_ec_backlight module NOT FOUND in kernel${RESET}"
    echo "  (kernel may be too old — requires 5.16+)"
fi

# ─── 5. Diagnosis ───
echo ""
echo -e "${CYAN}=== Diagnosis ===${RESET}"

if [ "$PRODUCT" = "83DH" ]; then
    echo "Hardware: Lenovo Legion Slim 5 16AHP9 (83DH)"

    if [ -d "$BACKLIGHT_DIR/nvidia_wmi_ec_backlight" ]; then
        echo -e "${GREEN}✅ nvidia_wmi_ec_backlight is present — backlight should work correctly${RESET}"
    elif [ -d "$BACKLIGHT_DIR/amdgpu_bl1" ] || [ -d "$BACKLIGHT_DIR/amdgpu_bl0" ]; then
        echo -e "${RED}⚠️  amdgpu_bl* is present but nvidia_wmi_ec_backlight is NOT${RESET}"
        echo -e "${RED}   Physical brightness will NOT change even though sysfs values update${RESET}"
        echo ""
        echo -e "${YELLOW}FIX: Change kernel parameter from acpi_backlight=native to acpi_backlight=nvidia_wmi_ec${RESET}"
        echo ""
        echo "For systemd-boot: edit /boot/loader/entries/*.conf"
        echo "For GRUB: edit /etc/default/grub or create /etc/default/grub.d/backlight.cfg"
        echo "Then reboot."
    else
        echo -e "${YELLOW}No known backlight interface found — check kernel parameters${RESET}"
    fi
else
    echo "Hardware: $PRODUCT (not a known problematic model)"

    # Check which interface brightness.sh would select
    SELECTED=""
    for pattern in "nvidia_wmi_ec_backlight" "intel_backlight" "amdgpu_bl" "acpi_video"; do
        for device in "$BACKLIGHT_DIR"/$pattern*; do
            if [ -d "$device" ]; then
                SELECTED="$(basename "$device")"
                break 2
            fi
        done
    done

    if [ -n "$SELECTED" ]; then
        echo -e "${GREEN}brightness.sh would use: $SELECTED${RESET}"
    else
        echo -e "${YELLOW}No standard backlight interface found${RESET}"
    fi
fi

echo ""
echo -e "${CYAN}Done.${RESET}"
