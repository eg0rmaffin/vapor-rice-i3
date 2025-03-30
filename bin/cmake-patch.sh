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

  # Пробуем вытащить рекомендуемую версию из вывода ошибки
  ERROR_LINE=$(grep -m1 'Compatibility with CMake' "$LOG" || true)
  POLICY_VERSION=$(echo "$ERROR_LINE" | grep -oE '[0-9]+\.[0-9]+' | tail -n1 || echo "3.25")

  echo "🔧 Обновим CMakeLists.txt до cmake_minimum_required(VERSION $POLICY_VERSION)"
  sed -i -E "s/cmake_minimum_required\(VERSION [0-9]+\.[0-9]+\)/cmake_minimum_required(VERSION $POLICY_VERSION)/" "$CMAKE_FILE"

  echo "🔁 Повторная сборка с патчем..."
  makepkg -si --noconfirm
fi

popd > /dev/null
rm -rf "$TMP_DIR"
echo "🧹 Удалили временную папку $TMP_DIR"
