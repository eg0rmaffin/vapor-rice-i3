#!/bin/bash
# ─────────────────────────────────────────────
# 🧠 zram Setup: Declarative zram-based swap configuration
#
# Purpose: Provide a memory pressure buffer to prevent full-system stalls
# under heavy workloads (JVM + browser + hybrid GPU).
#
# Design:
#   - Uses zram-generator for systemd-native, declarative zram management
#   - Idempotent: safe to run multiple times
#   - No disk-backed swap: in-memory compression only
#   - Tuned sysctl: optimized for in-memory swap (higher swappiness)
#
# Architecture:
#   1. zram-generator creates /dev/zram0 at boot via systemd
#   2. Kernel compresses memory pages into zram before OOM
#   3. System remains interactive under pressure instead of stalling
#
# References:
#   - https://wiki.archlinux.org/title/Zram
#   - https://github.com/systemd/zram-generator
# ─────────────────────────────────────────────

# Colors (defined locally for standalone mode, inherited from install.sh when sourced)
: "${GREEN:=\033[0;32m}"
: "${YELLOW:=\033[1;33m}"
: "${CYAN:=\033[0;36m}"
: "${RED:=\033[0;31m}"
: "${RESET:=\033[0m}"

setup_zram() {
    echo -e "${CYAN}🧠 Setting up zram swap...${RESET}"

    # ─── 1. Install zram-generator ───
    # zram-generator is a systemd unit generator that creates zram devices
    # at early boot based on /etc/systemd/zram-generator.conf
    if ! pacman -Q zram-generator &>/dev/null; then
        echo -e "${YELLOW}📦 Installing zram-generator...${RESET}"
        sudo pacman -S --noconfirm --needed zram-generator
    else
        echo -e "${GREEN}✅ zram-generator already installed${RESET}"
    fi

    # ─── 2. Deploy zram configuration ───
    # Create /etc/systemd/zram-generator.conf
    # This is read at early boot by systemd-zram-setup@.service
    local ZRAM_CONF="/etc/systemd/zram-generator.conf"

    echo -e "${CYAN}🔧 Deploying zram configuration...${RESET}"

    # Configuration rationale:
    #   - zram-size = min(ram / 2, 16384): Use half of RAM, max 16GB
    #     For 32GB system: 16GB zram (50% compression ratio = ~32GB effective)
    #   - compression-algorithm = zstd: Best compression ratio, modern systems handle it well
    #   - swap-priority = 100: Higher than any disk-based swap
    sudo tee "$ZRAM_CONF" > /dev/null <<'EOF'
# ─────────────────────────────────────────────
# zram-generator configuration
# Documentation: man zram-generator.conf
#
# This creates /dev/zram0 as compressed RAM swap at boot.
# Size: half of RAM, max 16GB (for 32GB system = 16GB zram)
# ─────────────────────────────────────────────

[zram0]
# Size formula: half of available RAM, capped at 16GB
# For 32GB RAM: min(16384, 16384) = 16GB
zram-size = min(ram / 2, 16384)

# Compression algorithm: zstd provides excellent ratio
# Falls back to kernel default if zstd unavailable
compression-algorithm = zstd

# Swap priority: higher = preferred over disk swap
swap-priority = 100
EOF

    echo -e "${GREEN}✅ zram configuration deployed to $ZRAM_CONF${RESET}"

    # ─── 3. Deploy sysctl tuning for in-memory swap ───
    # These settings optimize the kernel for zram usage
    local SYSCTL_CONF="/etc/sysctl.d/99-vm-zram-parameters.conf"

    echo -e "${CYAN}🔧 Deploying sysctl tuning for zram...${RESET}"

    # Tuning rationale (from Arch Wiki):
    #   - vm.swappiness = 180: High value for in-memory swap (fast access)
    #     Values > 100 are appropriate because zram is orders of magnitude
    #     faster than disk I/O
    #   - vm.watermark_boost_factor = 0: Disable aggressive reclaim boost
    #   - vm.watermark_scale_factor = 125: Allow more kswapd activity before
    #     direct reclaim (smoother performance)
    #   - vm.page-cluster = 0: Read single pages from zram (no prefetch needed)
    sudo tee "$SYSCTL_CONF" > /dev/null <<'EOF'
# ─────────────────────────────────────────────
# Kernel tuning for zram (in-memory compressed swap)
# Documentation: https://wiki.archlinux.org/title/Zram
#
# These settings optimize for fast in-memory swap access.
# ─────────────────────────────────────────────

# Swappiness: Controls how aggressively kernel swaps out pages
# For zram (in-memory): values > 100 make sense because access is fast
# 180 = moderately aggressive swapping to zram
vm.swappiness = 180

# Watermark boost factor: Controls reclaim behavior on allocation bursts
# 0 = disable boost (less aggressive emergency reclaim)
vm.watermark_boost_factor = 0

# Watermark scale factor: Controls when kswapd wakes up
# 125 = wake up earlier, spread reclaim over time (smoother)
vm.watermark_scale_factor = 125

# Page cluster: Number of pages to read at once from swap
# 0 = read single pages (optimal for zram, no disk seek penalty)
vm.page-cluster = 0
EOF

    echo -e "${GREEN}✅ sysctl tuning deployed to $SYSCTL_CONF${RESET}"

    # ─── 4. Apply sysctl settings (if system supports it) ───
    # This makes the settings take effect immediately without reboot
    if command -v sysctl >/dev/null 2>&1; then
        echo -e "${CYAN}🔧 Applying sysctl settings...${RESET}"
        sudo sysctl --system >/dev/null 2>&1 || true
        echo -e "${GREEN}✅ sysctl settings applied${RESET}"
    fi

    # ─── 5. Trigger zram device creation ───
    # The zram-generator creates devices via systemd-zram-setup@.service
    # We need to trigger systemd to pick up the new generator
    echo -e "${CYAN}🔧 Triggering zram device creation...${RESET}"

    # Reload systemd to pick up new generator output
    sudo systemctl daemon-reload

    # Start zram setup service if not already active
    # The service name is systemd-zram-setup@zram0.service
    if systemctl list-unit-files | grep -q 'systemd-zram-setup@'; then
        # Try to start the service (may fail if already running or at boot-only)
        sudo systemctl start systemd-zram-setup@zram0.service 2>/dev/null || true
    fi

    # ─── 6. Verify zram is active ───
    echo -e "${CYAN}🔍 Verifying zram setup...${RESET}"

    # Check if zram device exists
    if [ -b /dev/zram0 ]; then
        echo -e "${GREEN}✅ zram device /dev/zram0 exists${RESET}"

        # Show zram status
        if [ -f /sys/block/zram0/comp_algorithm ]; then
            local algo disksize
            algo=$(cat /sys/block/zram0/comp_algorithm 2>/dev/null | grep -o '\[.*\]' | tr -d '[]')
            disksize=$(cat /sys/block/zram0/disksize 2>/dev/null)
            if [ -n "$disksize" ]; then
                local size_mb=$((disksize / 1024 / 1024))
                echo -e "${GREEN}   Algorithm: $algo, Size: ${size_mb}MB${RESET}"
            fi
        fi

        # Check if swap is active on zram
        if swapon --show=NAME,SIZE 2>/dev/null | grep -q zram; then
            echo -e "${GREEN}✅ zram swap is active${RESET}"
            swapon --show=NAME,SIZE 2>/dev/null | grep zram | while read -r line; do
                echo -e "${GREEN}   $line${RESET}"
            done
        else
            echo -e "${YELLOW}⚠️  zram device exists but swap not activated yet${RESET}"
            echo -e "${YELLOW}   This is normal during install - swap will activate on next boot${RESET}"
        fi
    else
        echo -e "${YELLOW}⚠️  zram device not created yet${RESET}"
        echo -e "${YELLOW}   This is normal during initial setup - device will be created on next boot${RESET}"
        echo -e "${YELLOW}   To verify after reboot: swapon --show${RESET}"
    fi

    echo -e "${GREEN}✅ zram setup complete${RESET}"
    echo -e "${CYAN}   Memory pressure will now trigger compressed swap instead of stalls${RESET}"
}

