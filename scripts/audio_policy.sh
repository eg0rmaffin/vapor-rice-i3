#!/bin/bash
# ─────────────────────────────────────────────
# Audio Policy Setup
#    Deploys deterministic WirePlumber + PipeWire audio policy.
#    Called from install.sh after PipeWire services are enabled.
#
#    Policy goals (Windows-like):
#      - One persistent virtual output sink (always exists)
#      - Applications connect to virtual sink, never to physical devices
#      - Physical devices attach/detach underneath via loopback
#      - Bluetooth: A2DP only, no HSP/HFP profile switching
#      - Microphone does NOT degrade output quality
#      - No auto-mute/cork on device hot-plug
#      - Device hot-plug = redirect loopback automatically
#
#    Architecture:
#      App streams → [Virtual Output sink] → loopback → [physical device]
#      When BT connects:  loopback moves to BT   (apps unaffected)
#      When BT disconnects: loopback moves back   (apps unaffected)
#
#    Dependencies: wireplumber, pipewire, pipewire-pulse
# ─────────────────────────────────────────────

setup_audio_policy() {
    echo -e "${CYAN}🎧 Deploying deterministic audio policy...${RESET}"

    # ─── PipeWire virtual sink config ───
    local pw_conf_dir="$HOME/.config/pipewire/pipewire.conf.d"
    mkdir -p "$pw_conf_dir"

    for conf in ~/dotfiles/pipewire/*.conf; do
        local name
        name="$(basename "$conf")"
        ln -sf "$conf" "$pw_conf_dir/$name"
        echo -e "  ${GREEN}✅ [pipewire] $name${RESET}"
    done

    # ─── WirePlumber policy configs ───
    local wp_conf_dir="$HOME/.config/wireplumber/wireplumber.conf.d"
    mkdir -p "$wp_conf_dir"

    for conf in ~/dotfiles/wireplumber/*.conf; do
        local name
        name="$(basename "$conf")"
        ln -sf "$conf" "$wp_conf_dir/$name"
        echo -e "  ${GREEN}✅ [wireplumber] $name${RESET}"
    done

    # ─── Clear stale WirePlumber state ───
    # Remove cached stream targets and default device selections so
    # WirePlumber discovers the new Virtual Output sink cleanly.
    local wp_state_dir="$HOME/.local/state/wireplumber"
    if [ -d "$wp_state_dir" ]; then
        echo -e "${CYAN}  🧹 Clearing stale WirePlumber state...${RESET}"
        rm -f "$wp_state_dir/stream-properties" 2>/dev/null || true
        rm -f "$wp_state_dir/default-routes" 2>/dev/null || true
        rm -f "$wp_state_dir/restore-stream" 2>/dev/null || true
        echo -e "  ${GREEN}✅ Stale state cleared${RESET}"
    fi

    # ─── Restart PipeWire + WirePlumber to apply ───
    if systemctl --user is-active pipewire.service &>/dev/null; then
        echo -e "${CYAN}  🔄 Restarting PipeWire to load virtual sink...${RESET}"
        systemctl --user restart pipewire.service 2>/dev/null || true
        # PipeWire-Pulse and WirePlumber restart automatically (socket-activated / bound)
        sleep 2
        echo -e "  ${GREEN}✅ PipeWire restarted${RESET}"
    else
        echo -e "  ${YELLOW}⚠️ PipeWire not running, policy will apply on next start${RESET}"
    fi

    # ─── Set Virtual Output as default sink ───
    if command -v wpctl &>/dev/null; then
        # Wait for WirePlumber to settle after restart
        sleep 1
        local virtual_id
        virtual_id=$(wpctl status 2>/dev/null | grep -i "virtual_output_sink" | grep -o '[0-9]*' | head -1)
        if [ -n "$virtual_id" ]; then
            wpctl set-default "$virtual_id" 2>/dev/null || true
            echo -e "  ${GREEN}✅ Virtual Output set as default sink (id=$virtual_id)${RESET}"
        else
            echo -e "  ${YELLOW}⚠️ Virtual Output sink not found yet (will be set on next login)${RESET}"
        fi
    fi

    echo -e "${GREEN}✅ Deterministic audio policy deployed${RESET}"
}
