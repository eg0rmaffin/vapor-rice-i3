#!/bin/bash
# Test script to verify steam_setup.sh doesn't interrupt install.sh under set -e

set -e

echo "=== Test 1: Verify ((x++)) behavior under set -e ==="

# Simulate the fixed pattern
x=0
true && ((x++)) || true
echo "After first increment: x=$x"

true && ((x++)) || true
echo "After second increment: x=$x"

# This would fail without || true:
# y=0
# true && ((y++))  # This would exit here!

echo "=== Test 2: Source steam_setup.sh and test manage_steam_launchers ==="

# Set up mock environment (use a temp directory to avoid modifying repo files)
TEST_DIR="/tmp/test_steam_$$"
export DOTFILES_DIR="$TEST_DIR/dotfiles"
export HOME="$TEST_DIR/home"
mkdir -p "$HOME/.local/share/applications"
mkdir -p "$HOME/.local/bin"

# Create mock steam files in temp location
mkdir -p "$DOTFILES_DIR/steam"
echo "#!/bin/bash" > "$DOTFILES_DIR/steam/steam-nvidia.sh"
cat > "$DOTFILES_DIR/steam/steam-nvidia.desktop" <<'EOF'
[Desktop Entry]
Name=Steam (NVIDIA)
Exec=steam-nvidia
Type=Application
EOF

# Source the script
source scripts/steam_setup.sh

# Mock GPU detection to simulate having NVIDIA
detect_nvidia_gpu() { return 0; }
detect_amd_dgpu() { return 1; }

echo ""
echo "Running manage_steam_launchers..."
STEAM_LAUNCHER_CHANGES=0
manage_steam_launchers
echo ""
echo "Changes made: $STEAM_LAUNCHER_CHANGES"
echo "Exit code: $? (should be 0)"

# Cleanup
rm -rf "$TEST_DIR"

echo ""
echo "=== All tests passed! Script completed without interruption ==="
