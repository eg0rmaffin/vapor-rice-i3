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

# ──── Определение поколения NVIDIA GPU ────
detect_nvidia_generation() {
    local gpu_info="$1"

    # RTX 50 series (Blackwell) - 2025+
    if echo "$gpu_info" | grep -iE 'RTX 50[0-9]{2}|RTX 5[0-9]{3}' &>/dev/null; then
        echo "blackwell"
        return
    fi

    # RTX 40 series (Ada Lovelace) - 2022+
    if echo "$gpu_info" | grep -iE 'RTX 40[0-9]{2}|RTX 4[0-9]{3}' &>/dev/null; then
        echo "ada"
        return
    fi

    # RTX 30 series (Ampere) - 2020+
    if echo "$gpu_info" | grep -iE 'RTX 30[0-9]{2}|RTX 3[0-9]{3}|A[0-9]{2,4}|A100|A40' &>/dev/null; then
        echo "ampere"
        return
    fi

    # RTX 20/GTX 16 series (Turing) - 2018+
    if echo "$gpu_info" | grep -iE 'RTX 20[0-9]{2}|GTX 16[0-9]{2}' &>/dev/null; then
        echo "turing"
        return
    fi

    # GTX 10 series (Pascal) - 2016-2017
    if echo "$gpu_info" | grep -iE 'GTX 10[0-9]{2}|GT 10[0-9]{2}' &>/dev/null; then
        echo "pascal"
        return
    fi

    # GTX 900 series (Maxwell) - 2014-2016
    if echo "$gpu_info" | grep -iE 'GTX 9[0-9]{2}|GTX TITAN X' &>/dev/null; then
        echo "maxwell"
        return
    fi

    # GTX 700/600 series (Kepler) - 2012-2014
    if echo "$gpu_info" | grep -iE 'GTX [67][0-9]{2}|GT [67][0-9]{2}|TITAN' &>/dev/null; then
        echo "kepler"
        return
    fi

    echo "unknown"
}

# ──── Установка драйверов NVIDIA ────
install_nvidia_drivers() {
    local nvidia_info=$(lspci | grep -i 'vga\|3d\|display' | grep -i 'nvidia')
    local generation=$(detect_nvidia_generation "$nvidia_info")

    echo -e "${CYAN}Обнаружена видеокарта: ${nvidia_info}${RESET}"
    echo -e "${CYAN}Определено поколение GPU: ${generation}${RESET}"

    # Проверяем, установлены ли уже драйверы
    if check_package "nvidia-utils" || check_package "nvidia-580xx-utils"; then
        echo -e "${GREEN}✅ Драйверы NVIDIA уже установлены${RESET}"
        return
    fi

    case "$generation" in
        blackwell|ada|ampere|turing)
            echo -e "${CYAN}📦 Устанавливаем современные драйверы NVIDIA (открытые модули ядра)...${RESET}"

            # Устанавливаем необходимые пакеты для DKMS
            for pkg in linux-headers dkms; do
                if ! check_package "$pkg"; then
                    install_package "$pkg"
                else
                    echo -e "${GREEN}✅ $pkg уже установлен${RESET}"
                fi
            done

            # Устанавливаем основные драйверы NVIDIA (открытые модули ядра)
            for pkg in nvidia-open-dkms nvidia-utils nvidia-settings; do
                if ! check_package "$pkg"; then
                    install_package "$pkg"
                else
                    echo -e "${GREEN}✅ $pkg уже установлен${RESET}"
                fi
            done

            # 32-битная поддержка для игр и Wine
            if ! check_package "lib32-nvidia-utils"; then
                echo -e "${CYAN}📦 Устанавливаем 32-битную поддержку для игр...${RESET}"
                install_package "lib32-nvidia-utils"
            else
                echo -e "${GREEN}✅ lib32-nvidia-utils уже установлен${RESET}"
            fi

            echo -e "${GREEN}✅ Установлены драйверы NVIDIA с открытыми модулями ядра${RESET}"
            ;;

        pascal|maxwell|kepler)
            echo -e "${CYAN}📦 Устанавливаем драйверы NVIDIA legacy (580xx) для старых GPU...${RESET}"
            echo -e "${YELLOW}⚠️ Поддержка Pascal и старше перенесена в AUR (NVIDIA 580xx)${RESET}"

            # Устанавливаем необходимые пакеты для DKMS
            for pkg in linux-headers dkms; do
                if ! check_package "$pkg"; then
                    install_package "$pkg"
                else
                    echo -e "${GREEN}✅ $pkg уже установлен${RESET}"
                fi
            done

            # Устанавливаем legacy драйверы из AUR
            for pkg in nvidia-580xx-dkms nvidia-580xx-utils nvidia-settings; do
                if ! check_package "$pkg"; then
                    install_aur_package "$pkg"
                else
                    echo -e "${GREEN}✅ $pkg уже установлен${RESET}"
                fi
            done

            # 32-битная поддержка для игр и Wine
            if ! check_package "lib32-nvidia-580xx-utils"; then
                echo -e "${CYAN}📦 Устанавливаем 32-битную поддержку для игр...${RESET}"
                install_aur_package "lib32-nvidia-580xx-utils"
            else
                echo -e "${GREEN}✅ lib32-nvidia-580xx-utils уже установлен${RESET}"
            fi

            echo -e "${GREEN}✅ Установлены legacy драйверы NVIDIA 580xx${RESET}"
            ;;

        *)
            echo -e "${YELLOW}⚠️ Не удалось определить поколение GPU: $nvidia_info${RESET}"
            echo -e "${YELLOW}⚠️ Пожалуйста, установите драйверы NVIDIA вручную${RESET}"
            echo -e "${YELLOW}Посетите https://wiki.archlinux.org/title/NVIDIA для подробностей${RESET}"
            return 1
            ;;
    esac

    # Настройка модуля ядра для включения modesetting
    echo -e "${CYAN}🔧 Настраиваем параметры модуля ядра nvidia-drm...${RESET}"

    MODPROBE_CONF="/etc/modprobe.d/nvidia.conf"
    if [ ! -f "$MODPROBE_CONF" ]; then
        sudo tee "$MODPROBE_CONF" > /dev/null <<EOF
