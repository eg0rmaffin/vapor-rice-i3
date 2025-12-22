#!/bin/bash
# scripts/snapshot_setup.sh
# Скрипт для настройки системных снэпшотов с использованием Snapper на Btrfs
# Enables system stability through easy rollback capabilities

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
RED="\033[0;31m"
RESET="\033[0m"

# Функция для проверки наличия пакета
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
    yay -S --noconfirm "$1"
}

# ──── Проверка Btrfs ────
check_btrfs() {
    echo -e "${CYAN}🔍 Проверяем файловую систему...${RESET}"

    local root_fs
    root_fs=$(df -T / | awk 'NR==2 {print $2}')

    if [ "$root_fs" != "btrfs" ]; then
        echo -e "${YELLOW}⚠️ Корневая файловая система не Btrfs (обнаружено: $root_fs)${RESET}"
        echo -e "${YELLOW}   Снэпшоты Snapper требуют файловую систему Btrfs.${RESET}"
        echo -e "${YELLOW}   Для включения снэпшотов необходимо переустановить систему с Btrfs.${RESET}"
        return 1
    fi

    echo -e "${GREEN}✅ Обнаружена файловая система Btrfs${RESET}"
    return 0
}

# ──── Проверка подтомов Btrfs ────
check_subvolumes() {
    echo -e "${CYAN}🔍 Проверяем подтома Btrfs...${RESET}"

    # Проверяем текущие подтома
    local subvols
    subvols=$(sudo btrfs subvolume list / 2>/dev/null)

    if [ -z "$subvols" ]; then
        echo -e "${YELLOW}⚠️ Подтома Btrfs не обнаружены${RESET}"
        echo -e "${YELLOW}   Рекомендуется использовать раскладку подтомов: @, @home, @snapshots${RESET}"
        return 1
    fi

    echo -e "${GREEN}✅ Обнаружены подтома Btrfs:${RESET}"
    echo "$subvols" | head -10

    return 0
}

# ──── Установка пакетов снэпшотов ────
install_snapshot_packages() {
    echo -e "${CYAN}📦 Устанавливаем пакеты для снэпшотов...${RESET}"

    # Основные пакеты
    local pkgs=(
        snapper           # Основной инструмент для управления снэпшотами
        snap-pac          # Автоматические снэпшоты при обновлении пакетов через pacman
        grub-btrfs        # Добавление снэпшотов в загрузочное меню GRUB
        inotify-tools     # Необходимо для grub-btrfsd демона
    )

    for pkg in "${pkgs[@]}"; do
        if ! check_package "$pkg"; then
            install_package "$pkg"
        else
            echo -e "${GREEN}✅ $pkg уже установлен${RESET}"
        fi
    done

    # AUR пакеты (опционально)
    local aur_pkgs=(
        snap-pac-grub     # Автоматическое обновление GRUB после создания снэпшотов
    )

    for pkg in "${aur_pkgs[@]}"; do
        if ! check_package "$pkg"; then
            echo -e "${CYAN}📦 Пытаемся установить $pkg из AUR (опционально)...${RESET}"
            install_aur_package "$pkg" || echo -e "${YELLOW}⚠️ Не удалось установить $pkg, продолжаем...${RESET}"
        else
            echo -e "${GREEN}✅ $pkg уже установлен${RESET}"
        fi
    done
}

