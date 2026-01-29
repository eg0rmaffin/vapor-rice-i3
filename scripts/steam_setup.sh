#!/bin/bash
# scripts/steam_setup.sh
# Declarative Steam setup with hardware-aware GPU launcher generation
# Follows existing project patterns: explicit launchers, no magic, no auto-switching
#
# Convergent behavior:
# - Creates missing launchers when required
# - Removes obsolete/invalid launchers if present
# - Leaves correctly configured launchers untouched
# - Never touches system launcher /usr/share/applications/steam.desktop

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
RESET="\033[0m"

# ──── Convergent Symlink Helper ────
# Creates symlink only if it doesn't exist or points to wrong target
# Returns: 0 if created/updated, 1 if already correct
ensure_symlink() {
    local target="$1"
    local link="$2"
    local description="$3"

    if [ -L "$link" ]; then
        local current_target
        current_target=$(readlink -f "$link")
        local expected_target
        expected_target=$(readlink -f "$target")

        if [ "$current_target" = "$expected_target" ]; then
            echo -e "${GREEN}  ✓ $description (unchanged)${RESET}"
            return 1
        fi
    fi

    ln -sf "$target" "$link"
    echo -e "${GREEN}  + $description (linked)${RESET}"
    return 0
}

# ──── Convergent Removal Helper ────
# Removes file only if it exists
# Returns: 0 if removed, 1 if already absent
ensure_removed() {
    local file="$1"
    local description="$2"

    if [ -e "$file" ] || [ -L "$file" ]; then
        rm -f "$file"
        echo -e "${YELLOW}  - $description (removed)${RESET}"
        return 0
    fi
    return 1
}

# ──── GPU Detection (read-only) ────
detect_nvidia_gpu() {
    lspci | grep -i 'vga\|3d\|display' | grep -qi 'nvidia'
}

detect_amd_dgpu() {
    # Detect discrete AMD GPU (not APU)
    # Look for AMD/ATI GPU that is NOT an integrated APU
    local amd_devices=$(lspci | grep -i 'vga\|3d\|display' | grep -i 'amd\|ati\|radeon')

    if [[ -z "$amd_devices" ]]; then
        return 1
    fi

    # If there's both Intel and AMD, the AMD is likely discrete
    if lspci | grep -i 'vga\|3d\|display' | grep -qi 'intel'; then
        return 0
    fi

    # Check for known discrete AMD GPU patterns (not APUs like Ryzen integrated)
    # This is a heuristic - discrete cards are typically on PCIe bus, not CPU
    if echo "$amd_devices" | grep -qiE 'radeon rx|radeon vii|radeon pro|navi|vega.*[^g]$'; then
        return 0
    fi

    return 1
}

detect_intel_igpu() {
    lspci | grep -i 'vga\|3d\|display' | grep -qi 'intel'
}

detect_amd_igpu() {
    # AMD APU detection (integrated graphics in Ryzen CPUs)
    if lspci | grep -i 'vga\|3d\|display' | grep -qi 'amd\|ati\|radeon'; then
        # If there's only one AMD GPU and no Intel, it might be an APU
        local gpu_count=$(lspci | grep -i 'vga\|3d\|display' | wc -l)
        local amd_count=$(lspci | grep -i 'vga\|3d\|display' | grep -ci 'amd\|ati\|radeon')

        # Single AMD GPU with no Intel suggests APU (Ryzen with Vega/RDNA)
        if [[ "$amd_count" -eq 1 && "$gpu_count" -eq 1 ]]; then
            return 0
        fi
    fi
    return 1
}

# ──── Launcher Management (Convergent) ────
# Manages Steam launchers in ~/.local/share/applications/
# Never touches system launcher /usr/share/applications/steam.desktop
manage_steam_launchers() {
    echo -e "${CYAN}🎮 Managing Steam launchers (convergent)...${RESET}"

    local launchers_dir="$HOME/.local/share/applications"
    local bin_dir="$HOME/.local/bin"
    mkdir -p "$launchers_dir" "$bin_dir"

    local dotfiles_dir="${DOTFILES_DIR:-$HOME/dotfiles}"
    local changes_made=0

    # Always ensure default Steam launcher (uses system default GPU - usually iGPU)
    if [ -f "$dotfiles_dir/steam/steam-default.desktop" ]; then
        ensure_symlink "$dotfiles_dir/steam/steam-default.desktop" \
                       "$launchers_dir/steam-default.desktop" \
                       "Steam (Default GPU) launcher" && ((changes_made++))
    fi

    # NVIDIA launcher - only if NVIDIA hardware is present
    if detect_nvidia_gpu; then
        if [ -f "$dotfiles_dir/steam/steam-nvidia.sh" ]; then
            ensure_symlink "$dotfiles_dir/steam/steam-nvidia.sh" \
                           "$bin_dir/steam-nvidia" \
                           "steam-nvidia script" && ((changes_made++))
        fi
        if [ -f "$dotfiles_dir/steam/steam-nvidia.desktop" ]; then
            ensure_symlink "$dotfiles_dir/steam/steam-nvidia.desktop" \
                           "$launchers_dir/steam-nvidia.desktop" \
                           "Steam (NVIDIA) launcher" && ((changes_made++))
        fi
    else
        # Remove NVIDIA launcher if hardware not present (convergent removal)
        ensure_removed "$bin_dir/steam-nvidia" "steam-nvidia script" && ((changes_made++))
        ensure_removed "$launchers_dir/steam-nvidia.desktop" "Steam (NVIDIA) launcher" && ((changes_made++))
    fi

    # AMD dGPU launcher - only if discrete AMD hardware is present
    if detect_amd_dgpu; then
        if [ -f "$dotfiles_dir/steam/steam-amd-dgpu.sh" ]; then
            ensure_symlink "$dotfiles_dir/steam/steam-amd-dgpu.sh" \
                           "$bin_dir/steam-amd-dgpu" \
                           "steam-amd-dgpu script" && ((changes_made++))
        fi
        if [ -f "$dotfiles_dir/steam/steam-amd-dgpu.desktop" ]; then
            ensure_symlink "$dotfiles_dir/steam/steam-amd-dgpu.desktop" \
                           "$launchers_dir/steam-amd-dgpu.desktop" \
                           "Steam (AMD dGPU) launcher" && ((changes_made++))
        fi
    else
        # Remove AMD dGPU launcher if hardware not present (convergent removal)
        ensure_removed "$bin_dir/steam-amd-dgpu" "steam-amd-dgpu script" && ((changes_made++))
        ensure_removed "$launchers_dir/steam-amd-dgpu.desktop" "Steam (AMD dGPU) launcher" && ((changes_made++))
    fi

    # Update desktop database only if changes were made
    if [ "$changes_made" -gt 0 ]; then
        update-desktop-database "$launchers_dir" 2>/dev/null || true
        echo -e "${CYAN}  Desktop database updated${RESET}"
    fi

    return $changes_made
}

