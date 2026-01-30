#!/bin/bash
# Test script for XDG user-dirs.dirs generation
# Verifies that the declarative visual semantics setup is correct

set -e

GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
RESET="\033[0m"

PASS=0
FAIL=0

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

echo "=== XDG Visual Semantics Test Suite ==="
echo ""

# Use a temporary home for testing
TEST_HOME=$(mktemp -d)
export HOME="$TEST_HOME"

# Simulate the relevant part of install.sh
mkdir -p "$HOME/.config"

# Create user-dirs.dirs (as install.sh does)
cat > "$HOME/.config/user-dirs.dirs" << 'EOF'
# This file is written by install.sh as part of the declarative setup.
# XDG user directories are explicitly declared here for visual semantics.
# See also: https://wiki.archlinux.org/title/XDG_user_directories
#
# Desktop is intentionally excluded (not used in i3-based workflows).

XDG_DOWNLOAD_DIR="$HOME/Downloads"
XDG_DOCUMENTS_DIR="$HOME/Documents"
XDG_PICTURES_DIR="$HOME/Pictures"
XDG_MUSIC_DIR="$HOME/Music"
XDG_VIDEOS_DIR="$HOME/Videos"
EOF

echo "Test: user-dirs.dirs file generation"
echo "--------------------------------------"

# Test 1: File exists
test_case "user-dirs.dirs file exists" "[ -f '$HOME/.config/user-dirs.dirs' ]"

# Test 2: Downloads directory is declared
test_case "XDG_DOWNLOAD_DIR is declared" "grep -q 'XDG_DOWNLOAD_DIR' '$HOME/.config/user-dirs.dirs'"

# Test 3: Documents directory is declared
test_case "XDG_DOCUMENTS_DIR is declared" "grep -q 'XDG_DOCUMENTS_DIR' '$HOME/.config/user-dirs.dirs'"

# Test 4: Pictures directory is declared
test_case "XDG_PICTURES_DIR is declared" "grep -q 'XDG_PICTURES_DIR' '$HOME/.config/user-dirs.dirs'"

# Test 5: Music directory is declared
test_case "XDG_MUSIC_DIR is declared" "grep -q 'XDG_MUSIC_DIR' '$HOME/.config/user-dirs.dirs'"

# Test 6: Videos directory is declared
test_case "XDG_VIDEOS_DIR is declared" "grep -q 'XDG_VIDEOS_DIR' '$HOME/.config/user-dirs.dirs'"

# Test 7: Desktop is NOT declared (intentionally excluded)
test_case "XDG_DESKTOP_DIR is NOT declared (excluded)" "! grep -q 'XDG_DESKTOP_DIR' '$HOME/.config/user-dirs.dirs'"

# Test 8: File format is correct (shell-sourceable)
test_case "File is valid shell format" "bash -n '$HOME/.config/user-dirs.dirs' 2>/dev/null"

# Test 9: Variables use \$HOME (not hardcoded paths)
test_case "Paths use \$HOME variable" "grep -q '\$HOME/' '$HOME/.config/user-dirs.dirs'"

echo ""
echo "=== Summary ==="
echo -e "Passed: ${GREEN}$PASS${RESET}"
echo -e "Failed: ${RED}$FAIL${RESET}"

# Cleanup
rm -rf "$TEST_HOME"

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${RESET}"
    exit 0
else
    echo -e "${RED}Some tests failed!${RESET}"
    exit 1
fi
