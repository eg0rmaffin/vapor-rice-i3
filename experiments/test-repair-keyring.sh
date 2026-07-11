#!/bin/bash
# ─────────────────────────────────────────────
# Test suite for the --repair-keyring flag in install.sh
#
# Part A — STRUCTURAL checks (grep on install.sh): flag, function, dispatcher,
#          offline-first guarantees (no --refresh-keys, no SigLevel tampering).
#
# Part B — BEHAVIORAL checks: actually run `install.sh --repair-keyring` with all
#          privileged commands (sudo / pacman / pacman-key / pgrep / timedatectl)
#          replaced by logging mocks, and assert that the script:
#            1. repairs the keyring (offline reset + archlinux-keyring update),
#            2. EXITS without continuing into the dotfiles install flow,
#            3. refuses safely when a pacman/yay/makepkg process is running,
#            4. still completes the offline repair when the online update fails.
#
# No root and no real pacman are required — everything is intercepted by mocks.
#
# Do not use `set -e`: we want every test to run even if an earlier one fails.

GREEN="\033[0;32m"; RED="\033[0;31m"; CYAN="\033[0;36m"; YELLOW="\033[1;33m"; RESET="\033[0m"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALL_SH="$REPO_ROOT/install.sh"

PASS=0
FAIL=0
test_pass() { echo -e "${GREEN}✅ PASS${RESET}: $1"; PASS=$((PASS + 1)); }
test_fail() { echo -e "${RED}❌ FAIL${RESET}: $1"; FAIL=$((FAIL + 1)); }

# assert_contains <description> <haystack> <needle>
assert_contains() {
    if echo "$2" | grep -qF -- "$3"; then test_pass "$1"; else test_fail "$1 (missing: '$3')"; fi
}
# assert_not_contains <description> <haystack> <needle>
assert_not_contains() {
    if echo "$2" | grep -qF -- "$3"; then test_fail "$1 (unexpectedly found: '$3')"; else test_pass "$1"; fi
}
# assert_eq <description> <expected> <actual>
assert_eq() {
    if [ "$2" = "$3" ]; then test_pass "$1"; else test_fail "$1 (expected='$2' actual='$3')"; fi
}

# ═════════════════════════════════════════════════════════════════════════════
# Part A — Structural checks
# ═════════════════════════════════════════════════════════════════════════════
echo -e "${CYAN}── Part A: structural checks ──${RESET}"

if grep -q "REPAIR_KEYRING=0" "$INSTALL_SH"; then
    test_pass "REPAIR_KEYRING flag variable initialized"
else
    test_fail "REPAIR_KEYRING flag variable not found"
fi

if grep -q '"--repair-keyring" \]\] && REPAIR_KEYRING=1' "$INSTALL_SH"; then
    test_pass "--repair-keyring parsed in argument loop"
else
    test_fail "--repair-keyring not parsed in argument loop"
fi

if grep -q "perform_keyring_repair()" "$INSTALL_SH"; then
    test_pass "perform_keyring_repair() function defined"
else
    test_fail "perform_keyring_repair() function not found"
fi

if grep -q "check_explicit_keyring_repair()" "$INSTALL_SH"; then
    test_pass "check_explicit_keyring_repair() dispatcher defined"
else
    test_fail "check_explicit_keyring_repair() dispatcher not found"
fi

# The dispatcher must be CALLED before the install flow starts (before the header
# banner / multilib / mirrors). We approximate "before the flow" as: the call
# appears before the deps install_list invocation.
call_line=$(grep -n "^check_explicit_keyring_repair$" "$INSTALL_SH" | head -1 | cut -d: -f1)
flow_line=$(grep -n 'install_list "\${deps\[@\]}"' "$INSTALL_SH" | head -1 | cut -d: -f1)
if [ -n "$call_line" ] && [ -n "$flow_line" ] && [ "$call_line" -lt "$flow_line" ]; then
    test_pass "Dispatcher called before the package install flow (line $call_line < $flow_line)"
else
    test_fail "Dispatcher not called before the package install flow (call=$call_line flow=$flow_line)"
fi

# The dispatcher must exit so it cannot fall through into the install flow.
if grep -A6 "check_explicit_keyring_repair()" "$INSTALL_SH" | grep -q "exit 0"; then
    test_pass "Dispatcher exits after repair (does not continue the install flow)"
else
    test_fail "Dispatcher does not exit after repair"
fi

# Offline-first guarantees explicitly required by the issue.
if grep -A50 "perform_keyring_repair()" "$INSTALL_SH" | grep -q -- "--refresh-keys"; then
    test_fail "perform_keyring_repair uses --refresh-keys (violates offline-first)"
else
    test_pass "perform_keyring_repair does NOT use --refresh-keys (offline-first)"
fi

# Only executable (non-comment) lines count — a comment documenting that we leave
# SigLevel alone is fine; an actual SigLevel assignment in pacman.conf is not.
if grep -v '^[[:space:]]*#' "$INSTALL_SH" | grep -q "SigLevel"; then
    test_fail "install.sh modifies SigLevel (must not change signature policy)"
else
    test_pass "install.sh does not modify SigLevel (signature verification preserved)"
fi

