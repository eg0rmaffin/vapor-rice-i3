#!/bin/bash
# ─────────────────────────────────────────────
# Test: install.sh must not report success when `pacman -Syu` fails
#
# Reproduces https://github.com/eg0rmaffin/vapor-rice-i3/issues/119
#
# Validates that perform_system_upgrade():
#   1. On pacman failure: prints a red failure message, does NOT write the
#      last-upgrade stamp, sets UPGRADE_FAILED=1 and returns non-zero
#   2. On pacman success: writes both stamps and prints the green message
#   3. install.sh ends with a red banner and exit 1 when UPGRADE_FAILED=1
#
# Usage: ./experiments/test-upgrade-failure.sh
# ─────────────────────────────────────────────

set -e

GREEN="\033[0;32m"
RED="\033[0;31m"
CYAN="\033[0;36m"
RESET="\033[0m"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
INSTALL_FILE="$REPO_DIR/install.sh"

FAILURES=0

pass() { echo -e "  ${GREEN}✅ $1${RESET}"; }
fail() { echo -e "  ${RED}❌ $1${RESET}"; FAILURES=$((FAILURES + 1)); }

# Extract a shell function definition (`name() {` ... `}` at column 0) from install.sh
extract_fn() {
    awk -v fn="$1" '$0 ~ "^"fn"\\(\\) \\{" {p=1} p {print} p && /^\}$/ {exit}' "$INSTALL_FILE"
}

# Build a sandbox that provides the upgrade functions plus a fake sudo/pacman
# whose exit code we control via the PACMAN_EXIT variable.
make_harness() {
    local tmp="$1"
    {
        echo 'RED=""; GREEN=""; YELLOW=""; CYAN=""; RESET=""'
        echo "UPGRADE_STAMP=\"$tmp/last-upgrade\""
        echo "SYNC_STAMP=\"$tmp/last-sync\""
        echo 'UPGRADE_FAILED=0'
        echo 'sudo() { if [ "$1" = "pacman" ]; then return "${PACMAN_EXIT:-0}"; fi; return 0; }'
        echo 'ensure_keyring_for_upgrade() { :; }'
        extract_fn mark_synced
        extract_fn mark_upgraded
        extract_fn perform_system_upgrade
    } > "$tmp/harness.sh"
}

echo -e "${CYAN}🧪 Testing install.sh upgrade failure handling${RESET}"
echo ""

# ─── Test 1: pacman fails ─────────────────────────────────────
echo -e "${CYAN}Test 1: failed 'pacman -Syu' must not claim success${RESET}"
TMP1=$(mktemp -d)
make_harness "$TMP1"
set +e
OUT=$(PACMAN_EXIT=1 bash -c "source '$TMP1/harness.sh'; perform_system_upgrade; echo \"RC=\$?\"; echo \"FLAG=\$UPGRADE_FAILED\"" 2>&1)
set -e

echo "$OUT" | grep -q "RC=1" \
    && pass "perform_system_upgrade returns non-zero" \
    || fail "perform_system_upgrade returned zero on pacman failure"

echo "$OUT" | grep -q "FLAG=1" \
    && pass "UPGRADE_FAILED is set to 1" \
    || fail "UPGRADE_FAILED was not set"

echo "$OUT" | grep -q "System upgrade failed" \
    && pass "failure message printed" \
    || fail "no failure message printed"

echo "$OUT" | grep -q "System upgraded and synced" \
    && fail "success message printed despite failure" \
    || pass "no success message printed"

[ -f "$TMP1/last-upgrade" ] \
    && fail "last-upgrade stamp was written despite failure" \
    || pass "last-upgrade stamp NOT written"

rm -rf "$TMP1"
echo ""

# ─── Test 2: pacman succeeds ──────────────────────────────────
echo -e "${CYAN}Test 2: successful upgrade keeps previous behavior${RESET}"
TMP2=$(mktemp -d)
make_harness "$TMP2"
set +e
OUT=$(PACMAN_EXIT=0 bash -c "source '$TMP2/harness.sh'; perform_system_upgrade; echo \"RC=\$?\"" 2>&1)
set -e

echo "$OUT" | grep -q "RC=0" \
    && pass "perform_system_upgrade returns zero" \
    || fail "perform_system_upgrade returned non-zero on success"

echo "$OUT" | grep -q "System upgraded and synced" \
    && pass "success message printed" \
    || fail "no success message printed"

[ -f "$TMP2/last-upgrade" ] \
    && pass "last-upgrade stamp written" \
    || fail "last-upgrade stamp missing"

[ -f "$TMP2/last-sync" ] \
    && pass "last-sync stamp written" \
    || fail "last-sync stamp missing"

rm -rf "$TMP2"
echo ""

# ─── Test 3: final banner + non-zero exit ─────────────────────
echo -e "${CYAN}Test 3: script ends with a red banner and exit 1 when UPGRADE_FAILED=1${RESET}"
BANNER=$(awk '/^if \[ "\$UPGRADE_FAILED" -eq 1 \]; then/,/^fi$/' "$INSTALL_FILE")

[ -n "$BANNER" ] \
    && pass "final UPGRADE_FAILED banner exists" \
    || fail "no final UPGRADE_FAILED banner found"

echo "$BANNER" | grep -q "exit 1" \
    && pass "banner exits with non-zero code" \
    || fail "banner does not exit non-zero"

# The banner must come before the final green "All done" line
BANNER_LINE=$(grep -n '^if \[ "\$UPGRADE_FAILED" -eq 1 \]; then' "$INSTALL_FILE" | cut -d: -f1)
DONE_LINE=$(grep -n 'All done! You can launch i3' "$INSTALL_FILE" | cut -d: -f1)
if [ -n "$BANNER_LINE" ] && [ -n "$DONE_LINE" ] && [ "$BANNER_LINE" -lt "$DONE_LINE" ]; then
    pass "banner is checked before the final success line"
else
    fail "banner is not checked before the final success line"
fi
echo ""

# ─── Test 4: syntax check ─────────────────────────────────────
echo -e "${CYAN}Test 4: install.sh is syntactically valid${RESET}"
bash -n "$INSTALL_FILE" \
    && pass "bash -n passes" \
    || fail "bash -n failed"
echo ""

if [ "$FAILURES" -eq 0 ]; then
    echo -e "${GREEN}🎉 All upgrade-failure tests passed${RESET}"
    exit 0
fi
echo -e "${RED}❌ $FAILURES check(s) failed${RESET}"
exit 1