# ──── Создание конфигурации Snapper ────
configure_snapper() {
    echo -e "${CYAN}🔧 Настраиваем Snapper...${RESET}"

    # Проверяем, существует ли уже конфигурация root
    if [ -f /etc/snapper/configs/root ]; then
        echo -e "${GREEN}✅ Конфигурация Snapper для root уже существует${RESET}"
        return 0
    fi

    # Проверяем существование подтома .snapshots
    if sudo btrfs subvolume list / | grep -q '\.snapshots'; then
        echo -e "${YELLOW}⚠️ Подтом .snapshots уже существует${RESET}"
        echo -e "${CYAN}   Пытаемся создать конфигурацию Snapper...${RESET}"
    fi

    # Создаем конфигурацию snapper для корневого раздела
    echo -e "${CYAN}📝 Создаем конфигурацию Snapper для root...${RESET}"

    if sudo snapper -c root create-config / 2>/dev/null; then
        echo -e "${GREEN}✅ Конфигурация Snapper создана успешно${RESET}"
    else
        echo -e "${YELLOW}⚠️ Не удалось создать конфигурацию автоматически${RESET}"
        echo -e "${YELLOW}   Возможно, подтом .snapshots уже существует или есть проблемы с правами${RESET}"
        echo -e "${CYAN}   Для ручной настройки:${RESET}"
        echo -e "${CYAN}   1. Удалите существующий подтом: sudo btrfs subvolume delete /.snapshots${RESET}"
        echo -e "${CYAN}   2. Запустите: sudo snapper -c root create-config /${RESET}"
        return 1
    fi

    # Настраиваем таймлайн снэпшотов
    echo -e "${CYAN}📝 Настраиваем политику хранения снэпшотов...${RESET}"

    # Настраиваем количество хранимых снэпшотов
    sudo sed -i 's/^TIMELINE_LIMIT_HOURLY=.*/TIMELINE_LIMIT_HOURLY="5"/' /etc/snapper/configs/root
    sudo sed -i 's/^TIMELINE_LIMIT_DAILY=.*/TIMELINE_LIMIT_DAILY="7"/' /etc/snapper/configs/root
    sudo sed -i 's/^TIMELINE_LIMIT_WEEKLY=.*/TIMELINE_LIMIT_WEEKLY="4"/' /etc/snapper/configs/root
    sudo sed -i 's/^TIMELINE_LIMIT_MONTHLY=.*/TIMELINE_LIMIT_MONTHLY="6"/' /etc/snapper/configs/root
    sudo sed -i 's/^TIMELINE_LIMIT_YEARLY=.*/TIMELINE_LIMIT_YEARLY="2"/' /etc/snapper/configs/root

    # Включаем автоматическую очистку
    sudo sed -i 's/^TIMELINE_CLEANUP=.*/TIMELINE_CLEANUP="yes"/' /etc/snapper/configs/root

    echo -e "${GREEN}✅ Политика хранения снэпшотов настроена${RESET}"

    return 0
}

# ──── Настройка таймеров systemd ────
setup_systemd_timers() {
    echo -e "${CYAN}⏰ Настраиваем автоматическое создание снэпшотов...${RESET}"

    # Включаем таймер для автоматического создания снэпшотов
    if systemctl list-unit-files | grep -q "snapper-timeline.timer"; then
        sudo systemctl enable --now snapper-timeline.timer
        echo -e "${GREEN}✅ Таймер snapper-timeline включен${RESET}"
    else
        echo -e "${YELLOW}⚠️ Таймер snapper-timeline не найден${RESET}"
    fi

    # Включаем таймер для автоматической очистки старых снэпшотов
    if systemctl list-unit-files | grep -q "snapper-cleanup.timer"; then
        sudo systemctl enable --now snapper-cleanup.timer
        echo -e "${GREEN}✅ Таймер snapper-cleanup включен${RESET}"
    else
        echo -e "${YELLOW}⚠️ Таймер snapper-cleanup не найден${RESET}"
    fi

    # Включаем демон grub-btrfs для обновления GRUB при создании снэпшотов
    if systemctl list-unit-files | grep -q "grub-btrfsd.service"; then
        sudo systemctl enable --now grub-btrfsd.service
        echo -e "${GREEN}✅ Сервис grub-btrfsd включен${RESET}"
    else
        echo -e "${YELLOW}⚠️ Сервис grub-btrfsd не найден${RESET}"
    fi
}

