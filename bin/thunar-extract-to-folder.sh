#!/bin/bash
# Thunar custom action: Extract archive to a new folder
# Creates a folder named after the archive and extracts contents there
# Handles filenames with special characters (spaces, quotes, non-ASCII)
#
# Usage: Called by Thunar custom action with %f parameter

set -e

file="$1"

if [[ -z "$file" ]]; then
    notify-send "Extract" "No file specified"
    exit 1
fi

if [[ ! -f "$file" ]]; then
    notify-send "Extract" "File not found: $file"
    exit 1
fi

# Get the directory containing the archive
dir="$(dirname "$file")"
cd "$dir"

# Get filename without path
filename="$(basename "$file")"

# Get filename without extension (strip all extensions like .tar.gz)
name="$filename"
# Remove common archive extensions
name="${name%.tar.gz}"
name="${name%.tar.bz2}"
name="${name%.tar.xz}"
name="${name%.tgz}"
name="${name%.tbz2}"
name="${name%.txz}"
name="${name%.tar}"
name="${name%.zip}"
name="${name%.7z}"
name="${name%.rar}"

# Create target directory
mkdir -p "$name"

# Get lowercase extension for matching
ext_lower="${filename,,}"

# Extract based on file extension
case "$ext_lower" in
    *.zip)
        unzip -o "$file" -d "$name"
        ;;
    *.tar.gz|*.tgz)
        tar -xzf "$file" -C "$name"
        ;;
    *.tar.bz2|*.tbz2)
        tar -xjf "$file" -C "$name"
        ;;
    *.tar.xz|*.txz)
        tar -xJf "$file" -C "$name"
        ;;
    *.tar)
        tar -xf "$file" -C "$name"
        ;;
    *.7z)
        7z x "$file" -o"$name"
        ;;
    *.rar)
        7z x "$file" -o"$name"
        ;;
    *)
        # Clean up empty directory on failure
        rmdir "$name" 2>/dev/null || true
        notify-send "Extract" "Unsupported archive format: $filename"
        exit 1
        ;;
esac

notify-send "Extract" "Extracted to folder: $name"
