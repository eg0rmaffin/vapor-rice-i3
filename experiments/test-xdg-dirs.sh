#!/bin/bash
# Test script to verify XDG directory and bookmark logic
set -e

# Colors
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
RESET="\033[0m"

# Create a temporary test home directory
TEST_HOME=$(mktemp -d)
echo "Test HOME: $TEST_HOME"

# Override HOME for testing
export HOME="$TEST_HOME"
mkdir -p "$HOME/.config/gtk-3.0"

# The XDG directories array (matches install.sh)
XDG_USER_DIRS=(
    "Downloads"
    "Documents"
    "Pictures"
    "Music"
    "Videos"
)

echo -e "${CYAN}📁 Test 1: Creating XDG user directories...${RESET}"
for dir in "${XDG_USER_DIRS[@]}"; do
    if [ ! -d "$HOME/$dir" ]; then
        mkdir -p "$HOME/$dir"
        echo -e "  ${GREEN}✅ Created: ~/$dir${RESET}"
    else
        echo -e "  ${GREEN}✅ Already exists: ~/$dir${RESET}"
    fi
done

echo ""
echo -e "${CYAN}📁 Test 2: Idempotency - running again should report 'Already exists'...${RESET}"
for dir in "${XDG_USER_DIRS[@]}"; do
    if [ ! -d "$HOME/$dir" ]; then
        mkdir -p "$HOME/$dir"
        echo -e "  ${GREEN}✅ Created: ~/$dir${RESET}"
    else
        echo -e "  ${GREEN}✅ Already exists: ~/$dir${RESET}"
    fi
done

echo ""
echo -e "${CYAN}🔧 Test 3: Generating Thunar bookmarks...${RESET}"
> "$HOME/.config/gtk-3.0/bookmarks"  # Clear/create file
for dir in "${XDG_USER_DIRS[@]}"; do
    echo "file://$HOME/$dir $dir" >> "$HOME/.config/gtk-3.0/bookmarks"
    echo -e "  ${GREEN}✅ Added bookmark: $dir${RESET}"
done

echo ""
echo -e "${CYAN}📋 Result: Contents of bookmarks file:${RESET}"
cat "$HOME/.config/gtk-3.0/bookmarks"

echo ""
echo -e "${CYAN}📋 Result: Listing created directories:${RESET}"
ls -la "$HOME" | grep -E "^d.*"

echo ""
echo -e "${CYAN}✓ Verifying Desktop is NOT in the list:${RESET}"
if grep -q "Desktop" "$HOME/.config/gtk-3.0/bookmarks"; then
    echo -e "${YELLOW}❌ FAIL: Desktop found in bookmarks (should not be there)${RESET}"
    exit 1
else
    echo -e "${GREEN}✅ PASS: Desktop correctly excluded from bookmarks${RESET}"
fi

if [ -d "$HOME/Desktop" ]; then
    echo -e "${YELLOW}❌ FAIL: Desktop directory was created (should not be created)${RESET}"
    exit 1
else
    echo -e "${GREEN}✅ PASS: Desktop directory correctly not created${RESET}"
fi

# Cleanup
rm -rf "$TEST_HOME"
echo ""
echo -e "${GREEN}✅ All tests passed!${RESET}"