# ──── Создание скриптов-помощников ────
create_helper_scripts() {
    echo -e "${CYAN}🔧 Создаем скрипты-помощники...${RESET}"

    mkdir -p ~/.local/bin

    # Скрипт для создания ручного снэпшота
    cat > ~/.local/bin/snapshot-create << 'SCRIPT_EOF'
#!/bin/bash
# Создание ручного снэпшота системы
GREEN="\033[0;32m"
CYAN="\033[0;36m"
RESET="\033[0m"

DESCRIPTION="${1:-Manual snapshot}"

echo -e "${CYAN}📸 Создаем снэпшот: $DESCRIPTION${RESET}"

if sudo snapper -c root create --description "$DESCRIPTION"; then
    echo -e "${GREEN}✅ Снэпшот создан успешно${RESET}"
    sudo snapper -c root list | tail -5
else
    echo -e "\033[0;31m❌ Ошибка при создании снэпшота${RESET}"
    exit 1
fi
SCRIPT_EOF
    chmod +x ~/.local/bin/snapshot-create

    # Скрипт для просмотра списка снэпшотов
    cat > ~/.local/bin/snapshot-list << 'SCRIPT_EOF'
#!/bin/bash
# Просмотр списка снэпшотов
echo -e "\033[0;36m📋 Список снэпшотов:\033[0m"
sudo snapper -c root list
SCRIPT_EOF
    chmod +x ~/.local/bin/snapshot-list

    # Скрипт для сравнения снэпшотов
    cat > ~/.local/bin/snapshot-diff << 'SCRIPT_EOF'
#!/bin/bash
# Сравнение двух снэпшотов
GREEN="\033[0;32m"
CYAN="\033[0;36m"
YELLOW="\033[1;33m"
RESET="\033[0m"

if [ -z "$1" ] || [ -z "$2" ]; then
    echo -e "${YELLOW}Использование: snapshot-diff <номер1> <номер2>${RESET}"
    echo -e "${CYAN}Пример: snapshot-diff 1 5${RESET}"
    echo ""
    echo -e "${CYAN}Доступные снэпшоты:${RESET}"
    sudo snapper -c root list
    exit 1
fi

echo -e "${CYAN}🔍 Сравнение снэпшотов $1 и $2:${RESET}"
sudo snapper -c root status "$1".."$2"
SCRIPT_EOF
    chmod +x ~/.local/bin/snapshot-diff

    # Скрипт для удаления снэпшота
    cat > ~/.local/bin/snapshot-delete << 'SCRIPT_EOF'
#!/bin/bash
# Удаление снэпшота
GREEN="\033[0;32m"
CYAN="\033[0;36m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
RESET="\033[0m"

if [ -z "$1" ]; then
    echo -e "${YELLOW}Использование: snapshot-delete <номер>${RESET}"
    echo -e "${CYAN}Пример: snapshot-delete 5${RESET}"
    echo ""
    echo -e "${CYAN}Доступные снэпшоты:${RESET}"
    sudo snapper -c root list
    exit 1
fi

echo -e "${YELLOW}⚠️  Вы уверены, что хотите удалить снэпшот $1? (y/N)${RESET}"
read -r confirm
if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
    if sudo snapper -c root delete "$1"; then
        echo -e "${GREEN}✅ Снэпшот $1 удален${RESET}"
    else
        echo -e "${RED}❌ Ошибка при удалении снэпшота${RESET}"
        exit 1
    fi
else
    echo -e "${CYAN}Отменено${RESET}"
fi
SCRIPT_EOF
    chmod +x ~/.local/bin/snapshot-delete

    # Скрипт для отката к снэпшоту (информационный)
    cat > ~/.local/bin/snapshot-rollback << 'SCRIPT_EOF'
#!/bin/bash
# Информация о откате к снэпшоту
CYAN="\033[0;36m"
YELLOW="\033[1;33m"
GREEN="\033[0;32m"
RESET="\033[0m"

echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${RESET}"
echo -e "${CYAN}│           📖 Инструкция по откату системы                  │${RESET}"
echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${RESET}"
echo ""
echo -e "${GREEN}Способ 1: Загрузка в снэпшот через GRUB${RESET}"
echo -e "  1. Перезагрузите компьютер"
echo -e "  2. В меню GRUB выберите 'Arch Linux snapshots'"
echo -e "  3. Выберите нужный снэпшот для загрузки"
echo ""
echo -e "${GREEN}Способ 2: Ручной откат (рекомендуется для постоянного отката)${RESET}"
echo -e "  ${YELLOW}⚠️  Выполняйте эти команды только если вы понимаете, что делаете!${RESET}"
echo ""
echo -e "  1. Загрузитесь в Live USB или в снэпшот"
echo -e "  2. Смонтируйте корневой Btrfs раздел:"
echo -e "     ${CYAN}sudo mount /dev/sdXY /mnt${RESET}"
echo -e "  3. Переименуйте текущий подтом @:"
echo -e "     ${CYAN}sudo mv /mnt/@ /mnt/@.broken${RESET}"
echo -e "  4. Создайте новый @ из снэпшота:"
echo -e "     ${CYAN}sudo btrfs subvolume snapshot /mnt/@.snapshots/X/snapshot /mnt/@${RESET}"
echo -e "     (где X - номер нужного снэпшота)"
echo -e "  5. Перезагрузитесь"
echo ""
echo -e "${CYAN}Текущие снэпшоты:${RESET}"
sudo snapper -c root list 2>/dev/null || echo -e "${YELLOW}Snapper не настроен${RESET}"
SCRIPT_EOF
    chmod +x ~/.local/bin/snapshot-rollback

    echo -e "${GREEN}✅ Скрипты-помощники созданы:${RESET}"
    echo -e "   ${CYAN}snapshot-create${RESET} - создание ручного снэпшота"
    echo -e "   ${CYAN}snapshot-list${RESET}   - просмотр списка снэпшотов"
    echo -e "   ${CYAN}snapshot-diff${RESET}   - сравнение двух снэпшотов"
    echo -e "   ${CYAN}snapshot-delete${RESET} - удаление снэпшота"
    echo -e "   ${CYAN}snapshot-rollback${RESET} - инструкция по откату"
}

