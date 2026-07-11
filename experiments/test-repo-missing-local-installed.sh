#!/bin/bash
# ─────────────────────────────────────────────
# Test script for repo-missing but locally-installed detection
#
# This script validates the fix for issue #106:
#   - install_list() must detect "target not found" errors
#   - If package is locally installed → non-fatal warning + continue
#   - If package is not locally installed → fatal error
#   - All repo-missing packages tracked for end-of-run summary
#
# Usage: ./experiments/test-repo-missing-local-installed.sh
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

echo -e "${CYAN}🧪 Testing repo-missing but locally-installed detection (Issue #106)${RESET}"
echo ""

# ─────────────────────────────────────────────
# Test 1: Global tracking array exists
# ─────────────────────────────────────────────
echo -e "${CYAN}Test 1: Global tracking array declared${RESET}"

if grep -q 'declare -a REPO_MISSING_LOCAL_INSTALLED=' "$INSTALL_FILE"; then
    echo -e "  ${GREEN}✅ REPO_MISSING_LOCAL_INSTALLED array declared${RESET}"
else
    echo -e "  ${RED}❌ REPO_MISSING_LOCAL_INSTALLED array NOT found${RESET}"
    exit 1
fi

# ─────────────────────────────────────────────
# Test 2: install_list() checks for "target not found"
# ─────────────────────────────────────────────
echo -e "${CYAN}Test 2: install_list() checks for 'target not found' errors${RESET}"

# Extract install_list function
INSTALL_LIST_FUNC=$(sed -n '/^install_list()/,/^}/p' "$INSTALL_FILE")

if echo "$INSTALL_LIST_FUNC" | grep -q 'error: target not found:'; then
    echo -e "  ${GREEN}✅ 'target not found' detection present${RESET}"
else
    echo -e "  ${RED}❌ 'target not found' detection NOT found${RESET}"
    exit 1
fi

# ─────────────────────────────────────────────
# Test 3: Check for local installation via pacman -Q
# ─────────────────────────────────────────────
echo -e "${CYAN}Test 3: Checks local installation via pacman -Q${RESET}"

if echo "$INSTALL_LIST_FUNC" | grep -q 'pacman -Q.*pkg'; then
    echo -e "  ${GREEN}✅ pacman -Q check present for local installation${RESET}"
else
    echo -e "  ${RED}❌ pacman -Q check NOT found${RESET}"
    exit 1
fi

# ─────────────────────────────────────────────
# Test 4: Distinguishes between local-installed and truly-missing
# ─────────────────────────────────────────────
echo -e "${CYAN}Test 4: Distinguishes local-installed vs truly-missing${RESET}"

if echo "$INSTALL_LIST_FUNC" | grep -q 'locally_installed' && \
   echo "$INSTALL_LIST_FUNC" | grep -q 'truly_missing'; then
    echo -e "  ${GREEN}✅ Both locally_installed and truly_missing arrays present${RESET}"
else
    echo -e "  ${RED}❌ Distinction arrays NOT found${RESET}"
    exit 1
fi

# ─────────────────────────────────────────────
# Test 5: Records repo-missing packages to global array
# ─────────────────────────────────────────────
echo -e "${CYAN}Test 5: Records packages to REPO_MISSING_LOCAL_INSTALLED${RESET}"

if echo "$INSTALL_LIST_FUNC" | grep -q 'REPO_MISSING_LOCAL_INSTALLED+='; then
    echo -e "  ${GREEN}✅ Packages recorded to global array${RESET}"
else
    echo -e "  ${RED}❌ Package recording NOT found${RESET}"
    exit 1
fi

# ─────────────────────────────────────────────
# Test 6: Retries installation without repo-missing packages
# ─────────────────────────────────────────────
echo -e "${CYAN}Test 6: Retries without repo-missing packages${RESET}"

if echo "$INSTALL_LIST_FUNC" | grep -q 'remaining_pkgs'; then
    echo -e "  ${GREEN}✅ Retry logic with remaining packages present${RESET}"
else
    echo -e "  ${RED}❌ Retry logic NOT found${RESET}"
    exit 1
fi

# ─────────────────────────────────────────────
# Test 7: Returns fatal error for truly missing packages
# ─────────────────────────────────────────────
echo -e "${CYAN}Test 7: Fatal error for truly missing packages${RESET}"

