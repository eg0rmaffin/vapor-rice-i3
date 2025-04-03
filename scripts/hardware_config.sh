#!/bin/bash
# scripts/hardware_config.sh
# Скрипт для автоматической конфигурации оборудования

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
RESET="\033[0m"

create_xorg_config() {
    echo -e "${CYAN}🔧 Создаем конфигурацию Xorg для определенного оборудования...${RESET}"

    XORG_CONF_DIR="/etc/X11/xorg.conf.d"
    if [ ! -d "$XORG_CONF_DIR" ]; then
        sudo mkdir -p "$XORG_CONF_DIR"
    fi

    # Intel GPU
    if lspci | grep -i 'vga\|3d\|display' | grep -i 'intel' &>/dev/null; then
        INTEL_CONF="$XORG_CONF_DIR/20-intel.conf"
        if [ ! -f "$INTEL_CONF" ]; then
            echo -e "${CYAN}🔧 Создаем конфигурацию для Intel GPU...${RESET}"
            sudo tee "$INTEL_CONF" > /dev/null <<EOF
Section "Device"
    Identifier  "Intel Graphics"
    Driver      "intel"
    Option      "TearFree" "true"
    Option      "AccelMethod" "sna"
    Option      "DRI" "3"
EndSection
EOF
            echo -e "${GREEN}✅ Конфигурация Intel GPU создана в $INTEL_CONF${RESET}"
        else
            echo -e "${GREEN}✅ Конфигурация Intel GPU уже существует${RESET}"
        fi
    fi

    # NVIDIA GPU: автоматическая конфигурация отключена
    if lspci | grep -i 'vga\|3d\|display' | grep -i 'nvidia' &>/dev/null; then
        echo -e "${YELLOW}⚠️ Обнаружена NVIDIA GPU. Автоматическая конфигурация NVIDIA отключена.${RESET}"
    fi

    # AMD GPU
    if lspci | grep -i 'vga\|3d\|display' | grep -i 'amd\|ati\|radeon' &>/dev/null; then
        AMD_CONF="$XORG_CONF_DIR/20-amdgpu.conf"
        if [ ! -f "$AMD_CONF" ]; then
            echo -e "${CYAN}🔧 Создаем конфигурацию для AMD GPU...${RESET}"
            sudo tee "$AMD_CONF" > /dev/null <<EOF
Section "Device"
    Identifier  "AMD Graphics"
    Driver      "amdgpu"
    Option      "TearFree" "true"
    Option      "DRI" "3"
    Option      "AccelMethod" "glamor"
EndSection
EOF
            echo -e "${GREEN}✅ Конфигурация AMD GPU создана в $AMD_CONF${RESET}"
        else
            echo -e "${GREEN}✅ Конфигурация AMD GPU уже существует${RESET}"
        fi
    fi
}

# Функция для настройки мультимедиа клавиш (без аудио громкости)
setup_multimedia_keys() {
    echo -e "${CYAN}🎹 Настраиваем мультимедиа клавиши (без аудио регулировки)...${RESET}"

    I3_MULTIMEDIA_CONFIG="$HOME/.config/i3/includes/multimedia.conf"
    mkdir -p "$HOME/.config/i3/includes"

    # Создаем конфигурацию, оставляя только управление воспроизведением
    if [ ! -f "$I3_MULTIMEDIA_CONFIG" ]; then
        cat > "$I3_MULTIMEDIA_CONFIG" <<EOF
# Клавиши управления медиа (без аудио регулировки)
bindsym XF86AudioPlay exec --no-startup-id playerctl play-pause
bindsym XF86AudioNext exec --no-startup-id playerctl next
bindsym XF86AudioPrev exec --no-startup-id playerctl previous
EOF
        echo -e "${GREEN}✅ Конфигурация мультимедиа клавиш для i3 создана в $I3_MULTIMEDIA_CONFIG${RESET}"

        I3_CONFIG="$HOME/.config/i3/config"
        if [ -f "$I3_CONFIG" ] && ! grep -q "includes/multimedia.conf" "$I3_CONFIG"; then
            echo "include \$HOME/.config/i3/includes/multimedia.conf" >> "$I3_CONFIG"
            echo -e "${GREEN}✅ Мультимедиа конфиг добавлен в основной конфиг i3${RESET}"
        fi
    else
        echo -e "${GREEN}✅ Конфигурация мультимедиа клавиш для i3 уже существует${RESET}"
    fi
}

# Функция для настройки гибридной графики – оставляем только предупреждение
setup_hybrid_graphics() {
    if lspci | grep -i 'vga\|3d\|display' | grep -i 'intel' &>/dev/null && \
       lspci | grep -i 'vga\|3d\|display' | grep -i 'nvidia' &>/dev/null; then
        echo -e "${YELLOW}⚠️ Обнаружена гибридная графика Intel + NVIDIA. Автоматическая настройка гибридной графики отключена.${RESET}"
        echo -e "${YELLOW}Используйте manual configuration для NVIDIA или отключите дискретную карту.${RESET}"
    fi
}

configure_hardware() {
    echo -e "${CYAN}"
    echo "┌────────────────────────────────────────────┐"
    echo "│    🔧 Настройка конкретного оборудования   │"
    echo "└────────────────────────────────────────────┘"
    echo -e "${RESET}"

    create_xorg_config
    setup_multimedia_keys
    setup_hybrid_graphics

    echo -e "${GREEN}✅ Настройка оборудования завершена!${RESET}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    configure_hardware
fi

export -f configure_hardware
