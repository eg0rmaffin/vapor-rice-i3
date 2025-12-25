#!/bin/bash
# Test script to verify Thunar bookmarks configuration

set -e

echo "=== Thunar Bookmarks Test ==="
echo

# Check if bookmarks file exists
if [ -f "gtk-3.0/bookmarks" ]; then
    echo "✅ Bookmarks file exists"
else
    echo "❌ Bookmarks file not found"
    exit 1
fi

# Check file format
echo
echo "📄 Bookmarks content:"
cat gtk-3.0/bookmarks

echo
echo "🔍 Validating format..."

while IFS= read -r line; do
    # Skip empty lines
    [ -z "$line" ] && continue

    # Check if line starts with file://
    if [[ $line == file://* ]]; then
        echo "  ✅ Valid bookmark: $line"
    else
        echo "  ❌ Invalid format: $line"
        exit 1
    fi
done < gtk-3.0/bookmarks

echo
echo "✅ All bookmarks are properly formatted"
echo
echo "📋 Summary:"
echo "   - Total bookmarks: $(grep -c '^file://' gtk-3.0/bookmarks)"
echo "   - Format: GTK bookmarks (compatible with Thunar)"
echo "   - Location: ~/.config/gtk-3.0/bookmarks"
echo
echo "🎉 Test passed!"
