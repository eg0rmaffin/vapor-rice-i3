#!/bin/bash
# ─────────────────────────────────────────────
# Audio Policy Setup
#    Deploys deterministic WirePlumber + PipeWire audio policy.
#    Called from install.sh after PipeWire services are enabled.
#
#    Policy goals (Windows-like):
#      - One persistent virtual output sink (always exists)
#      - One persistent virtual input source "Clean Mic" (noise-suppressed)
#      - Applications connect to virtual devices, never to physical hardware
#      - Physical devices attach/detach underneath via loopback/filter-chain
#      - Bluetooth: A2DP only, no HSP/HFP profile switching
#      - Microphone does NOT degrade output quality
#      - No auto-mute/cork on device hot-plug
#      - Device hot-plug = redirect automatically
#
#    Output architecture:
#      App streams → [Virtual Output sink] → loopback → [physical device]
#      When BT connects:  loopback moves to BT   (apps unaffected)
#      When BT disconnects: loopback moves back   (apps unaffected)
#
#    Input architecture (Clean Mic):
#      [Hardware Mic] → RNNoise → Limiter → [Clean Mic source]
#                                                  ↑
#                                          Apps connect here
#      - Noise suppression via RNNoise (removes background noise)
#      - Limiter prevents clipping (loud sounds capped at -3dB)
#      - Hardware-agnostic: works with any mic (built-in, USB, Bluetooth)
#      - Hotplug-safe: filter-chain follows default source automatically
#
#    IMPORTANT: This script NEVER restarts PipeWire.
#      Restarting PipeWire kills the PulseAudio socket, which permanently
#      breaks audio in applications that don't implement reconnection
#      (Minecraft/Java, Telegram Desktop, Electron apps, many games).
#      Config files are deployed as symlinks and take effect on next
#      session start or after a WirePlumber-only restart.
#
#    Volume policy:
#      Physical (ALSA) devices always at 100% volume.
#      Virtual sink is the single user-facing volume control.
#      This avoids double-attenuation (virtual × physical) that makes
#      speakers sound too quiet even at 100% virtual sink volume.
#
#    Dependencies: wireplumber, pipewire, pipewire-pulse,
#                  noise-suppression-for-voice (optional, for Clean Mic)
# ─────────────────────────────────────────────

setup_audio_policy() {
    echo -e "${CYAN}🎧 Deploying deterministic audio policy...${RESET}"

    # ─── PipeWire virtual sink config ───
    local pw_conf_dir="$HOME/.config/pipewire/pipewire.conf.d"
    mkdir -p "$pw_conf_dir"

    # Deploy all PipeWire configs (including Clean Mic with full pipeline)
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

    # ─── Apply WirePlumber policy without killing PipeWire ───
    # NEVER restart PipeWire — it destroys PulseAudio connections for
    # running apps (Minecraft, Telegram, games lose audio permanently).
    # Only restart WirePlumber, which re-reads its configs while PipeWire
    # and all application connections stay intact.
    if systemctl --user is-active wireplumber.service &>/dev/null; then
        echo -e "${CYAN}  🔄 Restarting WirePlumber to apply policy (PipeWire untouched)...${RESET}"
        systemctl --user restart wireplumber.service 2>/dev/null || true
        sleep 1
        echo -e "  ${GREEN}✅ WirePlumber restarted${RESET}"
    fi

    # ─── Check if Virtual Output sink is already available ───
    # The virtual sink is loaded by PipeWire (not WirePlumber), so it
    # only appears after PipeWire reads 50-virtual-sink.conf.
    # On first install this won't exist yet — it will appear on next login.
    if command -v wpctl &>/dev/null; then
        local virtual_id
        virtual_id=$(wpctl status 2>/dev/null | grep -i "virtual_output_sink" | grep -o '[0-9]*' | head -1)
        if [ -n "$virtual_id" ]; then
            wpctl set-default "$virtual_id" 2>/dev/null || true
            echo -e "  ${GREEN}✅ Virtual Output set as default sink (id=$virtual_id)${RESET}"
        else
            echo -e "  ${YELLOW}⚠️ Virtual Output sink not loaded yet (PipeWire configs take effect on next login)${RESET}"
        fi

        # ─── Check if Clean Mic source is already available ───
        # The clean-mic filter-chain is loaded by PipeWire from 60-clean-mic.conf.
        # On first install this won't exist yet — it will appear on next login.
        local clean_mic_id
        clean_mic_id=$(wpctl status 2>/dev/null | grep -i "clean_mic" | grep -v "capture" | grep -o '[0-9]*' | head -1)
        if [ -n "$clean_mic_id" ]; then
            wpctl set-default "$clean_mic_id" 2>/dev/null || true
            echo -e "  ${GREEN}✅ Clean Mic set as default source (id=$clean_mic_id)${RESET}"
        else
            echo -e "  ${YELLOW}⚠️ Clean Mic source not loaded yet (PipeWire configs take effect on next login)${RESET}"
        fi
    fi

    # ─── Set physical ALSA sinks to 100% volume ───
    # Clear any previously saved low volumes. With the virtual sink
    # architecture, physical devices should be at max — the user controls
    # volume through the virtual sink (one knob, Windows-like behavior).
    if command -v pactl &>/dev/null; then
        echo -e "${CYAN}  🔊 Setting physical ALSA sinks to 100% volume...${RESET}"
        pactl list sinks short 2>/dev/null | while read -r _ sink_name _; do
            case "$sink_name" in
                alsa_output.*)
                    pactl set-sink-volume "$sink_name" 100% 2>/dev/null || true
                    pactl set-sink-mute "$sink_name" 0 2>/dev/null || true
                    echo -e "  ${GREEN}✅ $sink_name → 100%${RESET}"
                    ;;
            esac
        done
    fi

    echo -e "${GREEN}✅ Deterministic audio policy deployed${RESET}"
    echo -e "  ${CYAN}ℹ️  PipeWire configs (virtual sink, clean mic) take effect on next login${RESET}"
}
