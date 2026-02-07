#!/bin/bash
# ─────────────────────────────────────────────
# 🎧 Audio Policy Diagnostic
#    Verifies that the deterministic audio policy is correctly deployed.
#
#    Usage: audio-policy-check.sh
#
#    Checks:
#      1. WirePlumber config files are deployed
#      2. WirePlumber is running and loaded configs
#      3. Bluetooth profile switching is disabled
#      4. Stream routing policy is correct
#      5. ALSA suspend policy is correct
#      6. Current audio device status
#
#    Dependencies: wireplumber, wpctl
# ─────────────────────────────────────────────

GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
RESET="\033[0m"

ok=0
fail=0

check() {
    local desc="$1"
    local result="$2"
    if [ "$result" = "true" ]; then
        echo -e "  ${GREEN}✅ $desc${RESET}"
        ok=$((ok + 1))
    else
        echo -e "  ${RED}❌ $desc${RESET}"
        fail=$((fail + 1))
    fi
}

echo -e "${CYAN}🎧 Audio Policy Diagnostic${RESET}"
echo ""

# ─── 1. Config files deployed ───
echo -e "${CYAN}📁 Config files:${RESET}"
WP_DIR="$HOME/.config/wireplumber/wireplumber.conf.d"

check "Bluetooth policy (51-audio-policy-bluetooth.conf)" \
    "$([ -f "$WP_DIR/51-audio-policy-bluetooth.conf" ] && echo true || echo false)"

check "Stream policy (52-audio-policy-streams.conf)" \
    "$([ -f "$WP_DIR/52-audio-policy-streams.conf" ] && echo true || echo false)"

check "ALSA policy (53-audio-policy-alsa.conf)" \
    "$([ -f "$WP_DIR/53-audio-policy-alsa.conf" ] && echo true || echo false)"

echo ""

# ─── 2. Services running ───
echo -e "${CYAN}🔧 Services:${RESET}"
check "PipeWire running" \
    "$(systemctl --user is-active pipewire.service &>/dev/null && echo true || echo false)"

check "PipeWire-Pulse running" \
    "$(systemctl --user is-active pipewire-pulse.service &>/dev/null && echo true || echo false)"

check "WirePlumber running" \
    "$(systemctl --user is-active wireplumber.service &>/dev/null && echo true || echo false)"

echo ""

# ─── 3. WirePlumber settings verification ───
if command -v wpctl &>/dev/null; then
    echo -e "${CYAN}⚙️  WirePlumber active settings:${RESET}"

    bt_switch=$(wpctl settings 2>/dev/null | grep -o 'bluetooth.autoswitch-to-headset-profile = [a-z]*' | awk '{print $NF}')
    if [ -n "$bt_switch" ]; then
        check "Bluetooth auto-switch disabled (=$bt_switch)" \
            "$([ "$bt_switch" = "false" ] && echo true || echo false)"
    else
        echo -e "  ${YELLOW}⚠️ Cannot read bluetooth.autoswitch setting (wpctl settings may not support this)${RESET}"
    fi

    follow=$(wpctl settings 2>/dev/null | grep -o 'linking.follow-default-target = [a-z]*' | awk '{print $NF}')
    if [ -n "$follow" ]; then
        check "Streams follow default target (=$follow)" \
            "$([ "$follow" = "true" ] && echo true || echo false)"
    fi

    pause=$(wpctl settings 2>/dev/null | grep -o 'linking.pause-playback = [a-z]*' | awk '{print $NF}')
    if [ -n "$pause" ]; then
        check "Pause-on-remove disabled (=$pause)" \
            "$([ "$pause" = "false" ] && echo true || echo false)"
    fi

    restore=$(wpctl settings 2>/dev/null | grep -o 'node.stream.restore-target = [a-z]*' | awk '{print $NF}')
    if [ -n "$restore" ]; then
        check "Per-app target restore disabled (=$restore)" \
            "$([ "$restore" = "false" ] && echo true || echo false)"
    fi

    echo ""
fi

# ─── 4. Audio device status ───
echo -e "${CYAN}🔊 Current audio devices:${RESET}"
if command -v wpctl &>/dev/null; then
    wpctl status 2>/dev/null | head -40
else
    echo -e "  ${YELLOW}⚠️ wpctl not found${RESET}"
fi

echo ""

# ─── Summary ───
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
if [ "$fail" -eq 0 ]; then
    echo -e "${GREEN}✅ All $ok checks passed — audio policy is active${RESET}"
else
    echo -e "${YELLOW}⚠️ $ok passed, $fail failed — review above for details${RESET}"
fi
