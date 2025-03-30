#!/bin/bash
set -e

PACKAGE="$1"

if [ -z "$PACKAGE" ]; then
  echo "❌ Не передано имя пакета."
  exit 1
fi

TMP_DIR="/tmp/$PACKAGE"
echo "📦 Клонируем AUR: $PACKAGE → $TMP_DIR"
git clone "https://aur.archlinux.org/$PACKAGE.git" "$TMP_DIR"

pushd "$TMP_DIR" > /dev/null

echo "🧪 Пробуем собрать без патчей..."
if ! makepkg -si --noconfirm; then
  echo "⚠️ Сборка провалилась. Пытаемся найти нужную версию cmake_policy..."

  POLICY_LINE=$(grep -oE 'cmake_policy\(VERSION [0-9]+\.[0-9]+\)' CMakeLists.txt || true)
  if [ -z "$POLICY_LINE" ]; then
    ERROR_LINE=$(makepkg 2>&1 | grep -m1 'cmake_policy' || true)
    POLICY_VERSION=$(echo "$ERROR_LINE" | grep -oE '[0-9]+\.[0-9]+' || echo "3.5")

    echo "🔧 Вставляем cmake_policy(VERSION $POLICY_VERSION) в CMakeLists.txt"
    sed -i "1i cmake_policy(VERSION $POLICY_VERSION)" CMakeLists.txt
  else
    echo "ℹ️ В CMakeLists.txt уже есть строка политики: $POLICY_LINE"
  fi

  echo "🔁 Повторная сборка с патчем..."
  makepkg -si --noconfirm
else
  echo "✅ Пакет успешно установлен без патча."
fi

popd > /dev/null
rm -rf "$TMP_DIR"
echo "🧹 Удалили временную папку $TMP_DIR"
