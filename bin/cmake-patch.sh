#!/bin/bash
set -e

PACKAGE="$1"
if [ -z "$PACKAGE" ]; then
  echo "❌ Не передано имя пакета."
  exit 1
fi

TMP_DIR="/tmp/$PACKAGE"
echo "📦 Клонируем AUR: $PACKAGE → $TMP_DIR"

# 🧹 Очистка если что-то осталось
if [ -d "$TMP_DIR" ]; then
  echo "🧹 Удаляем старый каталог $TMP_DIR..."
  rm -rf "$TMP_DIR"
fi

git clone "https://aur.archlinux.org/$PACKAGE.git" "$TMP_DIR"
pushd "$TMP_DIR" > /dev/null

# 🧪 Пробуем собрать только до распаковки
echo "📦 makepkg --nobuild (без сборки, чтобы сохранить src)"
makepkg --nobuild

# 🔍 Поиск CMakeLists.txt
CMAKE_FILE=$(find ./src -type f -name "CMakeLists.txt" | head -n 1)

if [ -z "$CMAKE_FILE" ]; then
  echo "❌ Не найден CMakeLists.txt"
  exit 1
fi

echo "📄 Используемый CMakeLists.txt: $CMAKE_FILE"

# 🔧 Извлекаем текущую и нужную версию
CURRENT_VERSION=$(grep -Po 'cmake_minimum_required\s*\(\s*VERSION\s*\K[0-9]+\.[0-9]+' "$CMAKE_FILE" || true)

# Пробуем извлечь из ошибки, если была
ERROR_VERSION=$(grep -Po 'CMake < \K[0-9]+\.[0-9]+' PKGBUILD || true)
POLICY_VERSION="${ERROR_VERSION:-3.25}"  # если ничего — берём безопасную версию

echo "🔢 Найдено: $CURRENT_VERSION"
echo "🧠 Требуется минимум: $POLICY_VERSION"

if [ -n "$CURRENT_VERSION" ]; then
  echo "🔁 Обновляем cmake_minimum_required до $POLICY_VERSION"
  sed -i -E "s/(cmake_minimum_required\s*\(\s*VERSION\s*)$CURRENT_VERSION/\1$POLICY_VERSION/" "$CMAKE_FILE"
else
  echo "📌 Вставляем строку cmake_minimum_required в начало"
  sed -i "1i cmake_minimum_required(VERSION $POLICY_VERSION)" "$CMAKE_FILE"
fi

# 📜 Выводим результат патча
echo "📜 CMakeLists.txt после правки:"
head -n 10 "$CMAKE_FILE"

# 🚀 Сборка с патчем
echo "🚀 makepkg --noextract --noarchive -si"
makepkg --noextract --noarchive -si

popd > /dev/null
rm -rf "$TMP_DIR"
echo "🧹 Удалили временную папку $TMP_DIR"