# ═════════════════════════════════════════════════════════════════════════════
# Part B — Behavioral checks (mocked privileged commands)
# ═════════════════════════════════════════════════════════════════════════════
echo -e "${CYAN}── Part B: behavioral checks (mocked sudo/pacman/pgrep) ──${RESET}"

MOCK_ROOT="$(mktemp -d)"
trap 'rm -rf "$MOCK_ROOT"' EXIT
MOCK_BIN="$MOCK_ROOT/bin"
mkdir -p "$MOCK_BIN"
CMD_LOG="$MOCK_ROOT/cmd.log"

# sudo: log the invocation, then succeed — unless SUDO_FAIL_MATCH is set and the
# command line matches it (used to simulate a failing online keyring update).
cat > "$MOCK_BIN/sudo" <<'MOCK'
#!/bin/bash
echo "sudo $*" >> "$CMD_LOG"
if [ -n "$SUDO_FAIL_MATCH" ] && echo "$*" | grep -q -- "$SUDO_FAIL_MATCH"; then
    exit 1
fi
exit 0
MOCK

# pgrep: report "no process" (exit 1) unless PGREP_FOUND=1 (simulate live txn).
cat > "$MOCK_BIN/pgrep" <<'MOCK'
#!/bin/bash
echo "pgrep $*" >> "$CMD_LOG"
[ "${PGREP_FOUND:-0}" = "1" ] && exit 0
exit 1
MOCK

# timedatectl: present so the best-effort NTP branch is exercised.
cat > "$MOCK_BIN/timedatectl" <<'MOCK'
#!/bin/bash
echo "timedatectl $*" >> "$CMD_LOG"
exit 0
MOCK

chmod +x "$MOCK_BIN"/sudo "$MOCK_BIN"/pgrep "$MOCK_BIN"/timedatectl

# run_repair <pgrep_found> <sudo_fail_match>  → sets globals: RC, OUT, LOG
run_repair() {
    : > "$CMD_LOG"
    env "PATH=$MOCK_BIN:$PATH" "CMD_LOG=$CMD_LOG" \
        "PGREP_FOUND=$1" "SUDO_FAIL_MATCH=$2" \
        bash "$INSTALL_SH" --repair-keyring > "$MOCK_ROOT/out.log" 2>&1
    RC=$?
    OUT="$(cat "$MOCK_ROOT/out.log")"
    LOG="$(cat "$CMD_LOG")"
}

# ── Scenario 1: happy path ───────────────────────────────────────────────────
echo -e "${YELLOW}Scenario 1: happy path (no running process, online update OK)${RESET}"
run_repair "0" ""
assert_eq          "exits 0 on success" "0" "$RC"
assert_contains    "announces explicit repair" "$OUT" "Explicit pacman keyring repair requested"
assert_contains    "reports keyring repaired + keyring updated" "$OUT" "Pacman keyring repaired and archlinux-keyring updated"
assert_not_contains "does NOT print the install header (early exit)" "$OUT" "Installing your dotfiles"
assert_contains    "runs offline reset (rm gnupg dir)" "$LOG" "rm -rf /etc/pacman.d/gnupg"
assert_contains    "runs pacman-key --init" "$LOG" "pacman-key --init"
assert_contains    "runs pacman-key --populate archlinux" "$LOG" "pacman-key --populate archlinux"
assert_contains    "updates archlinux-keyring online" "$LOG" "pacman -Sy --noconfirm archlinux-keyring"
assert_contains    "enables NTP best-effort" "$LOG" "timedatectl set-ntp true"
assert_not_contains "does NOT install the dotfiles deps (no xorg-server)" "$LOG" "xorg-server"
assert_not_contains "does NOT run a full system upgrade" "$LOG" "pacman -Syu"

# ── Scenario 2: a package manager is running → safe abort ────────────────────
echo -e "${YELLOW}Scenario 2: pacman/yay/makepkg running → refuse and exit 1${RESET}"
run_repair "1" ""
assert_eq          "exits 1 when a transaction may be active" "1" "$RC"
assert_contains    "warns about the running process" "$OUT" "Another package manager process is running"
assert_not_contains "does NOT touch the keyring (no pacman-key)" "$LOG" "pacman-key"
assert_not_contains "does NOT delete the gnupg dir" "$LOG" "rm -rf /etc/pacman.d/gnupg"

# ── Scenario 3: online update fails → offline repair still completes ─────────
echo -e "${YELLOW}Scenario 3: online archlinux-keyring update fails → offline repair still OK${RESET}"
run_repair "0" "archlinux-keyring"
assert_eq          "still exits 0 (offline reset is the deterministic core)" "0" "$RC"
assert_contains    "still runs the offline reset" "$LOG" "pacman-key --init"
assert_contains    "reports the offline reset was applied" "$OUT" "offline reset applied"
assert_not_contains "still does NOT continue the install flow" "$OUT" "Installing your dotfiles"

# ═════════════════════════════════════════════════════════════════════════════
# Summary
# ═════════════════════════════════════════════════════════════════════════════
echo ""
echo "═══════════════════════════════════════════"
echo -e "Tests passed: ${GREEN}$PASS${RESET}"
echo -e "Tests failed: ${RED}$FAIL${RESET}"
echo "═══════════════════════════════════════════"
[ "$FAIL" -eq 0 ]
