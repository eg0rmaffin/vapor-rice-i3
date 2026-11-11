#!/bin/bash
# ─────────────────────────────────────────────
# Audio Policy Diagnostic
#    Verifies that the deterministic audio policy is correctly deployed.
#
#    Usage: audio-policy-check.sh
#
#    Checks:
#      1. PipeWire virtual sink config deployed
#      2. WirePlumber config files deployed
#      3. PipeWire + WirePlumber services running
#      4. Virtual Output sink exists and is default
#      5. WirePlumber stream/BT policy settings
#      6. Physical ALSA sinks at 100% volume
#      7. Current audio device status
#
#    Dependencies: wireplumber, wpctl, pipewire
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

PW_DIR="$HOME/.config/pipewire/pipewire.conf.d"
WP_DIR="$HOME/.config/wireplumber/wireplumber.conf.d"

check "Virtual sink (pipewire: 50-virtual-sink.conf)" \
    "$([ -f "$PW_DIR/50-virtual-sink.conf" ] && echo true || echo false)"

check "Bluetooth policy (wireplumber: 51-audio-policy-bluetooth.conf)" \
    "$([ -f "$WP_DIR/51-audio-policy-bluetooth.conf" ] && echo true || echo false)"

check "Stream policy (wireplumber: 52-audio-policy-streams.conf)" \
    "$([ -f "$WP_DIR/52-audio-policy-streams.conf" ] && echo true || echo false)"

check "ALSA policy (wireplumber: 53-audio-policy-alsa.conf)" \
    "$([ -f "$WP_DIR/53-audio-policy-alsa.conf" ] && echo true || echo false)"

check "Mic policy (wireplumber: 54-audio-policy-mic.conf)" \
    "$([ -f "$WP_DIR/54-audio-policy-mic.conf" ] && echo true || echo false)"

check "Clean Mic (pipewire: 60-clean-mic.conf)" \
    "$([ -f "$PW_DIR/60-clean-mic.conf" ] && echo true || echo false)"

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

# ─── 3. Virtual Output sink ───
echo -e "${CYAN}🔊 Virtual Output sink:${RESET}"
if command -v wpctl &>/dev/null; then
    # Check if virtual_output_sink exists anywhere in the audio graph.
    # Note: loopback nodes appear under "Filters" (not "Sinks") because
    # PipeWire automatically sets node.link-group on loopback modules.
    # This is expected and does not affect functionality.
    virtual_found=$(wpctl status 2>/dev/null | grep -c "virtual_output_sink" || true)
    check "Virtual Output sink exists" \
        "$([ "$virtual_found" -gt 0 ] && echo true || echo false)"

    # Check if it is the default sink (marked with * in wpctl status).
    # The * can appear in both the Sinks and Filters sections — both are valid.
    default_virtual=$(wpctl status 2>/dev/null | grep -E '^\s*\*.*virtual_output_sink' || true)
    if [ -n "$default_virtual" ]; then
        check "Virtual Output is default sink" "true"
    else
        # Also check via wpctl inspect: get the default sink ID and compare
        default_id=$(wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null | grep -o 'id [0-9]*' | grep -o '[0-9]*' | head -1)
        virtual_id=$(wpctl status 2>/dev/null | grep -i "virtual_output_sink" | grep -o '[0-9]*' | head -1)
        if [ -n "$default_id" ] && [ -n "$virtual_id" ] && [ "$default_id" = "$virtual_id" ]; then
            check "Virtual Output is default sink" "true"
        else
            check "Virtual Output is default sink" "false"
            echo -e "  ${YELLOW}  Hint: run 'wpctl set-default <id>' where <id> is the Virtual Output node ID${RESET}"
        fi
    fi
else
    echo -e "  ${YELLOW}⚠️ wpctl not found${RESET}"
fi

echo ""

# ─── 4. WirePlumber settings verification ───
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

