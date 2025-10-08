#!/bin/bash
set -e

WALL_DIR="$HOME/dotfiles/wallpapers"
STATE_FILE="$HOME/.cache/current_wall"

mkdir -p "$(dirname "$STATE_FILE")"

# получаем список файлов по имени
mapfile -t WALLS < <(find "$WALL_DIR" -type f | sort -V)

if [ ${#WALLS[@]} -eq 0 ]; then
  echo "❌ No wallpapers found in $WALL_DIR"
  exit 1
fi

# читаем текущий номер (по-умолчанию 0 — значит, ещё не было)
if [ -f "$STATE_FILE" ]; then
  CUR=$(<"$STATE_FILE")
else
  CUR=0
fi

# корректируем на 1-индексацию
NEXT=$((CUR + 1))
if [ $NEXT -gt ${#WALLS[@]} ]; then
  NEXT=1
fi

# применяем обои
feh --bg-scale "${WALLS[$((NEXT - 1))]}"

# сохраняем новое состояние
echo "$NEXT" > "$STATE_FILE"
