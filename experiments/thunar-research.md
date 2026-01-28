# Thunar Bookmarks Research

## Configuration Location
Thunar stores bookmarks in: `~/.config/gtk-3.0/bookmarks`

## Format
The bookmarks file follows the GTK bookmarks format:
```
file:///path/to/directory Display Name
```

## Implementation Approach

### Problem with Static File
A static bookmarks file with hardcoded paths like `/home/admin/` doesn't work for other users.

### Solution: Dynamic Generation
Generate the bookmarks file during installation using `$HOME` variable:
- Loop through standard XDG directories
- Check if each directory exists before adding
- Write bookmarks with correct user path

### Code Example
```bash
BOOKMARK_DIRS=("Downloads" "Documents" "Pictures" "Music" "Videos" "Desktop")

> ~/.config/gtk-3.0/bookmarks
for dir in "${BOOKMARK_DIRS[@]}"; do
    if [ -d "$HOME/$dir" ]; then
        echo "file://$HOME/$dir $dir" >> ~/.config/gtk-3.0/bookmarks
    fi
done
```

## Common Popular Directories
- Downloads
- Documents
- Pictures
- Music
- Videos
- Desktop

## References
- Thunar uses GTK+ file chooser bookmarks
- File format: one bookmark per line
- Format: URI followed by optional display name
- XDG user directories: https://wiki.archlinux.org/title/XDG_user_directories