# ──── Main Setup Function ────
setup_steam() {
    echo -e "${CYAN}"
    echo "+-----------------------------------------+"
    echo "|     Steam Setup with GPU Launchers      |"
    echo "+-----------------------------------------+"
    echo -e "${RESET}"

    # Display detected GPU configuration
    echo -e "${CYAN}Detected GPU configuration:${RESET}"

    if detect_intel_igpu; then
        echo -e "  ${GREEN}Intel iGPU${RESET}"
    fi

    if detect_amd_igpu; then
        echo -e "  ${GREEN}AMD APU (integrated)${RESET}"
    fi

    if detect_nvidia_gpu; then
        echo -e "  ${GREEN}NVIDIA discrete GPU${RESET}"
    fi

    if detect_amd_dgpu; then
        echo -e "  ${GREEN}AMD discrete GPU${RESET}"
    fi

    echo ""

    # Manage hardware-aware launchers (convergent)
    manage_steam_launchers
    local changes=$?

    echo ""
    if [ "$changes" -eq 0 ]; then
        echo -e "${GREEN}Steam setup: already converged (no changes needed)${RESET}"
    else
        echo -e "${GREEN}Steam setup: converged ($changes changes made)${RESET}"
    fi

    echo -e "${CYAN}Available launchers in Rofi/application menu:${RESET}"
    echo -e "  - Steam (default system GPU)"

    if detect_nvidia_gpu; then
        echo -e "  - Steam (NVIDIA) - explicit NVIDIA offload"
    fi

    if detect_amd_dgpu; then
        echo -e "  - Steam (AMD dGPU) - explicit AMD discrete GPU"
    fi
}

# ──── Self-Test Mode ────
# Run with --test to verify convergent helper functions
run_self_test() {
    echo -e "${CYAN}Testing convergent helper functions...${RESET}"
    echo ""

    local test_dir
    test_dir=$(mktemp -d)
    trap "rm -rf $test_dir" RETURN

    local passed=0
    local failed=0

    # Create test target
    mkdir -p "$test_dir/dotfiles"
    echo "test content" > "$test_dir/dotfiles/test.desktop"

    # Test 1: Create new symlink
    echo "Test 1: ensure_symlink creates new link"
    ensure_symlink "$test_dir/dotfiles/test.desktop" "$test_dir/link.desktop" "test link" > /dev/null
    if [ $? -eq 0 ] && [ -L "$test_dir/link.desktop" ]; then
        echo -e "  ${GREEN}PASS${RESET}"
        ((passed++))
    else
        echo -e "  ${YELLOW}FAIL${RESET}"
        ((failed++))
    fi

    # Test 2: Existing correct symlink unchanged
    echo "Test 2: ensure_symlink leaves correct link unchanged"
    ensure_symlink "$test_dir/dotfiles/test.desktop" "$test_dir/link.desktop" "test link" > /dev/null
    if [ $? -eq 1 ]; then
        echo -e "  ${GREEN}PASS${RESET}"
        ((passed++))
    else
        echo -e "  ${YELLOW}FAIL${RESET}"
        ((failed++))
    fi

    # Test 3: ensure_removed on non-existent file
    echo "Test 3: ensure_removed on non-existent file"
    ensure_removed "$test_dir/nonexistent.desktop" "nonexistent" > /dev/null
    if [ $? -eq 1 ]; then
        echo -e "  ${GREEN}PASS${RESET}"
        ((passed++))
    else
        echo -e "  ${YELLOW}FAIL${RESET}"
        ((failed++))
    fi

    # Test 4: ensure_removed on existing file
    echo "Test 4: ensure_removed removes existing file"
    touch "$test_dir/to_remove.desktop"
    ensure_removed "$test_dir/to_remove.desktop" "file" > /dev/null
    if [ $? -eq 0 ] && [ ! -e "$test_dir/to_remove.desktop" ]; then
        echo -e "  ${GREEN}PASS${RESET}"
        ((passed++))
    else
        echo -e "  ${YELLOW}FAIL${RESET}"
        ((failed++))
    fi

    echo ""
    echo -e "Results: ${GREEN}$passed passed${RESET}, ${YELLOW}$failed failed${RESET}"

    if [ $failed -eq 0 ]; then
        echo -e "${GREEN}All tests passed!${RESET}"
        return 0
    else
        return 1
    fi
}

# Allow sourcing or direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        --test)
            run_self_test
            ;;
        *)
            setup_steam
            ;;
    esac
fi

export -f setup_steam