# ─────────────────────────────────────────────
# 🔍 Diagnostic function: Check zram status
# ─────────────────────────────────────────────
zram_status() {
    echo -e "${CYAN}🧠 zram Status Check${RESET}"
    echo ""

    # Check if zram-generator is installed
    if pacman -Q zram-generator &>/dev/null; then
        echo -e "${GREEN}✅ zram-generator installed${RESET}"
    else
        echo -e "${RED}❌ zram-generator not installed${RESET}"
        return 1
    fi

    # Check configuration files
    if [ -f /etc/systemd/zram-generator.conf ]; then
        echo -e "${GREEN}✅ zram-generator.conf exists${RESET}"
    else
        echo -e "${RED}❌ zram-generator.conf missing${RESET}"
    fi

    if [ -f /etc/sysctl.d/99-vm-zram-parameters.conf ]; then
        echo -e "${GREEN}✅ sysctl tuning exists${RESET}"
    else
        echo -e "${YELLOW}⚠️  sysctl tuning missing${RESET}"
    fi

    # Check zram device
    echo ""
    if [ -b /dev/zram0 ]; then
        echo -e "${GREEN}✅ /dev/zram0 device present${RESET}"

        # Show device stats
        if [ -d /sys/block/zram0 ]; then
            local algo=$(cat /sys/block/zram0/comp_algorithm 2>/dev/null | grep -o '\[.*\]' | tr -d '[]')
            local disksize=$(cat /sys/block/zram0/disksize 2>/dev/null)
            local orig_data=$(cat /sys/block/zram0/orig_data_size 2>/dev/null)
            local compr_data=$(cat /sys/block/zram0/compr_data_size 2>/dev/null)

            echo "   Algorithm: $algo"
            echo "   Disk size: $((disksize / 1024 / 1024))MB"

            if [ "$orig_data" -gt 0 ] 2>/dev/null; then
                local ratio=$((100 * compr_data / orig_data))
                echo "   Compression: ${ratio}% (${orig_data} → ${compr_data})"
            fi
        fi
    else
        echo -e "${YELLOW}⚠️  /dev/zram0 not present (reboot required?)${RESET}"
    fi

    # Check swap status
    echo ""
    echo "Active swap:"
    swapon --show 2>/dev/null || echo "  (none)"

    # Check sysctl values
    echo ""
    echo "Kernel parameters:"
    echo "  vm.swappiness = $(cat /proc/sys/vm/swappiness 2>/dev/null)"
    echo "  vm.page-cluster = $(cat /proc/sys/vm/page-cluster 2>/dev/null)"
}

# Allow running as standalone script for testing
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        status)
            zram_status
            ;;
        *)
            setup_zram
            ;;
    esac
fi
