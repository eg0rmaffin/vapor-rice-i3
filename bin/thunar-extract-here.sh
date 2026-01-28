#!/bin/bash
# Thunar custom action: Extract archive to current directory
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

# Get lowercase extension for matching
filename="$(basename "$file")"
ext_lower="${filename,,}"

# Extract based on file extension
case "$ext_lower" in
    *.zip)
        unzip -o "$file"
        ;;
    *.tar.gz|*.tgz)
        tar -xzf "$file"
        ;;
    *.tar.bz2|*.tbz2)
        tar -xjf "$file"
        ;;
    *.tar.xz|*.txz)
        tar -xJf "$file"
        ;;
    *.tar)
        tar -xf "$file"
        ;;
    *.7z)
        7z x "$file"
        ;;
    *.rar)
        7z x "$file"
        ;;
    *)
        notify-send "Extract" "Unsupported archive format: $filename"
        exit 1
        ;;
esac

notify-send "Extract" "Successfully extracted: $filename"
