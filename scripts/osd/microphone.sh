#!/usr/bin/env bash
# ─────────────────────────────────────────────
# 🎤 Vaporwave OSD Microphone Indicator
#    Linked by install.sh → ~/.local/bin/microphone-osd.sh
#    Used by: i3 config mic mute keys
#    Stack: pamixer + dunst (libnotify)
# ─────────────────────────────────────────────

# Source OSD panel library
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "$SCRIPT_DIR/osd-panel.sh"

# ─────────────────────────────────────────────
# Get microphone status
# ─────────────────────────────────────────────
MUTED=$(pamixer --default-source --get-mute 2>/dev/null)

# Check if pamixer can access default source
if [ $? -ne 0 ]; then
    osd_show_status "mic-osd" "$OSD_ID_MIC" "❌" "Microphone not found"
    exit 1
fi

VOL=$(pamixer --default-source --get-volume 2>/dev/null)

if [ "$MUTED" = "true" ]; then
    osd_show_progress "mic-osd" "$OSD_ID_MIC" "🔇" "Microphone muted" "0"
else
    osd_show_progress "mic-osd" "$OSD_ID_MIC" "🎤" "Microphone $VOL%" "$VOL"
fi
