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
  echo "⚠️ Сборка упала, пытаемся определить CMake версию..."

  # 🔍 Находим путь к CMakeLists.txt
  CMAKE_FILE=$(find . -type f -name "CMakeLists.txt" | head -n 1)

  if [ -z "$CMAKE_FILE" ]; then
    echo "❌ Не найден CMakeLists.txt"
    exit 1
  fi

  # 🧠 Ищем строку cmake_policy или cmake_minimum_required
  POLICY_LINE=$(grep -E 'cmake_(minimum_required|policy)\(VERSION [0-9]+\.[0-9]+\)' "$CMAKE_FILE" || true)

  if [ -z "$POLICY_LINE" ]; then
    # ⚠️ Ничего не найдено — берём версию из лога
    ERROR_LINE=$(grep -m1 'cmake' "$LOG" || true)
    POLICY_VERSION=$(echo "$ERROR_LINE" | grep -oE '[0-9]+\.[0-9]+' || echo "3.5")

    echo "🔧 Вставляем cmake_policy(VERSION $POLICY_VERSION) в начало $CMAKE_FILE"
    sed -i "1i cmake_policy(VERSION $POLICY_VERSION)" "$CMAKE_FILE"
  else
    POLICY_VERSION=$(echo "$POLICY_LINE" | grep -oE '[0-9]+\.[0-9]+')
    echo "ℹ️ Обнаружено: $POLICY_LINE"
    echo "🔁 Заменяем на cmake_policy(VERSION $POLICY_VERSION)"
    sed -i "s/$POLICY_LINE/cmake_policy(VERSION $POLICY_VERSION)/" "$CMAKE_FILE"
  fi

  echo "🔁 Повторная сборка с патчем..."
  makepkg -si --noconfirm
fi

popd > /dev/null
rm -rf "$TMP_DIR"
echo "🧹 Удалили временную папку $TMP_DIR"
