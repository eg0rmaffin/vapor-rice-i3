#!/usr/bin/env bash
# ─────────────────────────────────────────────
# 🔊 Vaporwave OSD Volume Indicator
#    Linked by install.sh → ~/.local/bin/volume.sh
#    Used by: detect-audio-keys.sh → audio.conf
#    Stack: pamixer + dunst (libnotify)
# ─────────────────────────────────────────────

vol=$(pamixer --get-volume)
muted=$(pamixer --get-mute)

# replace-id позволяет dunst обновлять плашку вместо спама
REPLACE_ID=420

if [ "$muted" = "true" ]; then
  notify-send -u low -t 1200 --replace-id=$REPLACE_ID \
    --hint=int:value:0 --app-name="volume-osd" \
    "🔇 Volume muted"
else
  notify-send -u low -t 1200 --replace-id=$REPLACE_ID \
    --hint=int:value:$vol --app-name="volume-osd" \
    "🔊 Volume $vol%"
fi
