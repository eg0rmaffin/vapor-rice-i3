#!/bin/bash
# scripts/detect_hardware.sh
# Скрипт для определения оборудования и установки соответствующих драйверов
# (Обратите внимание: для NVIDIA установка драйверов отключена – их необходимо настроить вручную)

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
RESET="\033[0m"

# Функция для определения наличия пакета
check_package() {
    pacman -Q "$1" &>/dev/null
}

# Функция для установки пакета
install_package() {
    echo -e "${YELLOW}📦 Устанавливаем $1...${RESET}"
    sudo pacman -S --noconfirm "$1"
}

# Функция для установки пакета из AUR
install_aur_package() {
    if ! check_package "yay"; then
        echo -e "${YELLOW}⚠️ yay не установлен, невозможно установить AUR пакет${RESET}"
        return 1
    fi
    echo -e "${YELLOW}📦 Устанавливаем $1 из AUR...${RESET}"
    if ! yay -S --noconfirm "$1"; then
        echo -e "${CYAN}⚠️ Standard install failed — trying cmake patch для $1...${RESET}"
        if [ -f ~/dotfiles/bin/cmake-patch.sh ]; then
            ~/dotfiles/bin/cmake-patch.sh "$1"
        else
            echo -e "${YELLOW}⚠️ cmake-patch.sh не найден, установка $1 не удалась${RESET}"
            return 1
        fi
    fi
}

# ──── Установка драйверов видеокарты ────
install_gpu_drivers() {
    echo -e "${CYAN}🖥️ Определяем видеокарту...${RESET}"
    
    # Intel GPU
    if lspci | grep -i 'vga\|3d\|display' | grep -i 'intel' &>/dev/null; then
        echo -e "${CYAN}🔍 Найдена Intel GPU${RESET}"
        for pkg in xf86-video-intel intel-media-driver libva-intel-driver mesa vulkan-intel; do
            if ! check_package "$pkg"; then
                install_package "$pkg"
            else
                echo -e "${GREEN}✅ $pkg уже установлен${RESET}"
            fi
        done
    fi

    # NVIDIA GPU – отключаем установку, выводим предупреждение
    if lspci | grep -i 'vga\|3d\|display' | grep -i 'nvidia' &>/dev/null; then
        echo -e "${YELLOW}⚠️ Обнаружена NVIDIA GPU. Драйверы для NVIDIA НЕ устанавливаются декларативно.${RESET}"
        echo -e "${YELLOW}Пожалуйста, настройте драйверы NVIDIA вручную или используйте официальный установщик.${RESET}"
    fi

    # AMD GPU
    if lspci | grep -i 'vga\|3d\|display' | grep -i 'amd\|ati\|radeon' &>/dev/null; then
        echo -e "${CYAN}🔍 Найдена AMD GPU${RESET}"
        for pkg in xf86-video-amdgpu mesa vulkan-radeon libva-mesa-driver mesa-vdpau; do
            if ! check_package "$pkg"; then
                install_package "$pkg"
            else
                echo -e "${GREEN}✅ $pkg уже установлен${RESET}"
            fi
        done
    fi

    # Если ничего не найдено – базовые драйверы
    if ! lspci | grep -i 'vga\|3d\|display' | grep -i 'intel\|nvidia\|amd\|ati\|radeon' &>/dev/null; then
        echo -e "${YELLOW}⚠️ Не удалось определить видеокарту, устанавливаем базовые драйверы${RESET}"
        for pkg in xf86-video-vesa xf86-video-fbdev mesa; do
            if ! check_package "$pkg"; then
                install_package "$pkg"
            else
                echo -e "${GREEN}✅ $pkg уже установлен${RESET}"
            fi
        done
    fi
}

# ──── Установка драйверов Wi-Fi ────
install_wifi_drivers() {
    echo -e "${CYAN}📡 Определяем Wi-Fi адаптер...${RESET}"
    
    if lspci | grep -i 'network\|wireless' | grep -i 'broadcom' &>/dev/null; then
        echo -e "${CYAN}🔍 Найден Broadcom Wi-Fi адаптер${RESET}"
        for pkg in broadcom-wl-dkms; do
            if ! check_package "$pkg"; then
                install_aur_package "$pkg"
            else
                echo -e "${GREEN}✅ $pkg уже установлен${RESET}"
            fi
        done
    fi
    
    if lspci | grep -i 'network\|wireless' | grep -i 'intel' &>/dev/null; then
        echo -e "${CYAN}🔍 Найден Intel Wi-Fi адаптер${RESET}"
        for pkg in linux-firmware intel-ucode; do
            if ! check_package "$pkg"; then
                install_package "$pkg"
            else
                echo -e "${GREEN}✅ $pkg уже установлен${RESET}"
            fi
        done
    fi
    
    if lspci | grep -i 'network\|wireless' | grep -i 'realtek' &>/dev/null || lsusb | grep -i 'realtek' &>/dev/null; then
        echo -e "${CYAN}🔍 Найден Realtek Wi-Fi адаптер${RESET}"
        for pkg in linux-firmware; do
            if ! check_package "$pkg"; then
                install_package "$pkg"
            else
                echo -e "${GREEN}✅ $pkg уже установлен${RESET}"
            fi
        done
        
        if lsusb | grep -i 'realtek.*8812\|8821\|8822\|8723' &>/dev/null; then
            for pkg in rtl8812au-dkms-git rtw88-dkms-git; do
                if ! check_package "$pkg"; then
                    install_aur_package "$pkg"
                else
                    echo -e "${GREEN}✅ $pkg уже установлен${RESET}"
                fi
            done
        fi
    fi
    
    for pkg in wpa_supplicant wireless_tools iw; do
        if ! check_package "$pkg"; then
            install_package "$pkg"
        else
            echo -e "${GREEN}✅ $pkg уже установлен${RESET}"
        fi
    done
}

