#!/bin/bash

# Режим: по умолчанию full (весь экран), можно передать "area"
MODE="${1:-full}"

# Путь к файлу
DIR=~/Pictures/Screenshots
mkdir -p "$DIR"

# Запоминаем количество файлов до скриншота
count_before=$(ls -1 "$DIR" 2>/dev/null | wc -l)

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

# Проверяем, был ли создан новый файл (пользователь не нажал ESC)
count_after=$(ls -1 "$DIR" 2>/dev/null | wc -l)
if [ "$count_after" -le "$count_before" ]; then
  # Скриншот не был сохранён (отменён), выходим без звука
  exit 0
fi

# Ждём, пока файл появится
screenshot="$DIR/$(ls -t "$DIR" | head -n1)"
while [ ! -s "$screenshot" ]; do
  sleep 0.1
done

# Копируем в буфер (для full; в area flameshot уже положил, но лишним не будет)
cp "$screenshot" /tmp/screenshot.png
xclip -selection clipboard -t image/png -i /tmp/screenshot.png || true

# Звук (только если скриншот был сохранён)
paplay ~/dotfiles/sounds/snap.wav 2>/dev/null || true
