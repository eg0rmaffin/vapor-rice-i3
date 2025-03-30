#!/bin/bash
set -e

PACKAGE="$1"
if [ -z "$PACKAGE" ]; then
  echo "❌ Не передано имя пакета."
  exit 1
fi

TMP_DIR="/tmp/$PACKAGE"
echo "📦 Клонируем AUR: $PACKAGE → $TMP_DIR"

# 🧹 Очистка, если каталог остался
if [ -d "$TMP_DIR" ]; then
  echo "🧹 Удаляем старый каталог $TMP_DIR..."
  rm -rf "$TMP_DIR"
fi

git clone "https://aur.archlinux.org/$PACKAGE.git" "$TMP_DIR"
pushd "$TMP_DIR" > /dev/null

# 🧪 Сборка без компиляции — чтобы просто распаковать
echo "📦 makepkg --nobuild (без сборки)"
makepkg --nobuild

# 🔍 Поиск нужного CMakeLists.txt
CMAKE_FILE=$(find ./src -type f -name "CMakeLists.txt" | head -n 1)

if [ -z "$CMAKE_FILE" ]; then
  echo "❌ Не найден CMakeLists.txt"
  exit 1
fi

echo "📄 Используемый CMakeLists.txt: $CMAKE_FILE"

# 🔧 Удаляем все строки cmake_minimum_required
sed -i '/cmake_minimum_required\s*(/Id' "$CMAKE_FILE"

# 📌 Вставляем нужную строку в начало
POLICY_VERSION="3.25"
sed -i "1i cmake_minimum_required(VERSION $POLICY_VERSION)" "$CMAKE_FILE"

# 📜 Покажем первые строки файла
echo "📜 CMakeLists.txt после правки:"
head -n 10 "$CMAKE_FILE"

# 🚀 Повторная сборка с уже распакованным src
echo "🚀 makepkg --noextract --noarchive -si"
makepkg --noextract --noarchive -si

popd > /dev/null
rm -rf "$TMP_DIR"
echo "🧹 Удалили временную папку $TMP_DIR"
