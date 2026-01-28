#!/bin/bash
# Thunar custom action: Compress files to 7z archive
# Handles filenames with special characters (spaces, quotes, non-ASCII)
#
# Usage: Called by Thunar custom action with %F parameter (multiple files)

set -e

if [[ $# -eq 0 ]]; then
    notify-send "Compress" "No files specified"
    exit 1
fi

# Get the directory from first file
first_file="$1"
dir="$(dirname "$first_file")"
cd "$dir"

# Determine archive name based on selection
if [[ $# -eq 1 ]]; then
    # Single file: use its name
    name="$(basename "$first_file")"
else
    # Multiple files: use parent directory name
    name="$(basename "$dir")"
fi

# Create archive
archive_name="${name}.7z"

# Get list of all file basenames for compression
files_to_compress=()
for f in "$@"; do
    files_to_compress+=("$(basename "$f")")
done

7z a "$archive_name" "${files_to_compress[@]}"

notify-send "Compress" "Created: $archive_name"
