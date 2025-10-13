#!/bin/bash
# bin/brightness.sh - универсальное управление яркостью

set -e

# Автоопределение backlight устройства с приоритетом
BACKLIGHT_DIR="/sys/class/backlight"

# Проверка на проблемный Lenovo IdeaPad
PRODUCT=$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo "unknown")
if [ "$PRODUCT" = "83DH" ] && [ -d "$BACKLIGHT_DIR/ideapad" ] && ! ls "$BACKLIGHT_DIR"/amdgpu_bl* "$BACKLIGHT_DIR"/intel_backlight 2>/dev/null | grep -q .; then
    echo "⚠️  Lenovo IdeaPad $PRODUCT detected with fake backlight"
    echo "📝 Add kernel parameter: acpi_backlight=native"
    echo "💡 After reboot, brightness will work automatically!"
    exit 1
fi

BACKLIGHT_DEVICE=""


# Приоритет: intel_backlight > amdgpu_bl* > acpi_video* > всё остальное (кроме ideapad)
for pattern in "intel_backlight" "amdgpu_bl" "acpi_video"; do
    for device in "$BACKLIGHT_DIR"/$pattern*; do
        if [ -d "$device" ]; then
            BACKLIGHT_DEVICE="$(basename "$device")"
            break 2
        fi
    done
done

# Если не нашли — берём любой, НО НЕ ideapad
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

if [ -z "$BACKLIGHT_DEVICE" ]; then
    echo "❌ Backlight device not found"
    exit 1
fi

BRIGHTNESS_FILE="$BACKLIGHT_DIR/$BACKLIGHT_DEVICE/brightness"
MAX_BRIGHTNESS=$(cat "$BACKLIGHT_DIR/$BACKLIGHT_DEVICE/max_brightness")

# Текущая яркость
CURRENT=$(cat "$BRIGHTNESS_FILE")

# Шаг изменения (5% от максимума)
STEP=$((MAX_BRIGHTNESS / 20))
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