# Check if truly_missing > 0 case leads to return 1
if echo "$INSTALL_LIST_FUNC" | grep -q '#truly_missing\[@\].*-gt 0'; then
    # Check that there's a return 1 after the truly_missing check
    TRULY_MISSING_CHECK=$(echo "$INSTALL_LIST_FUNC" | grep -n '#truly_missing\[@\].*-gt 0' | tail -1 | cut -d: -f1)
    RETURN_AFTER=$(echo "$INSTALL_LIST_FUNC" | tail -n +$TRULY_MISSING_CHECK | head -20 | grep -q 'return 1' && echo "found")
    if [ "$RETURN_AFTER" = "found" ]; then
        echo -e "  ${GREEN}✅ Fatal return for truly missing packages${RESET}"
    else
        echo -e "  ${RED}❌ Fatal return NOT found after truly_missing check${RESET}"
        exit 1
    fi
else
    echo -e "  ${RED}❌ truly_missing check NOT found${RESET}"
    exit 1
fi

# ─────────────────────────────────────────────
# Test 8: End-of-run reproducibility summary exists
# ─────────────────────────────────────────────
echo -e "${CYAN}Test 8: End-of-run reproducibility summary${RESET}"

if grep -q 'REPRODUCIBILITY DRIFT DETECTED' "$INSTALL_FILE"; then
    echo -e "  ${GREEN}✅ Reproducibility summary present${RESET}"
else
    echo -e "  ${RED}❌ Reproducibility summary NOT found${RESET}"
    exit 1
fi

# ─────────────────────────────────────────────
# Test 9: Summary shows package version
# ─────────────────────────────────────────────
echo -e "${CYAN}Test 9: Summary shows installed version${RESET}"

if grep -q 'local_version=.*pacman -Q' "$INSTALL_FILE"; then
    echo -e "  ${GREEN}✅ Version extraction in summary${RESET}"
else
    echo -e "  ${RED}❌ Version extraction NOT found${RESET}"
    exit 1
fi

# ─────────────────────────────────────────────
# Test 10: Documentation comment in install_list()
# ─────────────────────────────────────────────
echo -e "${CYAN}Test 10: Documentation for repo-missing handling${RESET}"

if echo "$INSTALL_LIST_FUNC" | grep -qi 'repo-missing\|target not found\|reproducibility'; then
    echo -e "  ${GREEN}✅ Documentation comment present${RESET}"
else
    echo -e "  ${YELLOW}⚠️  Consider adding more documentation${RESET}"
fi

# ─────────────────────────────────────────────
# Test 11: Does not affect PGP or dependency handling
# ─────────────────────────────────────────────
echo -e "${CYAN}Test 11: Existing error handlers preserved${RESET}"

if echo "$INSTALL_LIST_FUNC" | grep -q 'PGP signature' && \
   echo "$INSTALL_LIST_FUNC" | grep -q 'could not satisfy dependencies'; then
    echo -e "  ${GREEN}✅ PGP and dependency handlers preserved${RESET}"
else
    echo -e "  ${RED}❌ Existing handlers modified or missing${RESET}"
    exit 1
fi

# ─────────────────────────────────────────────
# Test 12: Target not found handled BEFORE unknown error
# ─────────────────────────────────────────────
echo -e "${CYAN}Test 12: target-not-found handled before unknown error${RESET}"

TARGET_NOT_FOUND_LINE=$(echo "$INSTALL_LIST_FUNC" | grep -n 'error: target not found:' | head -1 | cut -d: -f1)
UNKNOWN_ERROR_LINE=$(echo "$INSTALL_LIST_FUNC" | grep -n 'Unknown error' | head -1 | cut -d: -f1)

if [ -n "$TARGET_NOT_FOUND_LINE" ] && [ -n "$UNKNOWN_ERROR_LINE" ]; then
    if [ "$TARGET_NOT_FOUND_LINE" -lt "$UNKNOWN_ERROR_LINE" ]; then
        echo -e "  ${GREEN}✅ target-not-found (line $TARGET_NOT_FOUND_LINE) before unknown error (line $UNKNOWN_ERROR_LINE)${RESET}"
    else
        echo -e "  ${RED}❌ Wrong order: target-not-found=$TARGET_NOT_FOUND_LINE, unknown=$UNKNOWN_ERROR_LINE${RESET}"
        exit 1
    fi
else
    echo -e "  ${RED}❌ Could not determine line positions${RESET}"
    exit 1
fi

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GREEN}✅ All repo-missing detection tests passed${RESET}"
echo ""
echo -e "${CYAN}Summary of fix for issue #106:${RESET}"
echo "  - Detects 'error: target not found: <pkg>' in pacman output"
echo "  - Checks each missing package with pacman -Q for local installation"
echo "  - If locally installed → non-fatal warning, recorded for summary"
echo "  - If not installed → fatal error (cannot realize package set)"
echo "  - Retries installation with remaining packages"
echo "  - End-of-run summary shows all repo-missing packages"
echo ""