# ─── 5. Physical sink volume ───
echo -e "${CYAN}🔊 Physical ALSA sink volume:${RESET}"
if command -v pactl &>/dev/null; then
    # Read ALSA sinks into array to avoid subshell (preserves ok/fail counters)
    alsa_sinks=()
    while read -r _ sink_name _; do
        case "$sink_name" in alsa_output.*) alsa_sinks+=("$sink_name") ;; esac
    done < <(pactl list sinks short 2>/dev/null)

    for sink_name in "${alsa_sinks[@]}"; do
        vol=$(pactl get-sink-volume "$sink_name" 2>/dev/null | grep -o '[0-9]*%' | head -1)
        mute=$(LC_ALL=C pactl get-sink-mute "$sink_name" 2>/dev/null | grep -o 'yes\|no')
        if [ "$vol" = "100%" ] && [ "$mute" = "no" ]; then
            check "$sink_name at $vol (mute=$mute)" "true"
        else
            check "$sink_name at ${vol:-?} (mute=${mute:-?}) — should be 100%" "false"
            echo -e "  ${YELLOW}  Hint: run 'pactl set-sink-volume $sink_name 100%'${RESET}"
        fi
    done

    if [ ${#alsa_sinks[@]} -eq 0 ]; then
        echo -e "  ${YELLOW}⚠️ No physical ALSA sinks found${RESET}"
    fi
else
    echo -e "  ${YELLOW}⚠️ pactl not found${RESET}"
fi

echo ""

# ─── 6. Clean Mic (microphone enhancement) ───
echo -e "${CYAN}🎙 Clean Mic (optional microphone enhancement):${RESET}"

# Check if RNNoise LADSPA plugin is installed
rnnoise_ok="false"

# Check RNNoise plugin
if [ -f /usr/lib/ladspa/librnnoise_ladspa.so ] || [ -f /usr/lib64/ladspa/librnnoise_ladspa.so ]; then
    rnnoise_ok="true"
fi
check "RNNoise plugin installed" "$rnnoise_ok"

# Check Clean Mic systemd service (NEW: systemd-based approach)
# This is more reliable than context.modules drop-ins which can silently fail
if systemctl --user cat pipewire-clean-mic.service &>/dev/null; then
    check "Clean Mic service installed" "true"

    # Check if service is running
    if systemctl --user is-active pipewire-clean-mic.service &>/dev/null; then
        check "Clean Mic service running" "true"
    else
        service_status=$(systemctl --user is-active pipewire-clean-mic.service 2>/dev/null || true)
        if [ "$service_status" = "failed" ]; then
            check "Clean Mic service running" "false"
            echo -e "  ${YELLOW}  Service failed! Check: journalctl --user -u pipewire-clean-mic.service${RESET}"
        else
            check "Clean Mic service running" "false"
            echo -e "  ${YELLOW}  Hint: systemctl --user start pipewire-clean-mic.service${RESET}"
        fi
    fi
else
    check "Clean Mic service installed" "false"
    echo -e "  ${YELLOW}  Run install.sh to set up the Clean Mic service${RESET}"
fi

# Check if Clean Mic node exists in PipeWire
if command -v wpctl &>/dev/null; then
    clean_mic_found=$(wpctl status 2>/dev/null | grep -c "clean_mic" || true)
    if [ "$clean_mic_found" -gt 0 ]; then
        check "Clean Mic node in PipeWire" "true"

        # Check if Clean Mic is the default source
        clean_mic_id=$(wpctl status 2>/dev/null | grep -i "clean_mic" | grep -v "capture" | grep -o '[0-9]*' | head -1)
        default_source_id=$(wpctl inspect @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | grep -o 'id [0-9]*' | grep -o '[0-9]*' | head -1)
        if [ -n "$default_source_id" ] && [ -n "$clean_mic_id" ] && [ "$default_source_id" = "$clean_mic_id" ]; then
            check "Clean Mic is default source" "true"
        else
            check "Clean Mic is default source" "false"
            echo -e "  ${YELLOW}  Hint: run 'wpctl set-default $clean_mic_id'${RESET}"
        fi
    else
        if [ "$rnnoise_ok" = "true" ]; then
            echo -e "  ${YELLOW}⚠️ Clean Mic node not found (service may have failed)${RESET}"
            echo -e "  ${YELLOW}  Check: journalctl --user -u pipewire-clean-mic.service${RESET}"
        else
            echo -e "  ${YELLOW}⚠️ Clean Mic not active (missing RNNoise plugin)${RESET}"
            echo -e "  ${YELLOW}  This is NORMAL if plugin failed to install due to dependency conflicts.${RESET}"
            echo -e "  ${YELLOW}  Audio baseline still works. To enable Clean Mic later:${RESET}"
            echo -e "  ${YELLOW}    sudo pacman -Syu && sudo pacman -S noise-suppression-for-voice${RESET}"
        fi
    fi
else
    echo -e "  ${YELLOW}⚠️ wpctl not found${RESET}"
fi

# Additional hint for detailed Clean Mic diagnostics
echo -e "  ${CYAN}ℹ️  For detailed Clean Mic diagnostics: clean-mic-status.sh${RESET}"

echo ""

# ─── 7. Audio device status ───
echo -e "${CYAN}🔊 Current audio devices:${RESET}"
if command -v wpctl &>/dev/null; then
    wpctl status 2>/dev/null | head -40
else
    echo -e "  ${YELLOW}⚠️ wpctl not found${RESET}"
fi

echo ""

# ─── 8. Architecture diagram ───
echo -e "${CYAN}📐 Expected audio architecture:${RESET}"
echo ""
echo -e "  ${CYAN}Output (always active):${RESET}"
echo "  App streams → [Virtual Output sink] → loopback → [physical device]"
echo "  When BT connects:  loopback moves to BT   (apps unaffected)"
echo "  When BT disconnects: loopback moves back   (apps unaffected)"
echo ""
echo -e "  ${CYAN}Input (optional Clean Mic enhancement):${RESET}"
echo "  [Hardware Mic] → RNNoise → [Clean Mic] ← App input streams"
echo "  When mic hotplug: filter-chain rebinds to new hardware automatically"
echo "  If RNNoise missing: Clean Mic not available, raw hardware mic is used"
echo ""

# ─── Summary ───
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
if [ "$fail" -eq 0 ]; then
    echo -e "${GREEN}✅ All $ok checks passed — audio policy is active${RESET}"
else
    echo -e "${YELLOW}⚠️ $ok passed, $fail failed — review above for details${RESET}"
fi
