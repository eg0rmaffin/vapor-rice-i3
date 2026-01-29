#!/bin/bash
# Test script to verify convergent behavior of steam_setup.sh
# This tests the helper functions in isolation

# Don't use set -e because helper functions return 1 for "no changes" which is valid

# Source the steam_setup.sh to get the helper functions
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$SCRIPT_DIR/scripts/steam_setup.sh"

# Test directory
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

echo "Testing convergent symlink behavior..."
echo "Test directory: $TEST_DIR"
echo ""

# Create a test target file
mkdir -p "$TEST_DIR/dotfiles"
echo "test content" > "$TEST_DIR/dotfiles/test.desktop"

# Test 1: Create new symlink
echo "Test 1: Creating new symlink"
ensure_symlink "$TEST_DIR/dotfiles/test.desktop" "$TEST_DIR/link1.desktop" "test link 1"
result=$?
if [ $result -eq 0 ]; then
    echo "  PASS: ensure_symlink returned 0 (created)"
else
    echo "  FAIL: ensure_symlink returned $result (expected 0)"
fi

# Test 2: Re-run on existing correct symlink
echo ""
echo "Test 2: Re-running on existing correct symlink"
ensure_symlink "$TEST_DIR/dotfiles/test.desktop" "$TEST_DIR/link1.desktop" "test link 1"
result=$?
if [ $result -eq 1 ]; then
    echo "  PASS: ensure_symlink returned 1 (unchanged)"
else
    echo "  FAIL: ensure_symlink returned $result (expected 1)"
fi

# Test 3: ensure_removed on non-existent file
echo ""
echo "Test 3: ensure_removed on non-existent file"
ensure_removed "$TEST_DIR/nonexistent.desktop" "nonexistent"
result=$?
if [ $result -eq 1 ]; then
    echo "  PASS: ensure_removed returned 1 (already absent)"
else
    echo "  FAIL: ensure_removed returned $result (expected 1)"
fi

# Test 4: ensure_removed on existing file
echo ""
echo "Test 4: ensure_removed on existing file"
touch "$TEST_DIR/to_remove.desktop"
ensure_removed "$TEST_DIR/to_remove.desktop" "file to remove"
result=$?
if [ $result -eq 0 ]; then
    echo "  PASS: ensure_removed returned 0 (removed)"
else
    echo "  FAIL: ensure_removed returned $result (expected 0)"
fi

# Test 5: Re-run ensure_removed after removal
echo ""
echo "Test 5: Re-run ensure_removed after removal"
ensure_removed "$TEST_DIR/to_remove.desktop" "file to remove"
result=$?
if [ $result -eq 1 ]; then
    echo "  PASS: ensure_removed returned 1 (already absent)"
else
    echo "  FAIL: ensure_removed returned $result (expected 1)"
fi

echo ""
echo "All tests completed!"
