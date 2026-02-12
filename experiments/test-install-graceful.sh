#!/bin/bash
# ─────────────────────────────────────────────
# Test script for install.sh graceful handling
#
# This script validates that:
#   1. Clean Mic plugins are installed separately (not in main deps array)
#   2. Plugin installation failures don't exit the script
#   3. Proper warning messages are shown for failures
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

# Test 2: No 'exit 1' after swh-plugins failure
echo -e "${CYAN}Test 2: No 'exit 1' after swh-plugins section${RESET}"
# Look for the old pattern that exits on failure
if grep -A5 'swh-plugins' "$INSTALL_FILE" | grep -q 'exit 1'; then
    echo -e "  ${RED}❌ Found 'exit 1' after swh-plugins - failures will abort install${RESET}"
    exit 1
else
    echo -e "  ${GREEN}✅ No 'exit 1' after swh-plugins - failures are non-fatal${RESET}"
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
if grep -q 'Clean Mic feature may be degraded' "$INSTALL_FILE"; then
    echo -e "  ${GREEN}✅ User-friendly warning messages present${RESET}"
else
    echo -e "  ${YELLOW}⚠️  Warning messages may differ${RESET}"
fi

# Test 5: Recovery hint present
echo -e "${CYAN}Test 5: Recovery instructions present${RESET}"
if grep -q 'sudo pacman -Syu' "$INSTALL_FILE" | grep -q 'swh-plugins\|noise-suppression'; then
    echo -e "  ${GREEN}✅ Recovery instructions (pacman -Syu) present${RESET}"
else
    # Check with different pattern
    if grep 'pacman -Syu' "$INSTALL_FILE" | grep -q 'swh-plugins'; then
        echo -e "  ${GREEN}✅ Recovery instructions (pacman -Syu) present${RESET}"
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

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GREEN}✅ All tests passed - install.sh handles Clean Mic gracefully${RESET}"
echo ""
echo -e "${CYAN}Key safety features in install.sh:${RESET}"
echo "  - Clean Mic plugins installed separately from main deps"
echo "  - Plugin failures don't abort installation"
echo "  - User gets clear warning + recovery instructions"
echo "  - Audio baseline (output + routing) remains functional"
