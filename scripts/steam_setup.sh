#!/bin/bash
# scripts/steam_setup.sh
# Declarative Steam setup with hardware-aware GPU launcher generation
# Follows existing project patterns: explicit launchers, no magic, no auto-switching

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
RESET="\033[0m"

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

# ──── Launcher Creation ────
create_steam_launchers() {
    echo -e "${CYAN}🎮 Creating Steam launchers...${RESET}"

    local launchers_dir="$HOME/.local/share/applications"
    local bin_dir="$HOME/.local/bin"
    mkdir -p "$launchers_dir" "$bin_dir"

    local dotfiles_dir="${DOTFILES_DIR:-$HOME/dotfiles}"

    # Always create default Steam launcher (uses system default GPU - usually iGPU)
    if [ -f "$dotfiles_dir/steam/steam-default.desktop" ]; then
        ln -sf "$dotfiles_dir/steam/steam-default.desktop" "$launchers_dir/steam-default.desktop"
        echo -e "${GREEN}  Steam (Default GPU) launcher linked${RESET}"
    fi

    # NVIDIA launcher - only if NVIDIA hardware is present
    if detect_nvidia_gpu; then
        if [ -f "$dotfiles_dir/steam/steam-nvidia.sh" ]; then
            ln -sf "$dotfiles_dir/steam/steam-nvidia.sh" "$bin_dir/steam-nvidia"
            echo -e "${GREEN}  steam-nvidia script linked${RESET}"
        fi
        if [ -f "$dotfiles_dir/steam/steam-nvidia.desktop" ]; then
            ln -sf "$dotfiles_dir/steam/steam-nvidia.desktop" "$launchers_dir/steam-nvidia.desktop"
            echo -e "${GREEN}  Steam (NVIDIA) launcher linked${RESET}"
        fi
    else
        # Remove NVIDIA launcher if hardware not present
        rm -f "$bin_dir/steam-nvidia" 2>/dev/null
        rm -f "$launchers_dir/steam-nvidia.desktop" 2>/dev/null
        echo -e "${YELLOW}  NVIDIA GPU not detected - skipping NVIDIA launcher${RESET}"
    fi

    # AMD dGPU launcher - only if discrete AMD hardware is present
    if detect_amd_dgpu; then
        if [ -f "$dotfiles_dir/steam/steam-amd-dgpu.sh" ]; then
            ln -sf "$dotfiles_dir/steam/steam-amd-dgpu.sh" "$bin_dir/steam-amd-dgpu"
            echo -e "${GREEN}  steam-amd-dgpu script linked${RESET}"
        fi
        if [ -f "$dotfiles_dir/steam/steam-amd-dgpu.desktop" ]; then
            ln -sf "$dotfiles_dir/steam/steam-amd-dgpu.desktop" "$launchers_dir/steam-amd-dgpu.desktop"
            echo -e "${GREEN}  Steam (AMD dGPU) launcher linked${RESET}"
        fi
    else
        # Remove AMD dGPU launcher if hardware not present
        rm -f "$bin_dir/steam-amd-dgpu" 2>/dev/null
        rm -f "$launchers_dir/steam-amd-dgpu.desktop" 2>/dev/null
        echo -e "${YELLOW}  AMD discrete GPU not detected - skipping AMD dGPU launcher${RESET}"
    fi

    # Update desktop database
    update-desktop-database "$launchers_dir" 2>/dev/null || true
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

    # Create hardware-aware launchers
    create_steam_launchers

    echo -e "${GREEN}Steam setup complete!${RESET}"
    echo -e "${CYAN}Available launchers in Rofi/application menu:${RESET}"
    echo -e "  - Steam (default system GPU)"

    if detect_nvidia_gpu; then
        echo -e "  - Steam (NVIDIA) - explicit NVIDIA offload"
    fi

    if detect_amd_dgpu; then
        echo -e "  - Steam (AMD dGPU) - explicit AMD discrete GPU"
    fi
}

# Allow sourcing or direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_steam
fi

export -f setup_steam
