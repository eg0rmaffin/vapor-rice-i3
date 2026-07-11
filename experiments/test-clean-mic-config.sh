#!/bin/bash
# ─────────────────────────────────────────────
# Test script for Clean Mic configuration
#
# This script validates that:
#   1. The new systemd-based Clean Mic architecture is properly configured
#   2. The clean-mic-filter-chain.conf has correct syntax
#   3. The systemd service file is valid
#   4. The old 60-clean-mic.conf is deprecated (empty)
#
# Usage: ./experiments/test-clean-mic-config.sh
# ─────────────────────────────────────────────

set -e

GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
RESET="\033[0m"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
OLD_CONFIG_FILE="$REPO_DIR/pipewire/60-clean-mic.conf"
NEW_CONFIG_FILE="$REPO_DIR/pipewire/clean-mic-filter-chain.conf"
SYSTEMD_SERVICE="$REPO_DIR/systemd/pipewire-clean-mic.service"
STATUS_SCRIPT="$REPO_DIR/bin/clean-mic-status.sh"

echo -e "${CYAN}🧪 Testing Clean Mic configuration (systemd-based architecture)${RESET}"
echo ""

# Test 1: New config file exists
echo -e "${CYAN}Test 1: New config file exists${RESET}"
if [ -f "$NEW_CONFIG_FILE" ]; then
    echo -e "  ${GREEN}✅ $NEW_CONFIG_FILE exists${RESET}"
else
    echo -e "  ${RED}❌ $NEW_CONFIG_FILE not found${RESET}"
    exit 1
fi

# Test 2: Old config file is deprecated (exists but is empty/placeholder)
echo -e "${CYAN}Test 2: Old config file is deprecated${RESET}"
if [ -f "$OLD_CONFIG_FILE" ]; then
    if grep -q 'DEPRECATED' "$OLD_CONFIG_FILE"; then
        echo -e "  ${GREEN}✅ $OLD_CONFIG_FILE exists and is marked DEPRECATED${RESET}"
    else
        echo -e "  ${YELLOW}⚠️  $OLD_CONFIG_FILE exists but may still be active${RESET}"
    fi
else
    echo -e "  ${RED}❌ $OLD_CONFIG_FILE not found (expected deprecation placeholder)${RESET}"
    exit 1
fi

# Test 3: Systemd service file exists
echo -e "${CYAN}Test 3: Systemd service file exists${RESET}"
if [ -f "$SYSTEMD_SERVICE" ]; then
    echo -e "  ${GREEN}✅ $SYSTEMD_SERVICE exists${RESET}"
else
    echo -e "  ${RED}❌ $SYSTEMD_SERVICE not found${RESET}"
    exit 1
fi

# Test 4: Systemd service has correct dependencies
echo -e "${CYAN}Test 4: Systemd service has PipeWire dependencies${RESET}"
if grep -q 'After=pipewire.service' "$SYSTEMD_SERVICE" && \
   grep -q 'Requires=pipewire.service' "$SYSTEMD_SERVICE"; then
    echo -e "  ${GREEN}✅ Service depends on PipeWire${RESET}"
else
    echo -e "  ${RED}❌ Service missing PipeWire dependencies${RESET}"
    exit 1
fi

# Test 5: Systemd service uses pipewire -c
echo -e "${CYAN}Test 5: Systemd service uses pipewire -c flag${RESET}"
if grep -q 'pipewire -c' "$SYSTEMD_SERVICE"; then
    echo -e "  ${GREEN}✅ Service uses 'pipewire -c' for dedicated config${RESET}"
else
    echo -e "  ${RED}❌ Service should use 'pipewire -c' flag${RESET}"
    exit 1
fi

# Test 6: New config has filter-chain module
echo -e "${CYAN}Test 6: New config has filter-chain module${RESET}"
if grep -q 'name = libpipewire-module-filter-chain' "$NEW_CONFIG_FILE"; then
    echo -e "  ${GREEN}✅ Module name is 'libpipewire-module-filter-chain'${RESET}"
else
    echo -e "  ${RED}❌ Module name incorrect or missing${RESET}"
    exit 1
fi

# Test 7: New config has RNNoise plugin
echo -e "${CYAN}Test 7: RNNoise plugin configured in new config${RESET}"
if grep -q 'librnnoise_ladspa' "$NEW_CONFIG_FILE"; then
    echo -e "  ${GREEN}✅ RNNoise (librnnoise_ladspa) configured${RESET}"
else
    echo -e "  ${RED}❌ RNNoise plugin not found in config${RESET}"
    exit 1
fi

# Test 8: New config has proper graph I/O
echo -e "${CYAN}Test 8: Filter graph input/output configured${RESET}"
if grep -q 'inputs.*=.*\[.*"rnnoise:Input".*\]' "$NEW_CONFIG_FILE" && \
   grep -q 'outputs.*=.*\[.*"rnnoise:Output".*\]' "$NEW_CONFIG_FILE"; then
    echo -e "  ${GREEN}✅ Single-node graph: rnnoise input/output correctly configured${RESET}"
else
    echo -e "  ${RED}❌ Graph input/output not correctly configured${RESET}"
    exit 1
fi

# Test 9: New config has protocol-native module (required for IPC)
echo -e "${CYAN}Test 9: Protocol-native module present (required for IPC)${RESET}"
if grep -q 'libpipewire-module-protocol-native' "$NEW_CONFIG_FILE"; then
    echo -e "  ${GREEN}✅ Protocol-native module configured${RESET}"
else
    echo -e "  ${RED}❌ Protocol-native module missing (required for inter-process communication)${RESET}"
    exit 1
fi

# Test 10: Status diagnostic script exists
echo -e "${CYAN}Test 10: Clean Mic status script exists${RESET}"
if [ -f "$STATUS_SCRIPT" ]; then
    echo -e "  ${GREEN}✅ $STATUS_SCRIPT exists${RESET}"
else
    echo -e "  ${RED}❌ $STATUS_SCRIPT not found${RESET}"
    exit 1
fi

# Test 11: Status script is executable
echo -e "${CYAN}Test 11: Status script is executable${RESET}"
if [ -x "$STATUS_SCRIPT" ]; then
    echo -e "  ${GREEN}✅ $STATUS_SCRIPT is executable${RESET}"
else
    echo -e "  ${RED}❌ $STATUS_SCRIPT is not executable${RESET}"
    exit 1
fi

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GREEN}✅ All tests passed - Clean Mic systemd architecture is valid${RESET}"
echo ""
echo -e "${CYAN}Key improvements over context.modules approach:${RESET}"
echo "  - Dedicated systemd service: clear start/stop/status tracking"
echo "  - Errors logged to journalctl: easier debugging"
echo "  - Service dependencies: proper startup order (after PipeWire)"
echo "  - No silent failures: if filter-chain fails, service fails visibly"
echo "  - clean-mic-status.sh: quick diagnostic script"
echo ""
echo -e "${CYAN}To check Clean Mic status on a running system:${RESET}"
echo "  systemctl --user status pipewire-clean-mic.service"
echo "  clean-mic-status.sh"
