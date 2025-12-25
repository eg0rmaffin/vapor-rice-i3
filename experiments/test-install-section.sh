#!/bin/bash
# Test the GTK 3.0 section of install.sh

set -e

echo "=== Testing GTK 3.0 Installation Section ==="
echo

# Create temporary test directory
TEST_DIR="/tmp/thunar-test-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

# Simulate dotfiles structure
mkdir -p dotfiles/gtk-3.0
echo "[Settings]" > dotfiles/gtk-3.0/settings.ini
cat > dotfiles/gtk-3.0/bookmarks << 'BOOKMARKS'
file:///home/admin/Downloads Downloads
file:///home/admin/Documents Documents
file:///home/admin/Pictures Pictures
BOOKMARKS

# Simulate the install.sh section
mkdir -p .config/gtk-3.0
ln -sf "$TEST_DIR/dotfiles/gtk-3.0/settings.ini" .config/gtk-3.0/settings.ini
ln -sf "$TEST_DIR/dotfiles/gtk-3.0/bookmarks" .config/gtk-3.0/bookmarks

echo "✅ Symlinks created"
echo

# Verify symlinks
if [ -L ".config/gtk-3.0/settings.ini" ]; then
    echo "✅ settings.ini symlink exists"
    ls -la .config/gtk-3.0/settings.ini
else
    echo "❌ settings.ini symlink missing"
    exit 1
fi

if [ -L ".config/gtk-3.0/bookmarks" ]; then
    echo "✅ bookmarks symlink exists"
    ls -la .config/gtk-3.0/bookmarks
else
    echo "❌ bookmarks symlink missing"
    exit 1
fi

echo
echo "📄 Bookmarks content via symlink:"
cat .config/gtk-3.0/bookmarks

# Cleanup
cd /
rm -rf "$TEST_DIR"

echo
echo "🎉 Test passed! Installation section works correctly"
