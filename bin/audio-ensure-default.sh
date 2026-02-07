#!/bin/bash
# ─────────────────────────────────────────────
# Ensure Virtual Output is the default audio sink and physical devices
# are at full volume.
#
# Called from i3 autostart (exec_always) on every login and i3 reload.
# Waits for WirePlumber to discover the virtual sink node, then:
#   1. Sets virtual sink as default output
#   2. Sets all physical ALSA output sinks to 100% volume
#
# With the virtual sink architecture, the physical device should always
# be at max volume — the user controls volume through the virtual sink
# (one volume knob, Windows-like behavior).
#
# Safe to run repeatedly — idempotent.
#
# Dependencies: wireplumber (wpctl), pipewire-pulse (pactl)
# ─────────────────────────────────────────────

# Wait for WirePlumber to be ready (up to 5 seconds)
for i in $(seq 1 10); do
    if wpctl status &>/dev/null; then
        break
    fi
    sleep 0.5
done

# Find virtual_output_sink node ID in wpctl status output
virtual_id=$(wpctl status 2>/dev/null | grep -i "virtual_output_sink" | grep -o '[0-9]*' | head -1)

if [ -n "$virtual_id" ]; then
    wpctl set-default "$virtual_id" 2>/dev/null || true
fi

# ─── Set all physical ALSA output sinks to 100% volume ───
# The virtual sink is the user-facing volume control. Physical devices
# should be at max so the virtual sink volume maps 1:1 to actual output.
# This also overrides any previously saved low volumes from before the
# virtual sink architecture was deployed.
#
# Uses pactl (PulseAudio API via pipewire-pulse) to list sinks and set
# volume on each ALSA output sink. The virtual sink is skipped — its
# volume is the user-controlled knob.
if command -v pactl &>/dev/null; then
    pactl list sinks short 2>/dev/null | while read -r _ sink_name _; do
        case "$sink_name" in
            alsa_output.*)
                pactl set-sink-volume "$sink_name" 100% 2>/dev/null || true
                pactl set-sink-mute "$sink_name" 0 2>/dev/null || true
                ;;
        esac
    done
fi
