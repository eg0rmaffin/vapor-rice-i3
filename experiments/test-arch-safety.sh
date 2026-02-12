#!/bin/bash
# Test script for Arch-safe install.sh refactoring
# This script tests the core safety functions without actually running pacman

# Do not use set -e as we want to run all tests even if some fail

# ─────────────────────────────────────────────
# Test Setup
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
RESET="\033[0m"

TESTS_PASSED=0
TESTS_FAILED=0

test_pass() {
    echo -e "${GREEN}✅ PASS: $1${RESET}"
    ((TESTS_PASSED++))
}

test_fail() {
    echo -e "${RED}❌ FAIL: $1${RESET}"
    ((TESTS_FAILED++))
}

# ─────────────────────────────────────────────
# Test 1: Verify no bare pacman -Sy/-Syy patterns exist
echo -e "${CYAN}Test 1: Check for dangerous pacman patterns${RESET}"

INSTALL_SH="../install.sh"

# Count pacman -Syu (safe)
SAFE_SYNC=$(grep -c "pacman -Syu" "$INSTALL_SH" 2>/dev/null || echo "0")

# Count pacman -Sy (excluding -Syu, comments, and string literals)
# This should only find the --no-upgrade warning case
BARE_SY=$(grep -E "pacman -Sy[^u]|pacman -Sy$" "$INSTALL_SH" 2>/dev/null | grep -v "^#" | grep -v "# " | grep -v "'pacman" | wc -l | tr -d ' ')

# Count pacman -Syy (should be 0)
BARE_SYY=$(grep "pacman -Syy" "$INSTALL_SH" 2>/dev/null | wc -l | tr -d ' ' || echo "0")

echo "  Safe -Syu calls: $SAFE_SYNC"
echo "  Bare -Sy calls: $BARE_SY (expected: 1 for --no-upgrade case)"
echo "  Bare -Syy calls: $BARE_SYY (expected: 0)"

if [ "$BARE_SYY" -eq 0 ]; then
    test_pass "No bare pacman -Syy found"
else
    test_fail "Found $BARE_SYY bare pacman -Syy calls"
fi

if [ "$BARE_SY" -le 1 ]; then
    test_pass "Bare pacman -Sy limited to --no-upgrade case only"
else
    test_fail "Found $BARE_SY bare pacman -Sy calls (expected max 1)"
fi

# ─────────────────────────────────────────────
# Test 2: Verify ensure_system_consistency function exists
echo -e "${CYAN}Test 2: Check ensure_system_consistency function exists${RESET}"

if grep -q "ensure_system_consistency()" "$INSTALL_SH"; then
    test_pass "ensure_system_consistency() function defined"
else
    test_fail "ensure_system_consistency() function not found"
fi

if grep -q "ensure_system_consistency$" "$INSTALL_SH"; then
    test_pass "ensure_system_consistency() is called"
else
    test_fail "ensure_system_consistency() is not called"
fi

# ─────────────────────────────────────────────
# Test 3: Verify ensure_keyring function exists
echo -e "${CYAN}Test 3: Check ensure_keyring function exists${RESET}"

if grep -q "ensure_keyring()" "$INSTALL_SH"; then
    test_pass "ensure_keyring() function defined"
else
    test_fail "ensure_keyring() function not found"
fi

# ─────────────────────────────────────────────
# Test 4: Verify ensure_aur_helper function exists with libalpm check
echo -e "${CYAN}Test 4: Check AUR helper self-healing${RESET}"

if grep -q "ensure_aur_helper()" "$INSTALL_SH"; then
    test_pass "ensure_aur_helper() function defined"
else
    test_fail "ensure_aur_helper() function not found"
fi

if grep -q "libalpm" "$INSTALL_SH"; then
    test_pass "libalpm check present in AUR helper"
else
    test_fail "libalpm check not found in AUR helper"
fi

if grep -q "_rebuild_yay" "$INSTALL_SH"; then
    test_pass "_rebuild_yay helper function exists"
else
    test_fail "_rebuild_yay helper function not found"
fi

# ─────────────────────────────────────────────
# Test 5: Verify install_list uses --needed flag
echo -e "${CYAN}Test 5: Check install_list uses --needed flag${RESET}"

if grep -A20 "install_list()" "$INSTALL_SH" | grep -q "\-\-needed"; then
    test_pass "install_list uses --needed flag"
else
    test_fail "install_list does not use --needed flag"
fi

# ─────────────────────────────────────────────
# Test 6: Verify mirror validation uses curl, not pacman
echo -e "${CYAN}Test 6: Check mirror validation uses curl${RESET}"

if grep -q "test_mirror_reachable" "$INSTALL_SH"; then
    test_pass "test_mirror_reachable function exists"
else
    test_fail "test_mirror_reachable function not found"
fi

if grep -A3 "test_mirror_reachable()" "$INSTALL_SH" | grep -q "curl"; then
    test_pass "Mirror validation uses curl"
else
    test_fail "Mirror validation does not use curl"
fi

# ─────────────────────────────────────────────
# Test 7: Verify CLI flags are defined
echo -e "${CYAN}Test 7: Check CLI flags${RESET}"

if grep -q "\-\-upgrade" "$INSTALL_SH"; then
    test_pass "--upgrade flag defined"
else
    test_fail "--upgrade flag not found"
fi

if grep -q "\-\-no-upgrade" "$INSTALL_SH"; then
    test_pass "--no-upgrade flag defined"
else
    test_fail "--no-upgrade flag not found"
fi

if grep -q "\-\-force-sync" "$INSTALL_SH"; then
    test_pass "--force-sync flag defined"
else
    test_fail "--force-sync flag not found"
fi

# ─────────────────────────────────────────────
# Test 8: Verify mark_synced and mark_upgraded functions
echo -e "${CYAN}Test 8: Check sync/upgrade stamps${RESET}"

if grep -q "mark_synced()" "$INSTALL_SH"; then
    test_pass "mark_synced() function defined"
else
    test_fail "mark_synced() function not found"
fi

if grep -q "mark_upgraded()" "$INSTALL_SH"; then
    test_pass "mark_upgraded() function defined"
else
    test_fail "mark_upgraded() function not found"
fi

# ─────────────────────────────────────────────
# Summary
echo ""
echo "═══════════════════════════════════════════"
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${RESET}"
echo -e "Tests failed: ${RED}$TESTS_FAILED${RESET}"
echo "═══════════════════════════════════════════"

if [ "$TESTS_FAILED" -gt 0 ]; then
    exit 1
fi

echo -e "${GREEN}All Arch safety tests passed!${RESET}"
