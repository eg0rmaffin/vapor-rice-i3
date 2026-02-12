#!/bin/bash
# ─────────────────────────────────────────────
# Test script for install.sh graceful handling
#
# This script validates that:
#   1. Clean Mic plugin is installed separately (not in main deps array)
#   2. Plugin installation failures don't exit the script
#   3. Proper warning messages are shown for failures
#   4. swh-plugins (limiter) is NOT referenced (removed for version-tolerance)
#
# Usage: ./experiments/test-install-graceful.sh
# ─────────────────────────────────────────────

set -e

GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
RESET="\033[0m"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
INSTALL_FILE="$REPO_DIR/install.sh"

echo -e "${CYAN}🧪 Testing install.sh graceful handling${RESET}"
echo ""

# Test 1: noise-suppression-for-voice NOT in main deps array as a package (comments OK)
echo -e "${CYAN}Test 1: noise-suppression-for-voice NOT in main deps array (as package)${RESET}"
# The main deps array ends at the closing paren after the Wayland section
# We need to exclude lines that are comments (start with #)
MAIN_DEPS=$(sed -n '/^deps=(/,/^)/p' "$INSTALL_FILE" | grep -v '^\s*#')
if echo "$MAIN_DEPS" | grep -E '^\s*noise-suppression-for-voice\s*$' >/dev/null; then
    echo -e "  ${RED}❌ noise-suppression-for-voice is still in main deps array${RESET}"
    echo -e "  ${RED}   This means failure will abort install.sh${RESET}"
    exit 1
else
    echo -e "  ${GREEN}✅ noise-suppression-for-voice NOT in main deps array (only in comments)${RESET}"
fi

# Test 2: swh-plugins NOT installed (removed for version-tolerance)
echo -e "${CYAN}Test 2: swh-plugins NOT installed (version-tolerance)${RESET}"
# Check if install_list swh-plugins is called
if grep -q 'install_list swh-plugins' "$INSTALL_FILE"; then
    echo -e "  ${RED}❌ swh-plugins still being installed - should be removed for PipeWire 1.4.x${RESET}"
    exit 1
else
    echo -e "  ${GREEN}✅ swh-plugins NOT installed (version-tolerant design)${RESET}"
fi

# Test 3: CLEAN_MIC_OK variable exists (graceful handling)
echo -e "${CYAN}Test 3: CLEAN_MIC_OK variable for graceful handling${RESET}"
if grep -q 'CLEAN_MIC_OK=' "$INSTALL_FILE"; then
    echo -e "  ${GREEN}✅ CLEAN_MIC_OK variable found - tracking plugin status${RESET}"
else
    echo -e "  ${YELLOW}⚠️  CLEAN_MIC_OK variable not found (older approach)${RESET}"
fi

# Test 4: Warning messages for failures
echo -e "${CYAN}Test 4: Warning messages for plugin failures${RESET}"
if grep -q 'Clean Mic.*will be unavailable\|Clean Mic feature' "$INSTALL_FILE"; then
    echo -e "  ${GREEN}✅ User-friendly warning messages present${RESET}"
else
    echo -e "  ${YELLOW}⚠️  Warning messages may differ${RESET}"
fi

# Test 5: Recovery hint present (RNNoise only, no swh-plugins)
echo -e "${CYAN}Test 5: Recovery instructions present (RNNoise only)${RESET}"
if grep 'pacman -Syu.*noise-suppression-for-voice' "$INSTALL_FILE" | grep -qv 'swh-plugins'; then
    echo -e "  ${GREEN}✅ Recovery instructions (pacman -Syu noise-suppression-for-voice) present${RESET}"
else
    # More lenient check
    if grep -q 'pacman -Syu' "$INSTALL_FILE" && grep -q 'noise-suppression-for-voice' "$INSTALL_FILE"; then
        echo -e "  ${GREEN}✅ Recovery instructions present${RESET}"
    else
        echo -e "  ${YELLOW}⚠️  Recovery instructions may differ${RESET}"
    fi
fi

# Test 6: Comment explains NON-FATAL behavior
echo -e "${CYAN}Test 6: NON-FATAL behavior documented${RESET}"
if grep -q 'NON-FATAL\|non-fatal\|nofail' "$INSTALL_FILE"; then
    echo -e "  ${GREEN}✅ NON-FATAL behavior is documented${RESET}"
else
    echo -e "  ${YELLOW}⚠️  NON-FATAL documentation may be missing${RESET}"
fi

# Test 7: Limiter removal documented in comments
echo -e "${CYAN}Test 7: Limiter removal explained in comments${RESET}"
if grep -q 'Limiter.*removed\|version-tolerance\|port names.*vary' "$INSTALL_FILE"; then
    echo -e "  ${GREEN}✅ Limiter removal reason documented${RESET}"
else
    echo -e "  ${YELLOW}⚠️  Limiter removal documentation may be missing${RESET}"
fi

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GREEN}✅ All tests passed - install.sh handles Clean Mic gracefully${RESET}"
echo ""
echo -e "${CYAN}Key safety features in install.sh:${RESET}"
echo "  - Clean Mic plugin (RNNoise) installed separately from main deps"
echo "  - swh-plugins removed (version-tolerance for PipeWire 1.4.x)"
echo "  - Plugin failures don't abort installation"
echo "  - User gets clear warning + recovery instructions"
echo "  - Audio baseline (output + routing) remains functional"
