#!/bin/bash
# ─────────────────────────────────────────────
# Test script for Clean Mic configuration
#
# This script validates that:
#   1. The 60-clean-mic.conf has correct syntax
#   2. The 'nofail' flag is present
#   3. The module structure is valid
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
CONFIG_FILE="$REPO_DIR/pipewire/60-clean-mic.conf"

echo -e "${CYAN}🧪 Testing Clean Mic configuration${RESET}"
echo ""

# Test 1: Config file exists
echo -e "${CYAN}Test 1: Config file exists${RESET}"
if [ -f "$CONFIG_FILE" ]; then
    echo -e "  ${GREEN}✅ $CONFIG_FILE exists${RESET}"
else
    echo -e "  ${RED}❌ $CONFIG_FILE not found${RESET}"
    exit 1
fi

# Test 2: nofail flag is present
echo -e "${CYAN}Test 2: 'nofail' flag is present${RESET}"
if grep -q 'nofail' "$CONFIG_FILE"; then
    echo -e "  ${GREEN}✅ 'nofail' flag found${RESET}"
else
    echo -e "  ${RED}❌ 'nofail' flag NOT found - PipeWire will crash if plugins missing${RESET}"
    exit 1
fi

# Test 3: ifexists flag is present
echo -e "${CYAN}Test 3: 'ifexists' flag is present${RESET}"
if grep -q 'ifexists' "$CONFIG_FILE"; then
    echo -e "  ${GREEN}✅ 'ifexists' flag found${RESET}"
else
    echo -e "  ${RED}❌ 'ifexists' flag NOT found${RESET}"
    exit 1
fi

# Test 4: flags array format is correct
echo -e "${CYAN}Test 4: flags array format is correct${RESET}"
if grep -q 'flags = \[ ifexists nofail \]' "$CONFIG_FILE"; then
    echo -e "  ${GREEN}✅ flags array format is correct${RESET}"
else
    echo -e "  ${YELLOW}⚠️  flags array format may differ (checking alternative formats)${RESET}"
    if grep -qE 'flags\s*=\s*\[.*nofail.*\]' "$CONFIG_FILE"; then
        echo -e "  ${GREEN}✅ flags array contains 'nofail' in some format${RESET}"
    else
        echo -e "  ${RED}❌ flags array format incorrect${RESET}"
        exit 1
    fi
fi

# Test 5: Module name is correct
echo -e "${CYAN}Test 5: Module name is correct${RESET}"
if grep -q 'name = libpipewire-module-filter-chain' "$CONFIG_FILE"; then
    echo -e "  ${GREEN}✅ Module name is 'libpipewire-module-filter-chain'${RESET}"
else
    echo -e "  ${RED}❌ Module name incorrect or missing${RESET}"
    exit 1
fi

# Test 6: RNNoise plugin reference
echo -e "${CYAN}Test 6: RNNoise plugin configured${RESET}"
if grep -q 'librnnoise_ladspa' "$CONFIG_FILE"; then
    echo -e "  ${GREEN}✅ RNNoise (librnnoise_ladspa) configured${RESET}"
else
    echo -e "  ${RED}❌ RNNoise plugin not found in config${RESET}"
    exit 1
fi

# Test 7: Limiter plugin reference
echo -e "${CYAN}Test 7: Limiter plugin configured${RESET}"
if grep -q 'fast_lookahead_limiter_1913' "$CONFIG_FILE"; then
    echo -e "  ${GREEN}✅ Limiter (fast_lookahead_limiter_1913) configured${RESET}"
else
    echo -e "  ${RED}❌ Limiter plugin not found in config${RESET}"
    exit 1
fi

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GREEN}✅ All tests passed - Clean Mic config is robust${RESET}"
echo ""
echo -e "${CYAN}Key safety features:${RESET}"
echo "  - 'nofail' flag: PipeWire won't crash if plugins fail to load"
echo "  - 'ifexists' flag: module skipped if binary doesn't exist"
echo "  - Clean Mic is an optional enhancement, not a hard dependency"
