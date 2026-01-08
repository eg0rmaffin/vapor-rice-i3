#!/usr/bin/env bash
# ─────────────────────────────────────────────
# 🎵 Vaporwave OSD Media Indicator
#    Linked by install.sh → ~/.local/bin/media-osd.sh
#    Used by: i3 config media keys
#    Stack: playerctl + dunst (libnotify)
# ─────────────────────────────────────────────

# Source OSD panel library
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "$SCRIPT_DIR/osd-panel.sh"

# ─────────────────────────────────────────────
# Get media info from playerctl
# ─────────────────────────────────────────────
STATUS=$(playerctl status 2>/dev/null)

# No player running
if [ -z "$STATUS" ] || [ "$STATUS" = "No players found" ]; then
    osd_show_status "media-osd" "$OSD_ID_MEDIA" "🚫" "No media player"
    exit 0
fi

# Get track info
ARTIST=$(playerctl metadata artist 2>/dev/null | head -c 30)
TITLE=$(playerctl metadata title 2>/dev/null | head -c 40)

# Choose icon based on playback status
case "$STATUS" in
    Playing)
        ICON="▶️"
        ;;
    Paused)
        ICON="⏸️"
        ;;
    Stopped)
        ICON="⏹️"
        ;;
    *)
        ICON="🎵"
        ;;
esac

# Build message
if [ -n "$ARTIST" ] && [ -n "$TITLE" ]; then
    MESSAGE="$ARTIST - $TITLE"
elif [ -n "$TITLE" ]; then
    MESSAGE="$TITLE"
else
    MESSAGE="$STATUS"
fi

osd_show_status "media-osd" "$OSD_ID_MEDIA" "$ICON" "$MESSAGE"
