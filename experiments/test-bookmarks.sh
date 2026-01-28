#!/bin/bash
# Test script to verify Thunar bookmarks generation logic

set -e

echo "=== Thunar Bookmarks Generation Test ==="
echo

# Define the same directories as in install.sh
BOOKMARK_DIRS=(
    "Downloads"
    "Documents"
    "Pictures"
    "Music"
    "Videos"
    "Desktop"
)

# Create temporary test directory
TEST_DIR="/tmp/thunar-bookmarks-test-$$"
mkdir -p "$TEST_DIR"

# Simulate some directories exist, some don't
mkdir -p "$TEST_DIR/Downloads"
mkdir -p "$TEST_DIR/Documents"
mkdir -p "$TEST_DIR/Pictures"
# Skip Music, Videos, Desktop to test "directory not found" logic

echo "📁 Test directories created in: $TEST_DIR"
echo "   - Downloads (exists)"
echo "   - Documents (exists)"
echo "   - Pictures (exists)"
echo "   - Music (NOT created)"
echo "   - Videos (NOT created)"
echo "   - Desktop (NOT created)"
echo

# Simulate the bookmarks generation logic from install.sh
BOOKMARKS_FILE="$TEST_DIR/.config/gtk-3.0/bookmarks"
mkdir -p "$(dirname "$BOOKMARKS_FILE")"

echo "🔧 Generating bookmarks file..."
> "$BOOKMARKS_FILE"  # Clear/create file
found_count=0
skipped_count=0

for dir in "${BOOKMARK_DIRS[@]}"; do
    if [ -d "$TEST_DIR/$dir" ]; then
        echo "file://$TEST_DIR/$dir $dir" >> "$BOOKMARKS_FILE"
        echo "  ✅ Added bookmark: $dir"
        found_count=$((found_count + 1))
    else
        echo "  ⚠️ Skipped (not found): $dir"
        skipped_count=$((skipped_count + 1))
    fi
done

echo
echo "📄 Generated bookmarks content:"
cat "$BOOKMARKS_FILE"

echo
echo "🔍 Validating format..."

while IFS= read -r line; do
    [ -z "$line" ] && continue
    if [[ $line == file://* ]]; then
        echo "  ✅ Valid bookmark: $line"
    else
        echo "  ❌ Invalid format: $line"
        rm -rf "$TEST_DIR"
        exit 1
    fi
done < "$BOOKMARKS_FILE"

echo
echo "📋 Summary:"
echo "   - Directories found: $found_count"
echo "   - Directories skipped: $skipped_count"
echo "   - Bookmarks generated: $(grep -c '^file://' "$BOOKMARKS_FILE")"
echo "   - Format: GTK bookmarks (compatible with Thunar)"
echo

# Verify expected behavior
if [ "$found_count" -eq 3 ] && [ "$skipped_count" -eq 3 ]; then
    echo "✅ Generation logic works correctly (only existing dirs added)"
else
    echo "❌ Unexpected counts: found=$found_count, skipped=$skipped_count"
    rm -rf "$TEST_DIR"
    exit 1
fi

# Cleanup
rm -rf "$TEST_DIR"

echo
echo "🎉 Test passed!"
