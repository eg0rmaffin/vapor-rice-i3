#!/bin/bash
# ─────────────────────────────────────────────
# Clean Mic Status Diagnostic
#
# Quick diagnostic for Clean Mic microphone enhancement.
# Shows whether Clean Mic is:
#   1. Plugin installed (RNNoise LADSPA)
#   2. Service running (systemd)
#   3. Filter-chain active (PipeWire node exists)
#   4. Set as default source
#
# Usage:
#   clean-mic-status.sh           # Full diagnostic
#   clean-mic-status.sh --quiet   # Exit code only (0=working, 1=not working)
#
# Exit codes:
#   0 = Clean Mic is working and active
#   1 = Clean Mic not working (see output for reason)
#
# Dependencies: systemctl, wpctl
# ─────────────────────────────────────────────

set -e

GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
RESET="\033[0m"

QUIET=0
if [[ "$1" == "--quiet" ]]; then
    QUIET=1
fi

log() {
    if [[ "$QUIET" -eq 0 ]]; then
        echo -e "$1"
    fi
}

ok() {
    log "  ${GREEN}✅ $1${RESET}"
}

warn() {
    log "  ${YELLOW}⚠️  $1${RESET}"
}

fail() {
    log "  ${RED}❌ $1${RESET}"
}

# ─── Check 1: RNNoise plugin installed ───
check_plugin() {
    if [ -f /usr/lib/ladspa/librnnoise_ladspa.so ] || \
       [ -f /usr/lib64/ladspa/librnnoise_ladspa.so ]; then
        ok "RNNoise plugin installed"
        return 0
    else
        fail "RNNoise plugin NOT installed"
        log ""
        log "  ${YELLOW}To install:${RESET}"
        log "    sudo pacman -Syu && sudo pacman -S noise-suppression-for-voice"
        return 1
    fi
}

# ─── Check 2: Config file deployed ───
check_config() {
    local config_file="$HOME/.config/pipewire/clean-mic-filter-chain.conf"
    if [ -f "$config_file" ]; then
        ok "Config file deployed: $config_file"
        return 0
    else
        fail "Config file NOT found: $config_file"
        log ""
        log "  ${YELLOW}To deploy:${RESET}"
        log "    Run install.sh or copy from ~/dotfiles/pipewire/"
        return 1
    fi
}

# ─── Check 3: systemd service status ───
check_service() {
    # Check if service exists
    if ! systemctl --user cat pipewire-clean-mic.service &>/dev/null; then
        warn "Service not installed (pipewire-clean-mic.service)"
        log ""
        log "  ${YELLOW}To install:${RESET}"
        log "    Run install.sh or:"
        log "    ln -sf ~/dotfiles/systemd/pipewire-clean-mic.service ~/.config/systemd/user/"
        log "    systemctl --user daemon-reload"
        log "    systemctl --user enable pipewire-clean-mic.service"
        return 1
    fi

    # Check if service is running
    if systemctl --user is-active pipewire-clean-mic.service &>/dev/null; then
        ok "Service running: pipewire-clean-mic.service"
        return 0
    else
        local status
        status=$(systemctl --user is-active pipewire-clean-mic.service 2>/dev/null || true)
        if [ "$status" = "failed" ]; then
            fail "Service FAILED: pipewire-clean-mic.service"
            log ""
            log "  ${YELLOW}To diagnose:${RESET}"
            log "    journalctl --user -u pipewire-clean-mic.service -n 20"
            log ""
            log "  ${YELLOW}Common causes:${RESET}"
            log "    - RNNoise plugin not installed"
            log "    - PipeWire not running"
            log "    - Config file syntax error"
        else
            warn "Service not running (status: $status)"
            log ""
            log "  ${YELLOW}To start:${RESET}"
            log "    systemctl --user start pipewire-clean-mic.service"
        fi
        return 1
    fi
}

# ─── Check 4: Filter-chain node exists in PipeWire ───
check_node() {
    if ! command -v wpctl &>/dev/null; then
        warn "wpctl not found — cannot check PipeWire nodes"
        return 1
    fi

    local clean_mic_found
    clean_mic_found=$(wpctl status 2>/dev/null | grep -c "clean_mic" || true)
    if [ "$clean_mic_found" -gt 0 ]; then
        ok "Clean Mic node exists in PipeWire"
        return 0
    else
        fail "Clean Mic node NOT found in PipeWire"
        log ""
        log "  ${YELLOW}Possible causes:${RESET}"
        log "    - Service not running (check above)"
        log "    - Filter-chain failed to initialize"
        log "    - PipeWire restarted without Clean Mic service"
        return 1
    fi
}

# ─── Check 5: Clean Mic is default source ───
check_default() {
    if ! command -v wpctl &>/dev/null; then
        return 1
    fi

    local clean_mic_id default_id
    clean_mic_id=$(wpctl status 2>/dev/null | grep -i "clean_mic" | grep -v "capture" | grep -o '[0-9]*' | head -1)
    default_id=$(wpctl inspect @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | grep -o 'id [0-9]*' | grep -o '[0-9]*' | head -1)

    if [ -n "$default_id" ] && [ -n "$clean_mic_id" ] && [ "$default_id" = "$clean_mic_id" ]; then
        ok "Clean Mic is default source (id=$clean_mic_id)"
        return 0
    else
        warn "Clean Mic is NOT default source"
        if [ -n "$clean_mic_id" ]; then
            log ""
            log "  ${YELLOW}To set as default:${RESET}"
            log "    wpctl set-default $clean_mic_id"
        fi
        return 1
    fi
}

# ─── Main ───
log "${CYAN}🎙 Clean Mic Status${RESET}"
log ""

all_ok=1

log "${CYAN}1. Plugin:${RESET}"
check_plugin || all_ok=0
log ""

log "${CYAN}2. Config:${RESET}"
check_config || all_ok=0
log ""

log "${CYAN}3. Service:${RESET}"
check_service || all_ok=0
log ""

log "${CYAN}4. PipeWire node:${RESET}"
check_node || all_ok=0
log ""

log "${CYAN}5. Default source:${RESET}"
check_default || true  # Default source is nice-to-have, not critical
log ""

# ─── Summary ───
log "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
if [ "$all_ok" -eq 1 ]; then
    log "${GREEN}✅ Clean Mic is ACTIVE and working${RESET}"
    exit 0
else
    log "${YELLOW}⚠️  Clean Mic is NOT fully working — see above for details${RESET}"
    exit 1
fi