# ──── Создание симлинков для helper scripts ────
link_helper_scripts() {
    echo -e "${CYAN}🔗 Связываем скрипты снэпшотов...${RESET}"

    mkdir -p ~/.local/bin

    # Создаем симлинки из dotfiles
    for script in snapshot-create snapshot-list snapshot-diff snapshot-delete snapshot-rollback; do
        if [ -f ~/dotfiles/bin/$script ]; then
            ln -sf ~/dotfiles/bin/$script ~/.local/bin/$script
            echo -e "${GREEN}✅ $script связан${RESET}"
        fi
    done
}

# ──── Вывод информации о снэпшотах ────
print_snapshot_info() {
    echo -e "${CYAN}"
    echo "┌────────────────────────────────────────────────────────────┐"
    echo "│              📸 Снэпшоты успешно настроены!                │"
    echo "└────────────────────────────────────────────────────────────┘"
    echo -e "${RESET}"
    echo ""
    echo -e "${GREEN}Автоматические снэпшоты:${RESET}"
    echo -e "  • При каждом обновлении пакетов (snap-pac)"
    echo -e "  • Каждый час (timeline)"
    echo -e "  • Доступны в меню GRUB для загрузки"
    echo ""
    echo -e "${GREEN}Доступные команды:${RESET}"
    echo -e "  ${CYAN}snapshot-create \"описание\"${RESET} - создать ручной снэпшот"
    echo -e "  ${CYAN}snapshot-list${RESET}              - показать все снэпшоты"
    echo -e "  ${CYAN}snapshot-diff 1 5${RESET}          - сравнить снэпшоты 1 и 5"
    echo -e "  ${CYAN}snapshot-delete 5${RESET}          - удалить снэпшот 5"
    echo -e "  ${CYAN}snapshot-rollback${RESET}          - инструкция по откату"
    echo ""
    echo -e "${YELLOW}Примечание:${RESET} Для отката загрузитесь в GRUB → 'Arch Linux snapshots'"
}

# ──── Главная функция ────
setup_snapshots() {
    echo -e "${CYAN}"
    echo "┌────────────────────────────────────────────────────────────┐"
    echo "│         📸 Настройка системных снэпшотов (Snapper)         │"
    echo "└────────────────────────────────────────────────────────────┘"
    echo -e "${RESET}"

    # Проверяем Btrfs
    if ! check_btrfs; then
        echo -e "${YELLOW}"
        echo "┌────────────────────────────────────────────────────────────┐"
        echo "│  ⚠️  Снэпшоты недоступны без файловой системы Btrfs       │"
        echo "└────────────────────────────────────────────────────────────┘"
        echo -e "${RESET}"
        echo ""
        echo -e "${CYAN}Для использования снэпшотов рекомендуется:${RESET}"
        echo -e "  1. Переустановить систему с Btrfs"
        echo -e "  2. Использовать раскладку подтомов: @, @home, @snapshots, @var_log"
        echo ""
        echo -e "${CYAN}Альтернатива для ext4/других ФС:${RESET}"
        echo -e "  • Timeshift (требует отдельный раздел или rsync)"
        echo -e "  • Ручные бэкапы с rsync"
        return 1
    fi

    check_subvolumes

    # Устанавливаем пакеты
    install_snapshot_packages

    # Настраиваем Snapper
    configure_snapper

    # Настраиваем systemd таймеры
    setup_systemd_timers

    # Создаем скрипты-помощники
    create_helper_scripts

    # Выводим информацию
    print_snapshot_info

    echo -e "${GREEN}✅ Настройка снэпшотов завершена!${RESET}"
}

# Если скрипт запущен напрямую
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_snapshots
fi

export -f setup_snapshots
