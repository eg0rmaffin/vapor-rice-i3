#!/bin/bash
# ─────────────────────────────────────────────
# Test script for zram configuration
#
# This script validates that:
#   1. zram_setup.sh exists and is valid bash
#   2. zram-status.sh exists and is valid bash
#   3. install.sh sources zram_setup.sh
#   4. zram configuration follows declarative principles
#   5. Sysctl tuning is appropriate for in-memory swap
#
# Usage: ./experiments/test-zram-config.sh
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
ZRAM_SETUP="$REPO_DIR/scripts/zram_setup.sh"
ZRAM_STATUS="$REPO_DIR/bin/zram-status.sh"

echo -e "${CYAN}🧪 Testing zram configuration${RESET}"
echo ""

TESTS_PASSED=0
TESTS_FAILED=0

pass() {
    echo -e "  ${GREEN}✅ $1${RESET}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

fail() {
    echo -e "  ${RED}❌ $1${RESET}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

warn() {
    echo -e "  ${YELLOW}⚠️  $1${RESET}"
}

# ─── Test 1: zram_setup.sh exists ───
echo -e "${CYAN}Test 1: zram_setup.sh exists${RESET}"
if [ -f "$ZRAM_SETUP" ]; then
    pass "scripts/zram_setup.sh exists"
else
    fail "scripts/zram_setup.sh not found"
fi

# ─── Test 2: zram_setup.sh is valid bash ───
echo -e "${CYAN}Test 2: zram_setup.sh is valid bash${RESET}"
if bash -n "$ZRAM_SETUP" 2>/dev/null; then
    pass "zram_setup.sh has valid syntax"
else
    fail "zram_setup.sh has syntax errors"
fi

# ─── Test 3: zram-status.sh exists ───
echo -e "${CYAN}Test 3: zram-status.sh exists${RESET}"
if [ -f "$ZRAM_STATUS" ]; then
    pass "bin/zram-status.sh exists"
else
    fail "bin/zram-status.sh not found"
fi

# ─── Test 4: zram-status.sh is valid bash ───
echo -e "${CYAN}Test 4: zram-status.sh is valid bash${RESET}"
if bash -n "$ZRAM_STATUS" 2>/dev/null; then
    pass "zram-status.sh has valid syntax"
else
    fail "zram-status.sh has syntax errors"
fi

# ─── Test 5: install.sh sources zram_setup.sh ───
echo -e "${CYAN}Test 5: install.sh sources zram_setup.sh${RESET}"
if grep -q 'source.*zram_setup.sh' "$INSTALL_FILE"; then
    pass "install.sh sources zram_setup.sh"
else
    fail "install.sh does not source zram_setup.sh"
fi

# ─── Test 6: setup_zram function called ───
echo -e "${CYAN}Test 6: setup_zram function is called${RESET}"
if grep -q '^setup_zram$' "$INSTALL_FILE"; then
    pass "setup_zram is called"
else
    fail "setup_zram is not called"
fi

# ─── Test 7: zram-status.sh is linked ───
echo -e "${CYAN}Test 7: zram-status.sh is linked in install.sh${RESET}"
if grep -q 'zram-status.sh' "$INSTALL_FILE"; then
    pass "zram-status.sh is linked"
else
    fail "zram-status.sh is not linked"
fi

# ─── Test 8: Uses zram-generator (declarative) ───
echo -e "${CYAN}Test 8: Uses zram-generator (declarative approach)${RESET}"
if grep -q 'zram-generator' "$ZRAM_SETUP"; then
    pass "Uses zram-generator for declarative setup"
else
    fail "Does not use zram-generator"
fi

# ─── Test 9: Configuration file path ───
echo -e "${CYAN}Test 9: Configuration targets correct path${RESET}"
if grep -q '/etc/systemd/zram-generator.conf' "$ZRAM_SETUP"; then
    pass "Targets /etc/systemd/zram-generator.conf"
else
    fail "Configuration path incorrect"
fi

# ─── Test 10: Sysctl tuning exists ───
echo -e "${CYAN}Test 10: Sysctl tuning for zram${RESET}"
if grep -q '99-vm-zram-parameters.conf' "$ZRAM_SETUP"; then
    pass "Sysctl tuning file referenced"
else
    fail "Sysctl tuning not found"
fi

# ─── Test 11: Swappiness tuned for in-memory swap ───
echo -e "${CYAN}Test 11: vm.swappiness >= 100 (in-memory swap)${RESET}"
if grep -q 'vm.swappiness.*=.*1[0-9][0-9]' "$ZRAM_SETUP"; then
    pass "vm.swappiness tuned for in-memory swap (>=100)"
else
    fail "vm.swappiness not tuned for in-memory swap"
fi

# ─── Test 12: page-cluster = 0 for zram ───
echo -e "${CYAN}Test 12: vm.page-cluster = 0 (optimal for zram)${RESET}"
if grep -q 'vm.page-cluster.*=.*0' "$ZRAM_SETUP"; then
    pass "vm.page-cluster = 0 (optimal for zram)"
else
    warn "vm.page-cluster may not be optimized"
fi

# ─── Test 13: Compression algorithm specified ───
echo -e "${CYAN}Test 13: Compression algorithm specified${RESET}"
if grep -q 'compression-algorithm' "$ZRAM_SETUP"; then
    pass "Compression algorithm specified"
else
    warn "Compression algorithm not specified (using default)"
fi

# ─── Test 14: zram-size configured ───
echo -e "${CYAN}Test 14: zram-size configured${RESET}"
if grep -q 'zram-size' "$ZRAM_SETUP"; then
    pass "zram-size configured"
else
    warn "zram-size not configured (using default)"
fi

# ─── Test 15: install.sh has valid syntax ───
echo -e "${CYAN}Test 15: install.sh has valid syntax${RESET}"
if bash -n "$INSTALL_FILE" 2>/dev/null; then
    pass "install.sh has valid syntax"
else
    fail "install.sh has syntax errors"
fi

# ─── Test 16: No disk-backed swap (declarative zram only) ───
echo -e "${CYAN}Test 16: Declarative design (no disk swap)${RESET}"
if ! grep -q 'mkswap\|swapon.*\/dev\/sd\|swapfile' "$ZRAM_SETUP"; then
    pass "No disk-backed swap (pure zram)"
else
    warn "References to disk swap found"
fi

# ─── Test 17: Idempotent checks ───
echo -e "${CYAN}Test 17: Idempotent design (safe to run multiple times)${RESET}"
if grep -q 'pacman -Q\|already installed' "$ZRAM_SETUP"; then
    pass "Idempotent checks present"
else
    warn "Idempotent checks may be missing"
fi

# ─── Summary ───
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All $TESTS_PASSED tests passed${RESET}"
    echo ""
    echo -e "${CYAN}zram configuration features:${RESET}"
    echo "  - Declarative: uses zram-generator (systemd-native)"
    echo "  - Idempotent: safe to run install.sh multiple times"
    echo "  - No disk swap: in-memory compression only"
    echo "  - Tuned: vm.swappiness/page-cluster optimized for zram"
    echo "  - Diagnostic: zram-status.sh for easy verification"
    exit 0
else
    echo -e "${RED}❌ $TESTS_FAILED test(s) failed, $TESTS_PASSED passed${RESET}"
    exit 1
fi
