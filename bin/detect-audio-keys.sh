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
