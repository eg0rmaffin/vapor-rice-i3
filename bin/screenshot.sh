#!/bin/bash

# Режим: по умолчанию full (весь экран), можно передать "area"
MODE="${1:-full}"

# Путь к файлу
DIR=~/Pictures/Screenshots
mkdir -p "$DIR"

# Делаем скриншот
if [ "$MODE" = "area" ]; then
  # 🔹 Новый режим: выбор области
  # --accept-on-select → сразу делает снимок, не нужно ещё раз кликать
  # --clipboard → кладёт в буфер обмена
  flameshot gui --accept-on-select --path "$DIR" --clipboard
else
  # Старое поведение: полный экран
  flameshot screen -p "$DIR"
fi

# Ждём, пока он появится
screenshot="$DIR/$(ls -t "$DIR" | head -n1)"
while [ ! -s "$screenshot" ]; do
  sleep 0.1
done

# Копируем в буфер (для full; в area flameshot уже положил, но лишним не будет)
cp "$screenshot" /tmp/screenshot.png
xclip -selection clipboard -t image/png -i /tmp/screenshot.png || true


# Звук
paplay ~/dotfiles/sounds/snap.wav 2>/dev/null || true
