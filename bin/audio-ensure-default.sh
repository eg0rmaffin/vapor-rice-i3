#!/bin/bash
# ─────────────────────────────────────────────
# Ensure Virtual Output is the default audio sink.
#
# Called from i3 autostart (exec_always) on every login and i3 reload.
# Waits for WirePlumber to discover the virtual sink node, then sets it
# as the default output. This guarantees all application streams go
# through the virtual sink, which survives device hot-plug.
#
# Safe to run repeatedly — idempotent (no-op if already default).
#
# Dependencies: wireplumber (wpctl)
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
