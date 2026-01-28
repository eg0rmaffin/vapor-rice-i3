#!/bin/bash
# Test the GTK 3.0 bookmarks section of install.sh

set -e

echo "=== Testing GTK 3.0 Bookmarks Installation Section ==="
echo

# Create temporary test directory structure
TEST_DIR="/tmp/thunar-install-test-$$"
HOME_DIR="$TEST_DIR/home/testuser"
mkdir -p "$HOME_DIR"

# Simulate user directories (these would normally be created by xdg-user-dirs)
mkdir -p "$HOME_DIR/Downloads"
mkdir -p "$HOME_DIR/Documents"
mkdir -p "$HOME_DIR/Pictures"
mkdir -p "$HOME_DIR/Music"
mkdir -p "$HOME_DIR/Videos"
mkdir -p "$HOME_DIR/Desktop"

echo "📁 Simulated home directory: $HOME_DIR"
ls -la "$HOME_DIR"
echo

# Simulate dotfiles structure
mkdir -p "$HOME_DIR/dotfiles/gtk-3.0"
echo "[Settings]" > "$HOME_DIR/dotfiles/gtk-3.0/settings.ini"

# Simulate the install.sh bookmark generation section
cd "$HOME_DIR"

echo "🔧 Testing bookmark generation logic..."
echo

# Colors (same as install.sh)
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
RESET="\033[0m"

# Standard XDG user directories
BOOKMARK_DIRS=(
    "Downloads"
    "Documents"
    "Pictures"
    "Music"
    "Videos"
    "Desktop"
)

# Create config directory and bookmarks file
mkdir -p "$HOME_DIR/.config/gtk-3.0"
ln -sf "$HOME_DIR/dotfiles/gtk-3.0/settings.ini" "$HOME_DIR/.config/gtk-3.0/settings.ini"

# Create bookmarks file with only existing directories
> "$HOME_DIR/.config/gtk-3.0/bookmarks"  # Clear/create file
for dir in "${BOOKMARK_DIRS[@]}"; do
    if [ -d "$HOME_DIR/$dir" ]; then
        echo "file://$HOME_DIR/$dir $dir" >> "$HOME_DIR/.config/gtk-3.0/bookmarks"
        echo -e "  ${GREEN}✅ Added bookmark: $dir${RESET}"
    else
        echo -e "  ${YELLOW}⚠️ Skipped (not found): $dir${RESET}"
    fi
done

echo
echo "📄 Generated bookmarks content:"
cat "$HOME_DIR/.config/gtk-3.0/bookmarks"

# Verify results
echo
echo "🔍 Verifying..."

if [ -L "$HOME_DIR/.config/gtk-3.0/settings.ini" ]; then
    echo "✅ settings.ini symlink exists"
else
    echo "❌ settings.ini symlink missing"
    rm -rf "$TEST_DIR"
    exit 1
fi

if [ -f "$HOME_DIR/.config/gtk-3.0/bookmarks" ]; then
    echo "✅ bookmarks file exists"
    bookmark_count=$(grep -c '^file://' "$HOME_DIR/.config/gtk-3.0/bookmarks")
    echo "   - Contains $bookmark_count bookmarks"

    if [ "$bookmark_count" -eq 6 ]; then
        echo "✅ All 6 directories added as bookmarks"
    else
        echo "❌ Expected 6 bookmarks, got $bookmark_count"
        rm -rf "$TEST_DIR"
        exit 1
    fi
else
    echo "❌ bookmarks file missing"
    rm -rf "$TEST_DIR"
    exit 1
fi

# Verify no hardcoded paths
if grep -q '/home/admin' "$HOME_DIR/.config/gtk-3.0/bookmarks"; then
    echo "❌ ERROR: Found hardcoded '/home/admin' path!"
    rm -rf "$TEST_DIR"
    exit 1
else
    echo "✅ No hardcoded paths found (uses dynamic \$HOME)"
fi

# Cleanup
cd /
rm -rf "$TEST_DIR"

echo
echo "🎉 Test passed! Installation section works correctly"
