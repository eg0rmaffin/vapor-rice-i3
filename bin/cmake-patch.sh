#!/bin/bash
set -e

PACKAGE="$1"

if [ -z "$PACKAGE" ]; then
  echo "❌ Не передано имя пакета."
  exit 1
fi

TMP_DIR="/tmp/$PACKAGE"
echo "📦 Клонируем AUR: $PACKAGE → $TMP_DIR"

# 🔥 Удалим временную папку, если осталась после сбоя
if [ -d "$TMP_DIR" ]; then
  echo "🧹 Старый каталог $TMP_DIR найден, удаляем..."
  rm -rf "$TMP_DIR"
fi

git clone "https://aur.archlinux.org/$PACKAGE.git" "$TMP_DIR"

pushd "$TMP_DIR" > /dev/null

echo "🧪 Пробуем собрать без патчей..."

# 🧾 Сохраняем вывод в лог, чтобы не запускать makepkg дважды
LOG=$(mktemp)
if makepkg -si --noconfirm >"$LOG" 2>&1; then
  echo "✅ Установилось без патчей."
else
  echo "⚠️ Сборка упала, пытаемся определить cmake_policy..."

  # 🔍 Находим путь к CMakeLists.txt
  CMAKE_FILE=$(find . -type f -name "CMakeLists.txt" | head -n 1)

  if [ -z "$CMAKE_FILE" ]; then
    echo "❌ Не найден CMakeLists.txt"
    exit 1
  fi

  # 🧠 Пытаемся вытащить существующую строку cmake_policy
  POLICY_LINE=$(grep -oE 'cmake_policy\(VERSION [0-9]+\.[0-9]+\)' "$CMAKE_FILE" || true)

  if [ -z "$POLICY_LINE" ]; then
    # 📦 Извлекаем нужную версию cmake_policy из ошибки
    ERROR_LINE=$(grep -m1 'cmake_policy' "$LOG" || true)
    POLICY_VERSION=$(echo "$ERROR_LINE" | grep -oE '[0-9]+\.[0-9]+' || echo "3.5")

    echo "🔧 Патчим CMakeLists.txt → cmake_policy(VERSION $POLICY_VERSION)"
    sed -i "1i cmake_policy(VERSION $POLICY_VERSION)" "$CMAKE_FILE"
  else
    echo "ℹ️ Уже есть строка политики: $POLICY_LINE"
  fi

  echo "🔁 Повторная сборка с патчем..."
  makepkg -si --noconfirm
fi

popd > /dev/null
rm -rf "$TMP_DIR"
echo "🧹 Удалили временную папку $TMP_DIR"
