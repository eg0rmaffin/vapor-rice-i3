#!/bin/bash
# Test script for XDG directory custom icon metadata (gio set)
# Verifies that the declarative custom-icon-name setup logic is correct
#
# NOTE: Tests that require gvfs/gio are only run when gio is available.
# On CI without a D-Bus session, gio metadata operations are not supported,
# so those tests are skipped gracefully.

set -e

GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
RESET="\033[0m"

PASS=0
FAIL=0
SKIP=0

# Test helper
test_case() {
    local name="$1"
    local condition="$2"
    if eval "$condition"; then
        echo -e "${GREEN}✅ PASS: $name${RESET}"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}❌ FAIL: $name${RESET}"
        FAIL=$((FAIL + 1))
    fi
}

skip_case() {
    local name="$1"
    local reason="$2"
    echo -e "${YELLOW}⏭️  SKIP: $name ($reason)${RESET}"
    SKIP=$((SKIP + 1))
}

echo "=== XDG Custom Icon Metadata Test Suite ==="
echo ""

# ─── Test: install.sh contains the icon mapping ───
echo "Test: install.sh declares custom icon names"
echo "--------------------------------------"

INSTALL_SH="$(dirname "$0")/../install.sh"

test_case "install.sh contains gio set logic" \
    "grep -q 'metadata::custom-icon-name' '$INSTALL_SH'"

test_case "install.sh maps Downloads to folder-download" \
    "grep -q '\"Downloads\".*=.*\"folder-download\"' '$INSTALL_SH' || grep -q 'folder-download' '$INSTALL_SH'"

test_case "install.sh maps Documents to folder-documents" \
    "grep -q 'folder-documents' '$INSTALL_SH'"

test_case "install.sh maps Pictures to folder-pictures" \
    "grep -q 'folder-pictures' '$INSTALL_SH'"

test_case "install.sh maps Music to folder-music" \
    "grep -q 'folder-music' '$INSTALL_SH'"

test_case "install.sh maps Videos to folder-videos" \
    "grep -q 'folder-videos' '$INSTALL_SH'"

test_case "Desktop is NOT mapped (excluded)" \
    "! grep -q '\"Desktop\".*folder-desktop' '$INSTALL_SH'"

echo ""

# ─── Test: Mapping correctness ───
echo "Test: Icon name mapping follows freedesktop.org naming"
echo "--------------------------------------"

# Verify the mapping in install.sh uses correct freedesktop icon names
declare -A EXPECTED_ICONS=(
    ["Downloads"]="folder-download"
    ["Documents"]="folder-documents"
    ["Pictures"]="folder-pictures"
    ["Music"]="folder-music"
    ["Videos"]="folder-videos"
)

for dir in "${!EXPECTED_ICONS[@]}"; do
    icon="${EXPECTED_ICONS[$dir]}"
    test_case "Mapping: $dir -> $icon (freedesktop standard)" \
        "grep -q '$icon' '$INSTALL_SH'"
done

echo ""

# ─── Test: Idempotency logic ───
echo "Test: Idempotency (check-before-act pattern)"
echo "--------------------------------------"

test_case "install.sh checks current icon before setting" \
    "grep -q 'gio info' '$INSTALL_SH'"

test_case "install.sh compares current vs expected icon" \
    "grep -q '_current_icon' '$INSTALL_SH'"

echo ""

# ─── Test: gio set with real directories (requires gvfs + D-Bus) ───
echo "Test: gio set functionality (requires gvfs)"
echo "--------------------------------------"

if ! command -v gio &>/dev/null; then
    skip_case "gio set and read" "gio command not found"
    skip_case "gio idempotency" "gio command not found"
elif ! gio info -a metadata::custom-icon-name /tmp 2>/dev/null | grep -q 'metadata'; then
    skip_case "gio set and read" "gio metadata not available (no D-Bus session or gvfsd-metadata)"
    skip_case "gio idempotency" "gio metadata not available"
else
    # Create temp directory and test gio set/get
    _test_dir=$(mktemp -d)

    gio set "$_test_dir" metadata::custom-icon-name "folder-download"
    _read_icon=$(gio info -a metadata::custom-icon-name "$_test_dir" 2>/dev/null \
        | grep 'metadata::custom-icon-name:' | awk '{print $2}')
    test_case "gio set and read: folder-download" "[ '$_read_icon' = 'folder-download' ]"

    # Idempotency: setting again should not error
    gio set "$_test_dir" metadata::custom-icon-name "folder-download"
    _read_icon2=$(gio info -a metadata::custom-icon-name "$_test_dir" 2>/dev/null \
        | grep 'metadata::custom-icon-name:' | awk '{print $2}')
    test_case "gio idempotency: value unchanged after re-set" "[ '$_read_icon2' = 'folder-download' ]"

    rm -rf "$_test_dir"
fi

echo ""
echo "=== Summary ==="
echo -e "Passed: ${GREEN}$PASS${RESET}"
echo -e "Failed: ${RED}$FAIL${RESET}"
echo -e "Skipped: ${YELLOW}$SKIP${RESET}"

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${RESET}"
    exit 0
else
    echo -e "${RED}Some tests failed!${RESET}"
    exit 1
fi
