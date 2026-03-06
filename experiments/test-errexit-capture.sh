#!/bin/bash
# ─────────────────────────────────────────────
# Test script for set -e behavior with command substitution
#
# This script validates the fix for issue #104:
#   - Command substitution under set -e can cause silent exits
#   - The fix must preserve fail-fast semantics while capturing output
#
# Usage: ./experiments/test-errexit-capture.sh
# ─────────────────────────────────────────────

GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
RESET="\033[0m"

echo -e "${CYAN}🧪 Testing set -e behavior with command substitution${RESET}"
echo ""

# ─────────────────────────────────────────────
# Test 1: Demonstrate the BUG (old behavior)
# Under set -e, command substitution with a failing command
# exits the subshell, NOT the parent, and result is captured.
# However, shell behavior differs based on errexit propagation.
# ─────────────────────────────────────────────

echo -e "${CYAN}Test 1: Old pattern (vulnerable to silent exit)${RESET}"

OLD_RESULT=$( (
    set -e

    test_old_pattern() {
        # This is the OLD pattern - potentially problematic
        output=$(false 2>&1)  # false always returns 1
        status=$?
        echo "captured status: $status"
        echo "output: $output"
        return 0
    }

    if test_old_pattern; then
        echo "function succeeded"
    else
        echo "function failed"
    fi
) 2>&1 || echo "SCRIPT EXITED EARLY")

if echo "$OLD_RESULT" | grep -q "SCRIPT EXITED EARLY\|captured status"; then
    if echo "$OLD_RESULT" | grep -q "SCRIPT EXITED EARLY"; then
        echo -e "  ${YELLOW}⚠️  Old pattern caused early exit (shell-dependent)${RESET}"
    else
        echo -e "  ${GREEN}✅ Old pattern worked (this shell doesn't propagate errexit to substitution)${RESET}"
    fi
else
    echo -e "  ${RED}❌ Unexpected result: $OLD_RESULT${RESET}"
fi

# ─────────────────────────────────────────────
# Test 2: New pattern (safe capture boundary)
# ─────────────────────────────────────────────

echo -e "${CYAN}Test 2: New pattern (explicit capture boundary)${RESET}"

NEW_RESULT=$( (
    set -e

    test_new_pattern() {
        local output status

        # Explicit capture boundary - disable errexit locally
        set +e
        output=$(false 2>&1)
        status=$?
        set -e

        echo "captured status: $status"
        echo "output: [$output]"

        if [ $status -ne 0 ]; then
            echo "handling error gracefully"
            return 0  # We handled it
        fi
        return 0
    }

    if test_new_pattern; then
        echo "function succeeded"
    else
        echo "function failed"
    fi
) 2>&1 || echo "SCRIPT EXITED EARLY")

if echo "$NEW_RESULT" | grep -q "captured status: 1"; then
    echo -e "  ${GREEN}✅ New pattern correctly captured exit status${RESET}"
else
    echo -e "  ${RED}❌ New pattern failed to capture status${RESET}"
    echo "  Result: $NEW_RESULT"
    exit 1
fi

if echo "$NEW_RESULT" | grep -q "handling error gracefully"; then
    echo -e "  ${GREEN}✅ New pattern ran error handling code${RESET}"
else
    echo -e "  ${RED}❌ New pattern didn't run error handling${RESET}"
    exit 1
fi

if echo "$NEW_RESULT" | grep -q "function succeeded"; then
    echo -e "  ${GREEN}✅ Script continued execution after handling${RESET}"
else
    echo -e "  ${RED}❌ Script didn't continue${RESET}"
    exit 1
fi

# ─────────────────────────────────────────────
# Test 3: Verify return 1 still propagates under set -e
# Note: In bash, set -e does NOT exit on function return 1 when function is
# called in a command position. It DOES exit on direct command failure.
# We test the pattern used in install.sh where return 1 is checked by caller.
# ─────────────────────────────────────────────

echo -e "${CYAN}Test 3: Verify fail-fast for direct command failures${RESET}"

FAIL_RESULT=$( (
    set -e

    test_fail_fast() {
        local output status

        set +e
        output=$(false 2>&1)
        status=$?
        set -e

        if [ $status -ne 0 ]; then
            echo "error detected, not recoverable"
            return 1  # Propagate failure
        fi
        return 0
    }

    echo "before call"
    # Use the pattern from install.sh - check return value
    if ! test_fail_fast; then
        echo "caller detected failure"
        exit 1
    fi
    echo "after call"  # Should not reach
) 2>&1 || echo "FAIL_FAST_WORKED")

if echo "$FAIL_RESULT" | grep -q "FAIL_FAST_WORKED"; then
    echo -e "  ${GREEN}✅ Fail-fast behavior preserved for unhandled errors${RESET}"
else
    echo -e "  ${RED}❌ Fail-fast didn't work${RESET}"
    echo "  Result: $FAIL_RESULT"
    exit 1
fi

if echo "$FAIL_RESULT" | grep -q "after call"; then
    echo -e "  ${RED}❌ Script continued after return 1 (fail-fast broken)${RESET}"
    exit 1
else
    echo -e "  ${GREEN}✅ Script stopped after return 1${RESET}"
fi

# ─────────────────────────────────────────────
# Test 4: Verify pattern properly captures status
# ─────────────────────────────────────────────

echo -e "${CYAN}Test 4: set +e pattern captures correct exit status${RESET}"

OR_TRUE_RESULT=$( (
    set -e

    test_capture() {
        local output status

        # Correct pattern: set +e to capture status
        set +e
        output=$(exit 42 2>&1)  # Simulate specific exit code
        status=$?
        set -e

        echo "captured status: $status"

        if [ $status -eq 42 ]; then
            echo "correct status captured"
        else
            echo "wrong status: expected 42, got $status"
        fi
    }

    test_capture
) 2>&1)

if echo "$OR_TRUE_RESULT" | grep -q "captured status: 42"; then
    echo -e "  ${GREEN}✅ Specific exit status captured correctly${RESET}"
else
    echo -e "  ${RED}❌ Exit status not captured correctly${RESET}"
    echo "  Result: $OR_TRUE_RESULT"
    exit 1
fi

if echo "$OR_TRUE_RESULT" | grep -q "correct status captured"; then
    echo -e "  ${GREEN}✅ Status value preserved accurately${RESET}"
else
    echo -e "  ${RED}❌ Status value not preserved${RESET}"
    exit 1
fi

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GREEN}✅ All errexit capture tests passed${RESET}"
echo ""
echo -e "${CYAN}Summary:${RESET}"
echo "  - set +e / set -e boundary correctly captures exit status"
echo "  - Error handling code runs after capture"
echo "  - Fail-fast behavior preserved via explicit return 1"
echo "  - Global strict mode remains effective"
