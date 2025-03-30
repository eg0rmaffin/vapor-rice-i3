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

# 🔧 ВАЖНО: сохраняем вывод в лог, чтобы не запускать makepkg дважды (иначе могут удалиться исходники!)
LOG=$(mktemp)
if makepkg -si --noconfirm > "$LOG" 2>&1; then
  echo "✅ Установилось без патчей."
else
  echo "⚠️ Сборка упала, пытаемся определить cmake_policy..."

  # 📝 Пытаемся вытащить уже существующую cmake_policy
  POLICY_LINE=$(grep -oE 'cmake_policy\(VERSION [0-9]+\.[0-9]+' CMakeLists.txt || true)

  if [ -z "$POLICY_LINE" ]; then
    # 🧠 Извлекаем нужную версию cmake_policy из вывода makepkg
    ERROR_LINE=$(grep -m1 'cmake_policy' "$LOG" || true)
    POLICY_VERSION=$(echo "$ERROR_LINE" | grep -oE '[0-9]+\.[0-9]+' || echo "3.5")

    echo "🔧 Патчим CMakeLists.txt → cmake_policy(VERSION $POLICY_VERSION)"
    sed -i "1i cmake_policy(VERSION $POLICY_VERSION)" CMakeLists.txt
  else
    echo "ℹ️ Уже есть строка политики: $POLICY_LINE"
  fi

  echo "🔁 Повторная сборка с патчем..."
  makepkg -si --noconfirm
fi

popd > /dev/null
rm -rf "$TMP_DIR"
echo "🧹 Удалили временную папку $TMP_DIR"