# Включаем kernel mode setting для NVIDIA
# Необходимо для Wayland и правильной работы PRIME
options nvidia-drm modeset=1

# Включаем fbdev для совместимости с новыми ядрами (6.11+)
options nvidia-drm fbdev=1
EOF
        echo -e "${GREEN}✅ Создан $MODPROBE_CONF${RESET}"
    else
        echo -e "${GREEN}✅ $MODPROBE_CONF уже существует${RESET}"
    fi

    # Добавляем NVIDIA модули в mkinitcpio для раннего запуска
    echo -e "${CYAN}🔧 Добавляем модули NVIDIA в mkinitcpio...${RESET}"

    MKINITCPIO_CONF="/etc/mkinitcpio.conf"
    if [ -f "$MKINITCPIO_CONF" ]; then
        # Проверяем, добавлены ли уже модули NVIDIA
        if ! grep -q 'nvidia nvidia_modeset nvidia_uvm nvidia_drm' "$MKINITCPIO_CONF"; then
            # Создаем резервную копию
            sudo cp "$MKINITCPIO_CONF" "${MKINITCPIO_CONF}.bak"

            # Добавляем модули NVIDIA в MODULES
            sudo sed -i 's/^MODULES=(\(.*\))/MODULES=(\1 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' "$MKINITCPIO_CONF"

            echo -e "${GREEN}✅ Модули NVIDIA добавлены в mkinitcpio${RESET}"
            echo -e "${CYAN}🔄 Пересобираем initramfs...${RESET}"

            # Пересобираем initramfs для всех установленных ядер
            sudo mkinitcpio -P

            echo -e "${GREEN}✅ initramfs пересобран${RESET}"
        else
            echo -e "${GREEN}✅ Модули NVIDIA уже добавлены в mkinitcpio${RESET}"
        fi
    else
        echo -e "${YELLOW}⚠️ $MKINITCPIO_CONF не найден, пропускаем настройку mkinitcpio${RESET}"
    fi

    echo -e "${GREEN}✅ Установка и настройка драйверов NVIDIA завершена${RESET}"
    echo -e "${YELLOW}⚠️ Требуется перезагрузка для применения изменений${RESET}"
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

    # NVIDIA GPU – декларативная установка драйверов
    if lspci | grep -i 'vga\|3d\|display' | grep -i 'nvidia' &>/dev/null; then
        echo -e "${CYAN}🔍 Найдена NVIDIA GPU${RESET}"
        install_nvidia_drivers
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
