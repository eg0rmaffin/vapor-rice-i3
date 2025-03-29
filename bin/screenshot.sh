#!/bin/bash

# Путь к файлу
DIR=~/Pictures/Screenshots
mkdir -p "$DIR"

# Делаем скриншот
flameshot screen -p "$DIR"

# Ждём, пока он появится
screenshot="$DIR/$(ls -t "$DIR" | head -n1)"
while [ ! -s "$screenshot" ]; do
  sleep 0.1
done

# Копируем в буфер
cp "$screenshot" /tmp/screenshot.png
xclip -selection clipboard -t image/png -i /tmp/screenshot.png

# Звук
paplay ~/dotfiles/sounds/snap.wav
