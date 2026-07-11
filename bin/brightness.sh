#!/bin/bash
# bin/brightness.sh - универсальное управление яркостью

set -e

# Автоопределение backlight устройства с приоритетом
BACKLIGHT_DIR="/sys/class/backlight"

# Проверка на Lenovo Legion Slim 5 16AHP9 (83DH) — AMD iGPU + NVIDIA dGPU
# На этом ноутбуке яркость управляется через NVIDIA EC (Embedded Controller).
# amdgpu_bl* принимает записи, но физическая яркость не меняется.
# Правильный интерфейс — nvidia_wmi_ec_backlight (нужен kernel param: acpi_backlight=nvidia_wmi_ec).
PRODUCT=$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo "unknown")
if [ "$PRODUCT" = "83DH" ]; then
    # Если nvidia_wmi_ec_backlight отсутствует — нужен kernel param
    if [ ! -d "$BACKLIGHT_DIR/nvidia_wmi_ec_backlight" ]; then
        echo "⚠️  Lenovo Legion Slim 5 ($PRODUCT) — backlight controlled by NVIDIA EC"
        echo "📝 Replace kernel parameter: acpi_backlight=nvidia_wmi_ec"
        echo "   (remove acpi_backlight=native if present)"
        echo "💡 After reboot, nvidia_wmi_ec_backlight will appear and brightness will work!"
        exit 1
    fi
fi

BACKLIGHT_DEVICE=""


# Приоритет: nvidia_wmi_ec_backlight > intel_backlight > amdgpu_bl* > acpi_video* > всё остальное (кроме ideapad и nvidia_0)
for pattern in "nvidia_wmi_ec_backlight" "intel_backlight" "amdgpu_bl" "acpi_video"; do
    for device in "$BACKLIGHT_DIR"/$pattern*; do
        if [ -d "$device" ]; then
            BACKLIGHT_DEVICE="$(basename "$device")"
            break 2
        fi
    done
done

# Если не нашли — берём любой, НО НЕ ideapad и nvidia_0
if [ -z "$BACKLIGHT_DEVICE" ]; then
    for device in "$BACKLIGHT_DIR"/*; do
        if [ -d "$device" ]; then
            name="$(basename "$device")"
            # Исключаем проблемные устройства: ideapad (фейковый) и nvidia_0 (не работает в гибридном режиме)
            if [ "$name" != "ideapad" ] && [ "$name" != "nvidia_0" ]; then
                BACKLIGHT_DEVICE="$name"
                break
            fi
        fi
    done
fi

if [ -z "$BACKLIGHT_DEVICE" ]; then
    echo "❌ Backlight device not found"
    exit 1
fi

BRIGHTNESS_FILE="$BACKLIGHT_DIR/$BACKLIGHT_DEVICE/brightness"
MAX_BRIGHTNESS=$(cat "$BACKLIGHT_DIR/$BACKLIGHT_DEVICE/max_brightness")

# Текущая яркость
CURRENT=$(cat "$BRIGHTNESS_FILE")

# Шаг изменения (10% от максимума)
STEP=$((MAX_BRIGHTNESS / 10))
[ $STEP -lt 1 ] && STEP=1

case "$1" in
    up)
        NEW=$((CURRENT + STEP))
        if [ $NEW -gt $MAX_BRIGHTNESS ]; then
            NEW=$MAX_BRIGHTNESS
        fi
        echo $NEW > "$BRIGHTNESS_FILE"
        ;;
    down)
        NEW=$((CURRENT - STEP))
        if [ $NEW -lt 1 ]; then
            NEW=1
        fi
        echo $NEW > "$BRIGHTNESS_FILE"
        ;;
    *)
        echo "Usage: $0 {up|down}"
        exit 1
        ;;
esac

# ─── OSD + instant i3blocks update ───
PERCENT=$((NEW * 100 / MAX_BRIGHTNESS))
OSD_LIB="$HOME/dotfiles/scripts/osd/osd-panel.sh"
if [ -f "$OSD_LIB" ] && command -v notify-send >/dev/null; then
    . "$OSD_LIB"
    osd_show_progress "brightness" "$OSD_ID_BRIGHTNESS" "🔆" "Brightness ${PERCENT}%" "$PERCENT"
fi
pkill -RTMIN+10 i3blocks 2>/dev/null || true
