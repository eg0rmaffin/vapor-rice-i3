#!/bin/bash
# ─────────────────────────────────────────────
# 🎧 Audio Policy Setup
#    Deploys deterministic WirePlumber + PipeWire audio policy.
#    Called from install.sh after PipeWire services are enabled.
#
#    Policy goals (Windows-like):
#      - One default output, all streams follow it
#      - Bluetooth: A2DP only, no HSP/HFP profile switching
#      - Microphone does NOT degrade output quality
#      - No auto-mute/cork on device hot-plug
#      - Device hot-plug = redirect everything automatically
#
#    Dependencies: wireplumber, pipewire, pipewire-pulse
# ─────────────────────────────────────────────

setup_audio_policy() {
    echo -e "${CYAN}🎧 Deploying deterministic audio policy...${RESET}"

    # ─── WirePlumber policy configs ───
    local wp_conf_dir="$HOME/.config/wireplumber/wireplumber.conf.d"
    mkdir -p "$wp_conf_dir"

    # Symlink all policy configs from dotfiles
    for conf in ~/dotfiles/wireplumber/*.conf; do
        local name
        name="$(basename "$conf")"
        ln -sf "$conf" "$wp_conf_dir/$name"
        echo -e "  ${GREEN}✅ $name${RESET}"
    done

    # ─── Restart WirePlumber to apply ───
    if systemctl --user is-active wireplumber.service &>/dev/null; then
        echo -e "${CYAN}  🔄 Restarting WirePlumber to apply audio policy...${RESET}"
        systemctl --user restart wireplumber.service 2>/dev/null || true
        echo -e "  ${GREEN}✅ WirePlumber restarted${RESET}"
    else
        echo -e "  ${YELLOW}⚠️ WirePlumber not running, policy will apply on next start${RESET}"
    fi

    echo -e "${GREEN}✅ Deterministic audio policy deployed${RESET}"
}
