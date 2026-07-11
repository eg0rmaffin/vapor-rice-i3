#!/bin/bash
# ─────────────────────────────────────────────
# 🧠 zram-status.sh - Quick diagnostic for zram swap
#
# Usage: zram-status.sh
#
# Checks:
#   1. zram-generator package installed
#   2. Configuration files present
#   3. zram device active
#   4. Swap status
#   5. Compression statistics
# ─────────────────────────────────────────────

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
RED="\033[0;31m"
RESET="\033[0m"

echo -e "${CYAN}┌────────────────────────────────────────────┐${RESET}"
echo -e "${CYAN}│         🧠 zram Status Check               │${RESET}"
echo -e "${CYAN}└────────────────────────────────────────────┘${RESET}"
echo ""

ERRORS=0

# ─── Check 1: Package ───
echo -e "${CYAN}📦 Package:${RESET}"
if pacman -Q zram-generator &>/dev/null; then
    VERSION=$(pacman -Q zram-generator | awk '{print $2}')
    echo -e "   ${GREEN}✅ zram-generator $VERSION${RESET}"
else
    echo -e "   ${RED}❌ zram-generator not installed${RESET}"
    ERRORS=$((ERRORS + 1))
fi

# ─── Check 2: Configuration ───
echo ""
echo -e "${CYAN}📄 Configuration:${RESET}"
if [ -f /etc/systemd/zram-generator.conf ]; then
    echo -e "   ${GREEN}✅ /etc/systemd/zram-generator.conf${RESET}"
else
    echo -e "   ${RED}❌ /etc/systemd/zram-generator.conf missing${RESET}"
    ERRORS=$((ERRORS + 1))
fi

if [ -f /etc/sysctl.d/99-vm-zram-parameters.conf ]; then
    echo -e "   ${GREEN}✅ /etc/sysctl.d/99-vm-zram-parameters.conf${RESET}"
else
    echo -e "   ${YELLOW}⚠️  /etc/sysctl.d/99-vm-zram-parameters.conf missing${RESET}"
fi

# ─── Check 3: Device ───
echo ""
echo -e "${CYAN}💾 Device:${RESET}"
if [ -b /dev/zram0 ]; then
    echo -e "   ${GREEN}✅ /dev/zram0 present${RESET}"

    # Show device details
    if [ -d /sys/block/zram0 ]; then
        ALGO=$(cat /sys/block/zram0/comp_algorithm 2>/dev/null | grep -o '\[.*\]' | tr -d '[]')
        DISKSIZE=$(cat /sys/block/zram0/disksize 2>/dev/null)
        SIZE_MB=$((DISKSIZE / 1024 / 1024))
        echo -e "   ${GREEN}   Algorithm: $ALGO${RESET}"
        echo -e "   ${GREEN}   Size: ${SIZE_MB}MB${RESET}"
    fi
else
    echo -e "   ${YELLOW}⚠️  /dev/zram0 not present${RESET}"
    echo -e "   ${YELLOW}   (normal before first reboot after install)${RESET}"
fi

# ─── Check 4: Swap ───
echo ""
echo -e "${CYAN}💫 Swap:${RESET}"
if swapon --show=NAME,SIZE 2>/dev/null | grep -q zram; then
    echo -e "   ${GREEN}✅ zram swap active:${RESET}"
    swapon --show=NAME,SIZE,USED,PRIO 2>/dev/null | grep zram | while read -r line; do
        echo -e "   ${GREEN}   $line${RESET}"
    done
else
    SWAP_OUTPUT=$(swapon --show 2>/dev/null)
    if [ -z "$SWAP_OUTPUT" ]; then
        echo -e "   ${YELLOW}⚠️  No swap active${RESET}"
    else
        echo -e "   ${YELLOW}⚠️  Swap active but not zram:${RESET}"
        echo "$SWAP_OUTPUT" | while read -r line; do
            echo -e "   ${YELLOW}   $line${RESET}"
        done
    fi
fi

# ─── Check 5: Compression Stats ───
if [ -b /dev/zram0 ] && [ -d /sys/block/zram0 ]; then
    ORIG_DATA=$(cat /sys/block/zram0/orig_data_size 2>/dev/null || echo 0)
    COMPR_DATA=$(cat /sys/block/zram0/compr_data_size 2>/dev/null || echo 0)

    if [ "$ORIG_DATA" -gt 0 ] 2>/dev/null; then
        echo ""
        echo -e "${CYAN}📊 Compression:${RESET}"
        RATIO=$((100 * COMPR_DATA / ORIG_DATA))
        ORIG_MB=$((ORIG_DATA / 1024 / 1024))
        COMPR_MB=$((COMPR_DATA / 1024 / 1024))
        SAVED_MB=$((ORIG_MB - COMPR_MB))
        echo -e "   ${GREEN}Original: ${ORIG_MB}MB → Compressed: ${COMPR_MB}MB${RESET}"
        echo -e "   ${GREEN}Ratio: ${RATIO}% (saved ${SAVED_MB}MB)${RESET}"
    fi
fi

# ─── Check 6: Kernel Parameters ───
echo ""
echo -e "${CYAN}⚙️  Kernel:${RESET}"
SWAPPINESS=$(cat /proc/sys/vm/swappiness 2>/dev/null)
PAGE_CLUSTER=$(cat /proc/sys/vm/page-cluster 2>/dev/null)

if [ "$SWAPPINESS" -ge 100 ] 2>/dev/null; then
    echo -e "   ${GREEN}✅ vm.swappiness = $SWAPPINESS (optimized for zram)${RESET}"
else
    echo -e "   ${YELLOW}⚠️  vm.swappiness = $SWAPPINESS (consider 180 for zram)${RESET}"
fi

if [ "$PAGE_CLUSTER" -eq 0 ] 2>/dev/null; then
    echo -e "   ${GREEN}✅ vm.page-cluster = $PAGE_CLUSTER (optimized for zram)${RESET}"
else
    echo -e "   ${YELLOW}⚠️  vm.page-cluster = $PAGE_CLUSTER (consider 0 for zram)${RESET}"
fi

# ─── Summary ───
echo ""
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}────────────────────────────────────────────${RESET}"
    echo -e "${GREEN}✅ zram setup OK${RESET}"
    echo -e "${GREEN}────────────────────────────────────────────${RESET}"
else
    echo -e "${YELLOW}────────────────────────────────────────────${RESET}"
    echo -e "${YELLOW}⚠️  $ERRORS issue(s) detected${RESET}"
    echo -e "${YELLOW}   Run: ~/dotfiles/scripts/zram_setup.sh${RESET}"
    echo -e "${YELLOW}────────────────────────────────────────────${RESET}"
fi
