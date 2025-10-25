#!/bin/bash
# ─────────────────────────────────────────────
# 🔊 Настройка звуковой системы
audio_setup() {
    echo -e "${CYAN}🔧 Настройка звуковой системы с динамическими биндами...${RESET}"

    # Создаем директорию для аудио-конфигов
    mkdir -p ~/dotfiles/i3/includes

    # Создаем скрипт обнаружения аудио-клавиш и генерации конфига
    cat > ~/dotfiles/bin/detect-audio-keys.sh << 'EOF'
#!/bin/bash
# Определяем доступные клавиши звука на текущем устройстве
AUDIO_CONF="$HOME/dotfiles/i3/includes/audio.conf"

# Проверяем, существует ли уже конфигурационный файл
if [ -f "$AUDIO_CONF" ]; then
    # Файл существует, не перезаписываем его
    exit 0
fi

# Если файл не существует, создаем его
echo "# Автоматически сгенерированные бинды звука" > "$AUDIO_CONF"

# Проверяем доступные клавиши с помощью xmodmap
AUDIO_KEYS=()

# Проверка обычных XF86Audio клавиш
if xmodmap -pke | grep -q XF86AudioRaiseVolume; then
    AUDIO_KEYS+=("XF86AudioRaiseVolume")
fi
if xmodmap -pke | grep -q XF86AudioLowerVolume; then
    AUDIO_KEYS+=("XF86AudioLowerVolume")
fi
if xmodmap -pke | grep -q XF86AudioMute; then
    AUDIO_KEYS+=("XF86AudioMute")
fi

# Если стандартные клавиши не найдены, добавляем альтернативные комбинации
if [ ${#AUDIO_KEYS[@]} -eq 0 ]; then
    echo "# Стандартные клавиши звука не обнаружены, используем альтернативные" >> "$AUDIO_CONF"
    echo "bindsym \$mod+F9 exec --no-startup-id pamixer -i 5 # Громкость +" >> "$AUDIO_CONF"
    echo "bindsym \$mod+F8 exec --no-startup-id pamixer -d 5 # Громкость -" >> "$AUDIO_CONF"
    echo "bindsym \$mod+F7 exec --no-startup-id pamixer -t # Выкл/вкл звук" >> "$AUDIO_CONF"
else
    # Добавляем найденные клавиши в конфиг
    if [[ " ${AUDIO_KEYS[*]} " =~ "XF86AudioRaiseVolume" ]]; then
    echo "bindsym XF86AudioRaiseVolume exec --no-startup-id pamixer -i 5 && ~/.local/bin/volume.sh # Громкость +" >> "$AUDIO_CONF"
	fi
if [[ " ${AUDIO_KEYS[*]} " =~ "XF86AudioLowerVolume" ]]; then
    echo "bindsym XF86AudioLowerVolume exec --no-startup-id pamixer -d 5 && ~/.local/bin/volume.sh # Громкость -" >> "$AUDIO_CONF"
	fi
if [[ " ${AUDIO_KEYS[*]} " =~ "XF86AudioMute" ]]; then
    echo "bindsym XF86AudioMute exec --no-startup-id pamixer -t && ~/.local/bin/volume.sh # Выкл/вкл звук" >> "$AUDIO_CONF"
	fi
fi

# Добавляем открытие аудио-микшера
echo "bindsym \$mod+semicolon exec --no-startup-id pavucontrol # Открыть звуковой микшер" >> "$AUDIO_CONF"

# Инициализация звуковой системы
if command -v pipewire >/dev/null && ! pidof pipewire >/dev/null; then
    /usr/bin/pipewire &
fi
if command -v pipewire-pulse >/dev/null && ! pidof pipewire-pulse >/dev/null; then
    /usr/bin/pipewire-pulse &
fi
if command -v wireplumber >/dev/null && ! pidof wireplumber >/dev/null; then
    /usr/bin/wireplumber &
fi

# Устанавливаем начальную громкость
pactl set-sink-volume @DEFAULT_SINK@ 70% 2>/dev/null || true
pactl set-sink-mute @DEFAULT_SINK@ 0 2>/dev/null || true

exit 0
EOF

    chmod +x ~/dotfiles/bin/detect-audio-keys.sh
    echo -e "${GREEN}✅ Скрипт определения аудио-клавиш создан${RESET}"

    # Изменяем основной i3 конфиг, чтобы включить аудио-конфиг
    if ! grep -q "include.*audio.conf" ~/.config/i3/config; then
        echo -e "${CYAN}🔧 Обновление конфига i3 для динамического аудио...${RESET}"

        # Удаляем старые аудио-бинды из конфига i3
        sed -i '/XF86Audio/d' ~/.config/i3/config

        # Добавляем include директиву
        echo "" >> ~/.config/i3/config
        echo "# Включение динамической аудио-конфигурации" >> ~/.config/i3/config
        echo "include ~/dotfiles/i3/includes/audio.conf" >> ~/.config/i3/config

        echo -e "${GREEN}✅ Конфиг i3 обновлен для поддержки динамического аудио${RESET}"
    fi

    # Добавляем скрипт обнаружения в автозапуск i3, но с проверкой существования файла
    if ! grep -q "detect-audio-keys.sh" ~/.config/i3/config; then
        echo -e "${CYAN}🔧 Добавление скрипта аудио в автозапуск i3...${RESET}"
        echo "# Автоматическое определение и настройка аудио-клавиш" >> ~/.config/i3/config
        echo "exec_always --no-startup-id ~/dotfiles/bin/detect-audio-keys.sh" >> ~/.config/i3/config
        echo -e "${GREEN}✅ Скрипт аудио добавлен в автозапуск i3${RESET}"
    fi

    # Запускаем скрипт определения клавиш, если файл не существует
    if [ -n "$DISPLAY" ] && [ ! -f ~/dotfiles/i3/includes/audio.conf ]; then
        echo -e "${CYAN}🔧 Выполняем первичное определение аудио-клавиш...${RESET}"
        ~/dotfiles/bin/detect-audio-keys.sh
        echo -e "${GREEN}✅ Аудио-клавиши определены${RESET}"
    else
        echo -e "${YELLOW}⚠️ Пропускаем настройку клавиш: либо DISPLAY не определен, либо конфиг уже существует${RESET}"
    fi

    echo -e "${GREEN}✅ Динамическая звуковая система настроена${RESET}"
}
