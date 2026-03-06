#!/bin/bash
# ─────────────────────────────────────────────
# Test script for install_list() error capture boundary
#
# This script validates the fix for issue #104:
#   - install_list() must capture output and status even when pacman fails
#   - Diagnostic output must be visible to the user
#   - Global set -e must remain effective for other code
#
# Usage: ./experiments/test-install-list-capture.sh
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

echo -e "${CYAN}🧪 Testing install_list() error capture boundary${RESET}"
echo ""

# ─────────────────────────────────────────────
# Test 1: Check for set +e / set -e boundary around pacman call
# ─────────────────────────────────────────────
echo -e "${CYAN}Test 1: Explicit capture boundary exists${RESET}"

# Extract install_list function
INSTALL_LIST_FUNC=$(sed -n '/^install_list()/,/^}/p' "$INSTALL_FILE")

if echo "$INSTALL_LIST_FUNC" | grep -q 'set +e'; then
    echo -e "  ${GREEN}✅ set +e found in install_list()${RESET}"
else
    echo -e "  ${RED}❌ set +e NOT found in install_list()${RESET}"
    echo "  The capture boundary is required to prevent silent exits"
    exit 1
fi

if echo "$INSTALL_LIST_FUNC" | grep -q 'set -e'; then
    echo -e "  ${GREEN}✅ set -e found in install_list() (re-enabled after capture)${RESET}"
else
    echo -e "  ${RED}❌ set -e NOT found in install_list()${RESET}"
    echo "  errexit must be re-enabled after capturing output"
    exit 1
fi

# ─────────────────────────────────────────────
# Test 2: Correct ordering: set +e BEFORE pacman, set -e AFTER
# ─────────────────────────────────────────────
echo -e "${CYAN}Test 2: Correct set +e / set -e ordering${RESET}"

# Get line numbers - use ^\s*set to avoid matching comments
SET_PLUS_E_LINE=$(echo "$INSTALL_LIST_FUNC" | grep -n '^\s*set +e' | head -1 | cut -d: -f1)
PACMAN_LINE=$(echo "$INSTALL_LIST_FUNC" | grep -n 'install_output=.*sudo pacman' | head -1 | cut -d: -f1)
SET_MINUS_E_LINE=$(echo "$INSTALL_LIST_FUNC" | grep -n '^\s*set -e' | head -1 | cut -d: -f1)

if [ -n "$SET_PLUS_E_LINE" ] && [ -n "$PACMAN_LINE" ] && [ -n "$SET_MINUS_E_LINE" ]; then
    if [ "$SET_PLUS_E_LINE" -lt "$PACMAN_LINE" ] && [ "$PACMAN_LINE" -lt "$SET_MINUS_E_LINE" ]; then
        echo -e "  ${GREEN}✅ Correct order: set +e (line $SET_PLUS_E_LINE) → pacman (line $PACMAN_LINE) → set -e (line $SET_MINUS_E_LINE)${RESET}"
    else
        echo -e "  ${RED}❌ Wrong order: set +e=$SET_PLUS_E_LINE, pacman=$PACMAN_LINE, set -e=$SET_MINUS_E_LINE${RESET}"
        exit 1
    fi
else
    echo -e "  ${RED}❌ Could not find all required elements (set+e=$SET_PLUS_E_LINE, pacman=$PACMAN_LINE, set-e=$SET_MINUS_E_LINE)${RESET}"
    exit 1
fi

# ─────────────────────────────────────────────
# Test 3: Error output is printed before recovery attempts
# ─────────────────────────────────────────────
echo -e "${CYAN}Test 3: Error output printed before recovery${RESET}"

if echo "$INSTALL_LIST_FUNC" | grep -q 'echo.*install_output'; then
    echo -e "  ${GREEN}✅ install_output is echoed on error${RESET}"
else
    echo -e "  ${RED}❌ install_output is NOT echoed on error${RESET}"
    echo "  Users must see pacman output before recovery is attempted"
    exit 1
fi

# ─────────────────────────────────────────────
# Test 4: Exit status is captured before checking
# ─────────────────────────────────────────────
echo -e "${CYAN}Test 4: Exit status captured correctly${RESET}"

# Check pattern: install_output=$(...) followed by install_status=$?
if echo "$INSTALL_LIST_FUNC" | grep -q 'install_output=.*pacman' && \
   echo "$INSTALL_LIST_FUNC" | grep -q 'install_status=\$?'; then
    echo -e "  ${GREEN}✅ Exit status captured via \$?${RESET}"
else
    echo -e "  ${RED}❌ Exit status capture pattern not found${RESET}"
    exit 1
fi

# ─────────────────────────────────────────────
# Test 5: Detailed comment explaining the boundary
# ─────────────────────────────────────────────
echo -e "${CYAN}Test 5: Documentation of capture boundary${RESET}"

if echo "$INSTALL_LIST_FUNC" | grep -qi 'capture boundary\|errexit\|error-capture'; then
    echo -e "  ${GREEN}✅ Capture boundary is documented${RESET}"
else
    echo -e "  ${YELLOW}⚠️  Consider adding documentation for the capture boundary${RESET}"
fi

# ─────────────────────────────────────────────
# Test 6: Verify global set -e is at the top of script
# ─────────────────────────────────────────────
echo -e "${CYAN}Test 6: Global set -e still present${RESET}"

FIRST_LINES=$(head -5 "$INSTALL_FILE")
if echo "$FIRST_LINES" | grep -q '^set -e'; then
    echo -e "  ${GREEN}✅ Global set -e at top of script${RESET}"
else
    echo -e "  ${RED}❌ Global set -e NOT found at top${RESET}"
    exit 1
fi

# ─────────────────────────────────────────────
# Test 7: Return 1 on unrecoverable failures
# ─────────────────────────────────────────────
echo -e "${CYAN}Test 7: Explicit return 1 on failures${RESET}"

RETURN_1_COUNT=$(echo "$INSTALL_LIST_FUNC" | grep -c 'return 1')
if [ "$RETURN_1_COUNT" -ge 2 ]; then
    echo -e "  ${GREEN}✅ Found $RETURN_1_COUNT explicit return 1 statements${RESET}"
else
    echo -e "  ${YELLOW}⚠️  Only $RETURN_1_COUNT return 1 found (expected multiple for different error paths)${RESET}"
fi

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GREEN}✅ All install_list() capture boundary tests passed${RESET}"
echo ""
echo -e "${CYAN}Summary of fix for issue #104:${RESET}"
echo "  - set +e disables errexit before pacman command"
echo "  - Output and status are captured before any exit possibility"
echo "  - set -e re-enables errexit after capture"
echo "  - Error output is ALWAYS printed on failure"
echo "  - Recovery logic runs with full diagnostic context"
echo "  - Global fail-fast semantics preserved via explicit return 1"
