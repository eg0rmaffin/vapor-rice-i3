#!/bin/bash
# Test script for the sync cache mechanism in install.sh
# Verifies that needs_sync / mark_synced work correctly
set -e

GREEN="\033[0;32m"
RED="\033[0;31m"
CYAN="\033[0;36m"
RESET="\033[0m"

SYNC_COOLDOWN=3600
TEST_STAMP="/tmp/test-vapor-sync-stamp"
SYNC_STAMP="$TEST_STAMP"

FORCE_SYNC=0

needs_sync() {
    [[ "$FORCE_SYNC" -eq 1 ]] && return 0
    [[ ! -f "$SYNC_STAMP" ]] && return 0
    local last now age
    last=$(cat "$SYNC_STAMP" 2>/dev/null || echo 0)
    now=$(date +%s)
    age=$(( now - last ))
    [[ "$age" -ge "$SYNC_COOLDOWN" ]]
}

mark_synced() {
    mkdir -p "$(dirname "$SYNC_STAMP")"
    date +%s > "$SYNC_STAMP"
}

PASS=0
FAIL=0

assert() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        echo -e "${GREEN}PASS${RESET}: $desc"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}FAIL${RESET}: $desc (expected=$expected, actual=$actual)"
        FAIL=$((FAIL + 1))
    fi
}

# Cleanup
rm -f "$TEST_STAMP"

# Test 1: No stamp file => needs sync
if needs_sync; then result=0; else result=1; fi
assert "No stamp file => needs sync" "0" "$result"

# Test 2: After mark_synced => does NOT need sync
mark_synced
if needs_sync; then result=0; else result=1; fi
assert "Just synced => skip sync" "1" "$result"

# Test 3: Stamp file with old timestamp => needs sync
echo 0 > "$TEST_STAMP"
if needs_sync; then result=0; else result=1; fi
assert "Old timestamp (epoch 0) => needs sync" "0" "$result"

# Test 4: --force-sync overrides cache
mark_synced
FORCE_SYNC=1
if needs_sync; then result=0; else result=1; fi
assert "FORCE_SYNC=1 => needs sync even if recently synced" "0" "$result"
FORCE_SYNC=0

# Test 5: Stamp with timestamp = now - 3599 (just under cooldown) => skip
echo $(( $(date +%s) - 3599 )) > "$TEST_STAMP"
if needs_sync; then result=0; else result=1; fi
assert "3599s ago (under 3600s cooldown) => skip sync" "1" "$result"

# Test 6: Stamp with timestamp = now - 3601 (just over cooldown) => needs sync
echo $(( $(date +%s) - 3601 )) > "$TEST_STAMP"
if needs_sync; then result=0; else result=1; fi
assert "3601s ago (over 3600s cooldown) => needs sync" "0" "$result"

# Cleanup
rm -f "$TEST_STAMP"

echo ""
echo -e "${CYAN}Results: $PASS passed, $FAIL failed${RESET}"
[[ "$FAIL" -eq 0 ]]
