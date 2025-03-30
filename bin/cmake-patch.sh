#!/bin/bash
set -e

PACKAGE="$1"
if [ -z "$PACKAGE" ]; then
  echo "❌ Не передано имя пакета."
  exit 1
fi

TMP_DIR="/tmp/$PACKAGE"
echo "📦 Клонируем AUR: $PACKAGE → $TMP_DIR"

if [ -d "$TMP_DIR" ]; then
  echo "🧹 Старый каталог $TMP_DIR найден, удаляем..."
  rm -rf "$TMP_DIR"
fi

git clone "https://aur.archlinux.org/$PACKAGE.git" "$TMP_DIR"
pushd "$TMP_DIR" > /dev/null

echo "🧪 Пробуем собрать без патчей..."
LOG=$(mktemp)

if makepkg -si --noconfirm >"$LOG" 2>&1; then
  echo "✅ Установилось без патчей."
else
  echo "⚠️ Сборка упала, анализируем..."

  CMAKE_FILE=$(find . -type f -name "CMakeLists.txt" | head -n 1)
  if [ -z "$CMAKE_FILE" ]; then
    echo "❌ Не найден CMakeLists.txt"
    exit 1
  fi

  echo "🔍 Ищем строку cmake_minimum_required в $CMAKE_FILE"
  CURRENT_LINE=$(grep -E 'cmake_minimum_required\(VERSION [0-9]+\.[0-9]+\)' "$CMAKE_FILE" || true)
  echo "   Найдено: $CURRENT_LINE"

  ERROR_LINE=$(grep -m1 'Compatibility with CMake' "$LOG" || true)
  POLICY_VERSION=$(echo "$ERROR_LINE" | grep -oE '[0-9]+\.[0-9]+' | tail -n1 || echo "3.25")
  echo "🔧 Требуемая версия по логу: $POLICY_VERSION"

  if [ -n "$CURRENT_LINE" ]; then
    echo "🔁 Заменяем строку на cmake_minimum_required(VERSION $POLICY_VERSION)"
    sed -i "s|$CURRENT_LINE|cmake_minimum_required(VERSION $POLICY_VERSION)|" "$CMAKE_FILE"
  else
    echo "📌 Вставляем новую строку в начало"
    sed -i "1i cmake_minimum_required(VERSION $POLICY_VERSION)" "$CMAKE_FILE"
  fi

  echo "🔁 Повторная сборка с патчем..."
  makepkg -si --noconfirm
fi

popd > /dev/null
rm -rf "$TMP_DIR"
echo "🧹 Удалили временную папку $TMP_DIR"
