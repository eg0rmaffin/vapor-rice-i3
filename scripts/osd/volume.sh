#!/usr/bin/env bash
# ─────────────────────────────────────────────
# 🔊 Vaporwave OSD Volume Indicator
#    Linked by install.sh → ~/.local/bin/volume.sh
#    Used by: detect-audio-keys.sh → audio.conf
#    Stack: pamixer + dunst (libnotify)
# ─────────────────────────────────────────────

# Source OSD panel library
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "$SCRIPT_DIR/osd-panel.sh"

vol=$(pamixer --get-volume)
muted=$(pamixer --get-mute)

if [ "$muted" = "true" ]; then
  osd_show_progress "volume-osd" "$OSD_ID_VOLUME" "🔇" "Volume muted" "0"
else
  osd_show_progress "volume-osd" "$OSD_ID_VOLUME" "🔊" "Volume $vol%" "$vol"
fi
