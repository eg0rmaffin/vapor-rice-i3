#!/bin/bash
# scripts/hardware_config.sh
# Скрипт для автоматической конфигурации оборудования

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
RESET="\033[0m"

detect_hybrid_graphics() {
    # Определяем наличие гибридной графики
    local intel_gpu=$(lspci | grep -i 'vga\|3d\|display' | grep -i 'intel')
    local amd_gpu=$(lspci | grep -i 'vga\|3d\|display' | grep -i 'amd\|ati\|radeon')
    local nvidia_gpu=$(lspci | grep -i 'vga\|3d\|display' | grep -i 'nvidia')
    
    if [[ -n "$intel_gpu" && (-n "$amd_gpu" || -n "$nvidia_gpu") ]]; then
        return 0  # Гибридная графика обнаружена
    else
        return 1  # Нет гибридной графики
    fi
}

create_xorg_config() {
    echo -e "${CYAN}🔧 Создаем конфигурацию Xorg для определенного оборудования...${RESET}"

    XORG_CONF_DIR="/etc/X11/xorg.conf.d"
    if [ ! -d "$XORG_CONF_DIR" ]; then
        sudo mkdir -p "$XORG_CONF_DIR"
    fi

    # Проверяем, есть ли гибридная графика
    if detect_hybrid_graphics; then
        echo -e "${YELLOW}⚠️ Обнаружена гибридная графика. Автоматическая конфигурация отключена.${RESET}"
        echo -e "${YELLOW}⚠️ Рекомендуется ручная настройка Xorg для избежания конфликтов.${RESET}"
        return
    fi

    # Intel GPU (только если нет гибридной графики)
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

    # NVIDIA GPU: создание конфигурации Xorg
    if lspci | grep -i 'vga\|3d\|display' | grep -i 'nvidia' &>/dev/null; then
        NVIDIA_CONF="$XORG_CONF_DIR/20-nvidia.conf"
        if [ ! -f "$NVIDIA_CONF" ]; then
            echo -e "${CYAN}🔧 Создаем конфигурацию для NVIDIA GPU...${RESET}"
            sudo tee "$NVIDIA_CONF" > /dev/null <<EOF
Section "Device"
    Identifier     "NVIDIA Graphics"
    Driver         "nvidia"
    VendorName     "NVIDIA Corporation"
    # Параметры для улучшения производительности
    Option         "NoLogo" "true"
    Option         "TripleBuffer" "true"
    # Включаем аппаратное ускорение
    Option         "AccelMethod" "glamor"
    Option         "DRI" "3"
EndSection

Section "Screen"
    Identifier     "NVIDIA Screen"
    Device         "NVIDIA Graphics"
    # Оптимизация для устранения разрывов изображения
    Option         "metamodes" "nvidia-auto-select +0+0 {ForceFullCompositionPipeline=On}"
EndSection
EOF
            echo -e "${GREEN}✅ Конфигурация NVIDIA GPU создана в $NVIDIA_CONF${RESET}"
        else
            echo -e "${GREEN}✅ Конфигурация NVIDIA GPU уже существует${RESET}"
        fi
    fi

    # AMD GPU (только если нет гибридной графики)
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

# Функция для настройки гибридной графики
setup_hybrid_graphics() {
    if detect_hybrid_graphics; then
        echo -e "${YELLOW}⚠️ Обнаружена гибридная графика. Автоматическая настройка гибридной графики отключена.${RESET}"
        echo -e "${YELLOW}Для гибридной графики рекомендуется использовать одно из решений:${RESET}"
        echo -e "${YELLOW}1. Использовать конфигурацию с драйвером modesetting${RESET}"
        echo -e "${YELLOW}2. Использовать инструменты типа optimus-manager, prime или amd-switcheroo${RESET}"
        
        # Проверяем существование конфигураций и предлагаем их удалить
        XORG_CONF_DIR="/etc/X11/xorg.conf.d"
        if [ -f "$XORG_CONF_DIR/20-intel.conf" ] || [ -f "$XORG_CONF_DIR/20-amdgpu.conf" ]; then
            echo -e "${YELLOW}⚠️ Обнаружены конфликтующие файлы конфигурации:${RESET}"
            
            if [ -f "$XORG_CONF_DIR/20-intel.conf" ]; then
                echo -e "${YELLOW}   - $XORG_CONF_DIR/20-intel.conf${RESET}"
            fi
            
            if [ -f "$XORG_CONF_DIR/20-amdgpu.conf" ]; then
                echo -e "${YELLOW}   - $XORG_CONF_DIR/20-amdgpu.conf${RESET}"
            fi
            
            read -p "Удалить конфликтующие конфигурации? (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                if [ -f "$XORG_CONF_DIR/20-intel.conf" ]; then
                    sudo rm "$XORG_CONF_DIR/20-intel.conf"
                    echo -e "${GREEN}✅ Удален файл $XORG_CONF_DIR/20-intel.conf${RESET}"
                fi
                
                if [ -f "$XORG_CONF_DIR/20-amdgpu.conf" ]; then
                    sudo rm "$XORG_CONF_DIR/20-amdgpu.conf"
                    echo -e "${GREEN}✅ Удален файл $XORG_CONF_DIR/20-amdgpu.conf${RESET}"
                fi
            fi
        fi
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