# ──── Установка драйверов для тачпада ────
install_touchpad_drivers() {
    echo -e "${CYAN}🖱️ Определяем тачпад...${RESET}"
    
    if xinput list | grep -i 'touchpad\|trackpad' &>/dev/null; then
        echo -e "${CYAN}🔍 Найден тачпад${RESET}"
        for pkg in xf86-input-libinput xorg-xinput; do
            if ! check_package "$pkg"; then
                install_package "$pkg"
            else
                echo -e "${GREEN}✅ $pkg уже установлен${RESET}"
            fi
        done
        
        echo -e "${CYAN}🔧 Создаем конфигурацию тачпада...${RESET}"
        TOUCHPAD_CONF_DIR="/etc/X11/xorg.conf.d"
        TOUCHPAD_CONF="$TOUCHPAD_CONF_DIR/30-touchpad.conf"
        
        if [ ! -d "$TOUCHPAD_CONF_DIR" ]; then
            sudo mkdir -p "$TOUCHPAD_CONF_DIR"
        fi
        
        if [ ! -f "$TOUCHPAD_CONF" ]; then
            sudo tee "$TOUCHPAD_CONF" > /dev/null <<EOF
Section "InputClass"
    Identifier "touchpad"
    Driver "libinput"
    MatchIsTouchpad "on"
    Option "Tapping" "on"
    Option "NaturalScrolling" "true"
    Option "ClickMethod" "clickfinger"
    Option "AccelProfile" "adaptive"
    Option "AccelSpeed" "0.3"
    Option "DisableWhileTyping" "true"
EndSection
EOF
            echo -e "${GREEN}✅ Конфигурация тачпада создана в $TOUCHPAD_CONF${RESET}"
        else
            echo -e "${GREEN}✅ Конфигурация тачпада уже существует${RESET}"
        fi
    else
        echo -e "${YELLOW}ℹ️ Тачпад не обнаружен, пропускаем настройку${RESET}"
    fi
}

# ──── Установка драйверов для принтеров ────
install_printer_drivers() {
    echo -e "${CYAN}🖨️ Настраиваем поддержку принтеров...${RESET}"
    
    for pkg in cups cups-pdf ghostscript gsfonts foomatic-db foomatic-db-engine gutenprint; do
        if ! check_package "$pkg"; then
            install_package "$pkg"
        else
            echo -e "${GREEN}✅ $pkg уже установлен${RESET}"
        fi
    done
    
    if ! systemctl is-enabled cups.service &>/dev/null; then
        echo -e "${CYAN}🔄 Включаем службу CUPS...${RESET}"
        sudo systemctl enable cups.service
    else
        echo -e "${GREEN}✅ Служба CUPS уже включена${RESET}"
    fi
    
    if lpinfo -v 2>/dev/null | grep -i 'hp' &>/dev/null || lsusb | grep -i 'hp' &>/dev/null; then
        echo -e "${CYAN}🔍 Обнаружено устройство HP${RESET}"
        for pkg in hplip; do
            if ! check_package "$pkg"; then
                install_package "$pkg"
            else
                echo -e "${GREEN}✅ $pkg уже установлен${RESET}"
            fi
        done
    fi
    
    if lpinfo -v 2>/dev/null | grep -i 'brother' &>/dev/null || lsusb | grep -i 'brother' &>/dev/null; then
        echo -e "${CYAN}🔍 Обнаружено устройство Brother${RESET}"
        for pkg in brother-cups-wrapper; do
            if ! check_package "$pkg"; then
                install_aur_package "$pkg"
            else
                echo -e "${GREEN}✅ $pkg уже установлен${RESET}"
            fi
        done
    fi
}

# ──── Главная функция ────
install_drivers() {
    echo -e "${CYAN}"
    echo "┌────────────────────────────────────────────┐"
    echo "│     🚀 Декларативная установка драйверов   │"
    echo "└────────────────────────────────────────────┘"
    echo -e "${RESET}"
    
    for util in lspci lsusb; do
        if ! command -v "$util" &>/dev/null; then
            echo -e "${YELLOW}📦 Устанавливаем $util...${RESET}"
            install_package "pciutils"
            install_package "usbutils"
            break
        fi
    done
    
    install_gpu_drivers
    install_wifi_drivers
    install_touchpad_drivers
    install_printer_drivers
    
    echo -e "${GREEN}✅ Установка драйверов завершена!${RESET}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_drivers
fi

export -f install_drivers
