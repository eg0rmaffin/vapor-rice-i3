#!/usr/bin/env bash
# ─────────────────────────────────────────────
# 🎨 Vaporwave OSD Panel Library
#    Reusable dunst notification functions
#    for consistent OSD styling across all indicators
# ─────────────────────────────────────────────

# Replace IDs for different notification types (to update instead of spam)
# Each type gets unique ID so they don't interfere with each other
OSD_ID_VOLUME=420
OSD_ID_BRIGHTNESS=421
OSD_ID_MEDIA=422
OSD_ID_MIC=423

# Default notification timeout (ms)
OSD_TIMEOUT=1200

# ─────────────────────────────────────────────
# Show OSD notification with progress bar
# Usage: osd_show_progress <app_name> <replace_id> <icon> <title> <value>
# ─────────────────────────────────────────────
osd_show_progress() {
    local app_name="$1"
    local replace_id="$2"
    local icon="$3"
    local title="$4"
    local value="$5"  # 0-100 for progress bar

    notify-send -u low -t "$OSD_TIMEOUT" --replace-id="$replace_id" \
        --hint=int:value:"$value" --app-name="$app_name" \
        "$icon $title"
}

# ─────────────────────────────────────────────
# Show OSD notification without progress bar (status only)
# Usage: osd_show_status <app_name> <replace_id> <icon> <title>
# ─────────────────────────────────────────────
osd_show_status() {
    local app_name="$1"
    local replace_id="$2"
    local icon="$3"
    local title="$4"

    notify-send -u low -t "$OSD_TIMEOUT" --replace-id="$replace_id" \
        --app-name="$app_name" \
        "$icon $title"
}
