#!/bin/bash
# scripts/laptop_power.sh
# Скрипт для установки и настройки энергосбережения на ноутбуках

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
RESET="\033[0m"

check_package() {
    pacman -Q "$1" &>/dev/null
}

install_package() {
    echo -e "${YELLOW}📦 Устанавливаем $1...${RESET}"
    sudo pacman -S --noconfirm "$1"
}

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

is_laptop() {
    if [ -d "/sys/class/power_supply" ]; then
        for supply in /sys/class/power_supply/*; do
            if [ -f "$supply/type" ] && grep -q "Battery" "$supply/type"; then
                return 0
            fi
        done
    fi
    if [ -f "/sys/class/dmi/id/chassis_type" ]; then
        CHASSIS_TYPE=$(cat /sys/class/dmi/id/chassis_type)
        if [[ "$CHASSIS_TYPE" == "8" || "$CHASSIS_TYPE" == "9" || "$CHASSIS_TYPE" == "10" || "$CHASSIS_TYPE" == "11" || "$CHASSIS_TYPE" == "14" ]]; then
            return 0
        fi
    fi
    return 1
}

setup_laptop_power() {
    echo -e "${CYAN}🔋 Настраиваем энергосбережение для ноутбука...${RESET}"
    
    for pkg in tlp tlp-rdw; do
        if ! check_package "$pkg"; then
            install_package "$pkg"
        else
            echo -e "${GREEN}✅ $pkg уже установлен${RESET}"
        fi
    done
    
    if lscpu | grep -i 'intel' &>/dev/null; then
        echo -e "${CYAN}🔍 Обнаружен процессор Intel${RESET}"
        for pkg in thermald intel-undervolt; do
            if ! check_package "$pkg"; then
                if [ "$pkg" == "intel-undervolt" ]; then
                    install_aur_package "$pkg"
                else
                    install_package "$pkg"
                fi
            else
                echo -e "${GREEN}✅ $pkg уже установлен${RESET}"
            fi
        done
        
        echo -e "${CYAN}🔄 Включаем службы для Intel...${RESET}"
        for service in thermald.service; do
            if systemctl list-unit-files | grep -q "$service"; then
                sudo systemctl enable "$service"
                sudo systemctl start "$service"
                echo -e "${GREEN}✅ Служба $service включена${RESET}"
            fi
        done
        
        if check_package "intel-undervolt"; then
            echo -e "${YELLOW}ℹ️ intel-undervolt установлен. Для настройки undervolting отредактируйте /etc/intel-undervolt.conf вручную и запустите intel-undervolt apply${RESET}"
        fi
    fi
    
    if lscpu | grep -i 'amd' &>/dev/null; then
        echo -e "${CYAN}🔍 Обнаружен процессор AMD${RESET}"
        for pkg in amd-ucode; do
            if ! check_package "$pkg"; then
                install_package "$pkg"
            else
                echo -e "${GREEN}✅ $pkg уже установлен${RESET}"
            fi
        done
    fi
    
    if ! check_package "powertop"; then
        install_package "powertop"
    else
        echo -e "${GREEN}✅ powertop уже установлен${RESET}"
    fi
    
    if ! check_package "auto-cpufreq"; then
        install_aur_package "auto-cpufreq"
        sudo systemctl enable auto-cpufreq.service
        sudo systemctl start auto-cpufreq.service
        echo -e "${GREEN}✅ auto-cpufreq включен${RESET}"
    else
        echo -e "${GREEN}✅ auto-cpufreq уже установлен${RESET}"
    fi
    
    echo -e "${CYAN}🔄 Включаем службы TLP...${RESET}"
    sudo systemctl enable tlp.service
    sudo systemctl start tlp.service
    
    if systemctl list-unit-files | grep -q "tlp-sleep.service"; then
        sudo systemctl enable tlp-sleep.service
        echo -e "${GREEN}✅ Служба tlp-sleep.service включена${RESET}"
    fi
    
    if systemctl list-unit-files | grep -q "power-profiles-daemon.service"; then
        echo -e "${CYAN}🔄 Отключаем power-profiles-daemon для предотвращения конфликтов с TLP...${RESET}"
        sudo systemctl disable power-profiles-daemon.service
        sudo systemctl stop power-profiles-daemon.service
        echo -e "${GREEN}✅ power-profiles-daemon отключен${RESET}"
    fi
    
    POWERTOP_SERVICE="/etc/systemd/system/powertop-auto-tune.service"
    if [ ! -f "$POWERTOP_SERVICE" ]; then
        echo -e "${CYAN}🔧 Создаем службу powertop-auto-tune...${RESET}"
        sudo tee "$POWERTOP_SERVICE" > /dev/null <<EOF
[Unit]
Description=PowerTOP auto tune
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/bin/powertop --auto-tune

[Install]
WantedBy=multi-user.target
EOF
        sudo systemctl daemon-reload
        sudo systemctl enable powertop-auto-tune.service
        echo -e "${GREEN}✅ Служба powertop-auto-tune создана и включена${RESET}"
    else
        echo -e "${GREEN}✅ Служба powertop-auto-tune уже существует${RESET}"
    fi



        # ─── Настройка яркости экрана ───
    echo -e "${CYAN}💡 Настраиваем управление яркостью...${RESET}"

    UDEV_BACKLIGHT="/etc/udev/rules.d/90-backlight.rules"
    if [ ! -f "$UDEV_BACKLIGHT" ]; then
        sudo tee "$UDEV_BACKLIGHT" > /dev/null <<'EOF'
# Разрешаем пользователям группы video управлять яркостью
ACTION=="add", SUBSYSTEM=="backlight", RUN+="/bin/chgrp video /sys/class/backlight/%k/brightness"
ACTION=="add", SUBSYSTEM=="backlight", RUN+="/bin/chmod g+w /sys/class/backlight/%k/brightness"
EOF
        echo -e "${GREEN}✅ Udev правило для яркости создано${RESET}"
        sudo udevadm control --reload-rules
        sudo udevadm trigger --subsystem-match=backlight
    else
        echo -e "${GREEN}✅ Udev правило для яркости уже существует${RESET}"
    fi

    # Добавляем пользователя в группу video
    if ! groups "$USER" | grep -q '\bvideo\b'; then
        sudo usermod -aG video "$USER"
        echo -e "${GREEN}✅ Пользователь добавлен в группу video${RESET}"
        echo -e "${YELLOW}⚠️ Требуется перелогиниться для применения прав${RESET}"
    else
        echo -e "${GREEN}✅ Пользователь уже в группе video${RESET}"
    fi

    # Проверка на Lenovo Legion Slim 5 16AHP9 (83DH) — AMD iGPU + NVIDIA dGPU
    # Яркость управляется через NVIDIA Embedded Controller, нужен acpi_backlight=nvidia_wmi_ec
    PRODUCT=$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo "unknown")
    if [ "$PRODUCT" = "83DH" ] && [ ! -d "/sys/class/backlight/nvidia_wmi_ec_backlight" ]; then
        echo -e "${YELLOW}⚠️  Обнаружен Lenovo Legion Slim 5 ($PRODUCT) — яркость через NVIDIA EC${RESET}"
        echo -e "${YELLOW}📝 Для работы яркости добавьте в загрузчик: acpi_backlight=nvidia_wmi_ec${RESET}"
        echo -e "${YELLOW}   (удалите acpi_backlight=native если есть)${RESET}"
        echo -e "${YELLOW}💡 После перезагрузки появится nvidia_wmi_ec_backlight и яркость заработает!${RESET}"
    fi
    
    echo -e "${GREEN}✅ Настройка энергосбережения для ноутбука завершена!${RESET}"
}

setup_power_management() {
    if is_laptop; then
        echo -e "${CYAN}"
        echo "┌────────────────────────────────────────────┐"
        echo "│     🔋 Настройка энергосбережения для      │"
        echo "│               ноутбука                     │"
        echo "└────────────────────────────────────────────┘"
        echo -e "${RESET}"
        setup_laptop_power
    else
        echo -e "${YELLOW}ℹ️ Система не определена как ноутбук, пропускаем настройку энергосбережения${RESET}"
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_power_management
fi

export -f setup_power_management
