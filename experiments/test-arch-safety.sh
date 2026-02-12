#!/bin/bash
# Test script for Arch-safe install.sh refactoring
# This script tests the core safety functions without actually running pacman
#
# NEW: Tests for OFFLINE-FIRST design (v2)
# - No implicit -Syu on normal runs
# - -Syu is FALLBACK-ONLY (dependency conflicts)
# - Keyring repair is OFFLINE-ONLY (PGP signature errors)

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

# Count pacman -Syu (safe, should only be in perform_system_upgrade fallback)
SAFE_SYNC=$(grep -c "pacman -Syu" "$INSTALL_SH" 2>/dev/null || echo "0")

# Count pacman -Sy (excluding -Syu, comments, and string literals)
# This should be 0 in the new design
BARE_SY=$(grep -E "pacman -Sy[^u]|pacman -Sy$" "$INSTALL_SH" 2>/dev/null | grep -v "^#" | grep -v "# " | grep -v "'pacman" | wc -l | tr -d ' ')

# Count pacman -Syy (should be 0)
BARE_SYY=$(grep "pacman -Syy" "$INSTALL_SH" 2>/dev/null | wc -l | tr -d ' ' || echo "0")

echo "  Safe -Syu calls: $SAFE_SYNC (inside fallback functions)"
echo "  Bare -Sy calls: $BARE_SY (expected: 0 in offline-first design)"
echo "  Bare -Syy calls: $BARE_SYY (expected: 0)"

if [ "$BARE_SYY" -eq 0 ]; then
    test_pass "No bare pacman -Syy found"
else
    test_fail "Found $BARE_SYY bare pacman -Syy calls"
fi

if [ "$BARE_SY" -eq 0 ]; then
    test_pass "No bare pacman -Sy found (offline-first compliant)"
else
    test_fail "Found $BARE_SY bare pacman -Sy calls (violates offline-first design)"
fi

# ─────────────────────────────────────────────
# Test 2: Verify FALLBACK-ONLY system upgrade design
echo -e "${CYAN}Test 2: Check fallback-only system upgrade design${RESET}"

if grep -q "perform_system_upgrade()" "$INSTALL_SH"; then
    test_pass "perform_system_upgrade() function defined (fallback)"
else
    test_fail "perform_system_upgrade() function not found"
fi

if grep -q "check_explicit_upgrade()" "$INSTALL_SH"; then
    test_pass "check_explicit_upgrade() function defined"
else
    test_fail "check_explicit_upgrade() function not found"
fi

# Ensure old ensure_system_consistency is removed/renamed
if grep -q "^ensure_system_consistency()" "$INSTALL_SH"; then
    test_fail "Old ensure_system_consistency() still exists (should be removed)"
else
    test_pass "Old ensure_system_consistency() removed (good)"
fi

# ─────────────────────────────────────────────
# Test 3: Verify OFFLINE-FIRST keyring repair
echo -e "${CYAN}Test 3: Check offline-first keyring repair${RESET}"

if grep -q "repair_keyring_offline()" "$INSTALL_SH"; then
    test_pass "repair_keyring_offline() function defined"
else
    test_fail "repair_keyring_offline() function not found"
fi

# Ensure no --refresh-keys in the offline repair function
if grep -A10 "repair_keyring_offline()" "$INSTALL_SH" | grep -q "\-\-refresh-keys"; then
    test_fail "repair_keyring_offline uses --refresh-keys (violates offline-first)"
else
    test_pass "repair_keyring_offline does NOT use --refresh-keys (good)"
fi

# ─────────────────────────────────────────────
# Test 4: Verify install_list handles errors with fallback
echo -e "${CYAN}Test 4: Check install_list error handling${RESET}"

if grep -A60 "install_list()" "$INSTALL_SH" | grep -q "PGP signature"; then
    test_pass "install_list handles PGP signature errors"
else
    test_fail "install_list does not handle PGP signature errors"
fi

if grep -A60 "install_list()" "$INSTALL_SH" | grep -q "could not satisfy dependencies\|breaks dependency"; then
    test_pass "install_list handles dependency conflicts"
else
    test_fail "install_list does not handle dependency conflicts"
fi

if grep -A60 "install_list()" "$INSTALL_SH" | grep -q "repair_keyring_offline"; then
    test_pass "install_list calls repair_keyring_offline on PGP error"
else
    test_fail "install_list does not call repair_keyring_offline"
fi

if grep -A60 "install_list()" "$INSTALL_SH" | grep -q "perform_system_upgrade"; then
    test_pass "install_list calls perform_system_upgrade on dependency conflict"
else
    test_fail "install_list does not call perform_system_upgrade"
fi

# ─────────────────────────────────────────────
# Test 5: Verify AUR helper self-healing
echo -e "${CYAN}Test 5: Check AUR helper self-healing${RESET}"

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
# Test 6: Verify install_list uses --needed flag
echo -e "${CYAN}Test 6: Check install_list uses --needed flag${RESET}"

if grep -A30 "install_list()" "$INSTALL_SH" | grep -q "\-\-needed"; then
    test_pass "install_list uses --needed flag"
else
    test_fail "install_list does not use --needed flag"
fi

# ─────────────────────────────────────────────
# Test 7: Verify mirror validation uses curl, not pacman
echo -e "${CYAN}Test 7: Check mirror validation uses curl${RESET}"

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
# Test 8: Verify CLI flags are defined
echo -e "${CYAN}Test 8: Check CLI flags${RESET}"

if grep -q "\-\-upgrade" "$INSTALL_SH"; then
    test_pass "--upgrade flag defined"
else
    test_fail "--upgrade flag not found"
fi

if grep -q "\-\-force-sync" "$INSTALL_SH"; then
    test_pass "--force-sync flag defined"
else
    test_fail "--force-sync flag not found"
fi

# ─────────────────────────────────────────────
# Test 9: Verify mark_synced and mark_upgraded functions
echo -e "${CYAN}Test 9: Check sync/upgrade stamps${RESET}"

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
# Test 10: Verify no implicit upgrade on normal path
echo -e "${CYAN}Test 10: Check no implicit upgrade on normal execution path${RESET}"

# The script should call check_explicit_upgrade, not ensure_system_consistency
if grep -q "check_explicit_upgrade || true" "$INSTALL_SH"; then
    test_pass "Normal path uses check_explicit_upgrade (no implicit upgrade)"
else
    test_fail "Normal path does not use check_explicit_upgrade"
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
echo -e "${CYAN}OFFLINE-FIRST design validated:${RESET}"
echo "  - No implicit -Syu on normal runs"
echo "  - -Syu is fallback-only (dependency conflicts)"
echo "  - Keyring repair is offline-only (PGP errors)"
