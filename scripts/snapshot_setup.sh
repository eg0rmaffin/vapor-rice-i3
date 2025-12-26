#!/bin/bash
# scripts/snapshot_setup.sh
# Universal snapshot setup: Timeshift for ext4, Snapper for Btrfs
# Enables system stability through easy rollback capabilities

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
RED="\033[0;31m"
RESET="\033[0m"

# ──── Helper functions ────
check_package() {
    pacman -Q "$1" &>/dev/null
}

install_package() {
    echo -e "${YELLOW}📦 Installing $1...${RESET}"
    sudo pacman -S --noconfirm "$1"
}

install_aur_package() {
    if ! check_package "yay"; then
        echo -e "${YELLOW}⚠️ yay not installed, cannot install AUR package${RESET}"
        return 1
    fi
    echo -e "${YELLOW}📦 Installing $1 from AUR...${RESET}"
    yay -S --noconfirm "$1"
}

# ──── Detect filesystem type ────
detect_filesystem() {
    local root_fs
    root_fs=$(df -T / | awk 'NR==2 {print $2}')
    echo "$root_fs"
}

# ════════════════════════════════════════════════════════════════════
# ████ TIMESHIFT (ext4 and other filesystems) ████
# ════════════════════════════════════════════════════════════════════

install_timeshift_packages() {
    echo -e "${CYAN}📦 Installing Timeshift packages...${RESET}"

    # Core package
    if ! check_package "timeshift"; then
        install_package "timeshift"
    else
        echo -e "${GREEN}✅ timeshift already installed${RESET}"
    fi

    # Cron scheduler (required for scheduled snapshots)
    if ! check_package "cronie"; then
        install_package "cronie"
        sudo systemctl enable --now cronie.service
        echo -e "${GREEN}✅ cronie enabled${RESET}"
    else
        echo -e "${GREEN}✅ cronie already installed${RESET}"
    fi

    # Optional: AUR package for pacman hook auto-snapshots
    if check_package "yay"; then
        if ! check_package "timeshift-autosnap"; then
            echo -e "${CYAN}📦 Installing timeshift-autosnap from AUR (auto-snapshot on pacman)...${RESET}"
            install_aur_package "timeshift-autosnap" || echo -e "${YELLOW}⚠️ timeshift-autosnap not installed, continuing...${RESET}"
        else
            echo -e "${GREEN}✅ timeshift-autosnap already installed${RESET}"
        fi
    fi
}

configure_timeshift() {
    echo -e "${CYAN}🔧 Configuring Timeshift...${RESET}"

    # Create config directory
    sudo mkdir -p /etc/timeshift

    # Find the root device
    local root_device
    root_device=$(df / | awk 'NR==2 {print $1}')
    local root_uuid
    root_uuid=$(lsblk -no UUID "$root_device" 2>/dev/null || echo "")

    # Create basic configuration for rsync mode
    if [ ! -f /etc/timeshift/timeshift.json ]; then
        echo -e "${CYAN}📝 Creating Timeshift configuration...${RESET}"
        sudo tee /etc/timeshift/timeshift.json > /dev/null << EOF
{
  "backup_device_uuid" : "$root_uuid",
  "parent_device_uuid" : "",
  "do_first_run" : "false",
  "btrfs_mode" : "false",
  "include_btrfs_home_for_backup" : "false",
  "include_btrfs_home_for_restore" : "false",
  "stop_cron_emails" : "true",
  "schedule_monthly" : "true",
  "schedule_weekly" : "true",
  "schedule_daily" : "true",
  "schedule_hourly" : "false",
  "schedule_boot" : "true",
  "count_monthly" : "2",
  "count_weekly" : "3",
  "count_daily" : "5",
  "count_hourly" : "0",
  "count_boot" : "3",
  "date_format" : "%Y-%m-%d %H:%M:%S",
  "exclude" : [
    "/home/**",
    "/root/**"
  ],
  "exclude-apps" : []
}
EOF
        echo -e "${GREEN}✅ Timeshift configuration created${RESET}"
        echo -e "${YELLOW}⚠️ Note: Run 'sudo timeshift-gtk' for graphical configuration${RESET}"
    else
        echo -e "${GREEN}✅ Timeshift configuration already exists${RESET}"
    fi

    # Enable cronie for scheduled snapshots
    if systemctl list-unit-files | grep -q "cronie.service"; then
        sudo systemctl enable --now cronie.service
        echo -e "${GREEN}✅ cronie service enabled${RESET}"
    fi
}

print_timeshift_info() {
    echo -e "${CYAN}"
    echo "┌────────────────────────────────────────────────────────────┐"
    echo "│           📸 Timeshift snapshots configured!              │"
    echo "└────────────────────────────────────────────────────────────┘"
    echo -e "${RESET}"
    echo ""
    echo -e "${GREEN}Automatic snapshots:${RESET}"
    echo -e "  • On boot (3 kept)"
    echo -e "  • Daily (5 kept)"
    echo -e "  • Weekly (3 kept)"
    echo -e "  • Monthly (2 kept)"
    if check_package "timeshift-autosnap"; then
        echo -e "  • Before every pacman update (timeshift-autosnap)"
    fi
    echo ""
    echo -e "${GREEN}Available commands:${RESET}"
    echo -e "  ${CYAN}snapshot-create \"description\"${RESET} - create manual snapshot"
    echo -e "  ${CYAN}snapshot-list${RESET}                 - list all snapshots"
    echo -e "  ${CYAN}snapshot-delete${RESET}               - delete a snapshot"
    echo -e "  ${CYAN}snapshot-rollback${RESET}             - show restore instructions"
    echo ""
    echo -e "${GREEN}GUI:${RESET}"
    echo -e "  ${CYAN}sudo timeshift-gtk${RESET}            - graphical interface"
    echo ""
    echo -e "${YELLOW}Note:${RESET} Restore from Live USB: sudo timeshift --restore"
}

setup_timeshift() {
    echo -e "${CYAN}"
    echo "┌────────────────────────────────────────────────────────────┐"
    echo "│      📸 Setting up Timeshift snapshots (rsync mode)       │"
    echo "└────────────────────────────────────────────────────────────┘"
    echo -e "${RESET}"

    install_timeshift_packages
    configure_timeshift
    print_timeshift_info

    echo -e "${GREEN}✅ Timeshift setup complete!${RESET}"
}

# ════════════════════════════════════════════════════════════════════
# ████ SNAPPER (Btrfs only) ████
# ════════════════════════════════════════════════════════════════════

check_btrfs_subvolumes() {
    echo -e "${CYAN}🔍 Checking Btrfs subvolumes...${RESET}"

    local subvols
    subvols=$(sudo btrfs subvolume list / 2>/dev/null)

    if [ -z "$subvols" ]; then
        echo -e "${YELLOW}⚠️ No Btrfs subvolumes detected${RESET}"
        return 1
    fi

    echo -e "${GREEN}✅ Btrfs subvolumes found:${RESET}"
    echo "$subvols" | head -10
    return 0
}

install_snapper_packages() {
    echo -e "${CYAN}📦 Installing Snapper packages...${RESET}"

    local pkgs=(
        snapper
        snap-pac
        grub-btrfs
        inotify-tools
    )

    for pkg in "${pkgs[@]}"; do
        if ! check_package "$pkg"; then
            install_package "$pkg"
        else
            echo -e "${GREEN}✅ $pkg already installed${RESET}"
        fi
    done

    # Optional AUR package
    if check_package "yay"; then
        if ! check_package "snap-pac-grub"; then
            echo -e "${CYAN}📦 Installing snap-pac-grub from AUR...${RESET}"
            install_aur_package "snap-pac-grub" || echo -e "${YELLOW}⚠️ snap-pac-grub not installed, continuing...${RESET}"
        fi
    fi
}

configure_snapper() {
    echo -e "${CYAN}🔧 Configuring Snapper...${RESET}"

    if [ -f /etc/snapper/configs/root ]; then
        echo -e "${GREEN}✅ Snapper root config already exists${RESET}"
        return 0
    fi

    echo -e "${CYAN}📝 Creating Snapper configuration for root...${RESET}"

    if sudo snapper -c root create-config / 2>/dev/null; then
        echo -e "${GREEN}✅ Snapper configuration created${RESET}"
    else
        echo -e "${YELLOW}⚠️ Could not create config automatically${RESET}"
        echo -e "${CYAN}   Manual setup: sudo snapper -c root create-config /${RESET}"
        return 1
    fi

    # Configure retention policy
    sudo sed -i 's/^TIMELINE_LIMIT_HOURLY=.*/TIMELINE_LIMIT_HOURLY="5"/' /etc/snapper/configs/root
    sudo sed -i 's/^TIMELINE_LIMIT_DAILY=.*/TIMELINE_LIMIT_DAILY="7"/' /etc/snapper/configs/root
    sudo sed -i 's/^TIMELINE_LIMIT_WEEKLY=.*/TIMELINE_LIMIT_WEEKLY="4"/' /etc/snapper/configs/root
    sudo sed -i 's/^TIMELINE_LIMIT_MONTHLY=.*/TIMELINE_LIMIT_MONTHLY="6"/' /etc/snapper/configs/root
    sudo sed -i 's/^TIMELINE_LIMIT_YEARLY=.*/TIMELINE_LIMIT_YEARLY="2"/' /etc/snapper/configs/root
    sudo sed -i 's/^TIMELINE_CLEANUP=.*/TIMELINE_CLEANUP="yes"/' /etc/snapper/configs/root

    echo -e "${GREEN}✅ Retention policy configured${RESET}"
}

setup_snapper_timers() {
    echo -e "${CYAN}⏰ Setting up automatic snapshots...${RESET}"

    if systemctl list-unit-files | grep -q "snapper-timeline.timer"; then
        sudo systemctl enable --now snapper-timeline.timer
        echo -e "${GREEN}✅ snapper-timeline timer enabled${RESET}"
    fi

    if systemctl list-unit-files | grep -q "snapper-cleanup.timer"; then
        sudo systemctl enable --now snapper-cleanup.timer
        echo -e "${GREEN}✅ snapper-cleanup timer enabled${RESET}"
    fi

    if systemctl list-unit-files | grep -q "grub-btrfsd.service"; then
        sudo systemctl enable --now grub-btrfsd.service
        echo -e "${GREEN}✅ grub-btrfsd service enabled${RESET}"
    fi
}

print_snapper_info() {
    echo -e "${CYAN}"
    echo "┌────────────────────────────────────────────────────────────┐"
    echo "│            📸 Snapper snapshots configured!               │"
    echo "└────────────────────────────────────────────────────────────┘"
    echo -e "${RESET}"
    echo ""
    echo -e "${GREEN}Automatic snapshots:${RESET}"
    echo -e "  • Before/after every pacman update (snap-pac)"
    echo -e "  • Hourly timeline snapshots"
    echo -e "  • Bootable from GRUB menu"
    echo ""
    echo -e "${GREEN}Available commands:${RESET}"
    echo -e "  ${CYAN}snapshot-create \"description\"${RESET} - create manual snapshot"
    echo -e "  ${CYAN}snapshot-list${RESET}                 - list all snapshots"
    echo -e "  ${CYAN}snapshot-diff 1 5${RESET}             - compare snapshots 1 and 5"
    echo -e "  ${CYAN}snapshot-delete 5${RESET}             - delete snapshot 5"
    echo -e "  ${CYAN}snapshot-rollback${RESET}             - show rollback instructions"
    echo ""
    echo -e "${YELLOW}Note:${RESET} Boot into snapshot via GRUB → 'Arch Linux snapshots'"
}

setup_snapper() {
    echo -e "${CYAN}"
    echo "┌────────────────────────────────────────────────────────────┐"
    echo "│         📸 Setting up Snapper snapshots (Btrfs)           │"
    echo "└────────────────────────────────────────────────────────────┘"
    echo -e "${RESET}"

    check_btrfs_subvolumes
    install_snapper_packages
    configure_snapper
    setup_snapper_timers
    print_snapper_info

    echo -e "${GREEN}✅ Snapper setup complete!${RESET}"
}

# ════════════════════════════════════════════════════════════════════
# ████ MAIN SETUP FUNCTION ████
# ════════════════════════════════════════════════════════════════════

setup_snapshots() {
    echo -e "${CYAN}"
    echo "┌────────────────────────────────────────────────────────────┐"
    echo "│              📸 System Snapshot Setup                     │"
    echo "└────────────────────────────────────────────────────────────┘"
    echo -e "${RESET}"

    local fs_type
    fs_type=$(detect_filesystem)
    echo -e "${CYAN}🔍 Detected filesystem: ${GREEN}$fs_type${RESET}"

    case "$fs_type" in
        btrfs)
            echo -e "${CYAN}   Using Snapper for native Btrfs snapshots${RESET}"
            setup_snapper
            ;;
        ext4|ext3|ext2|xfs|f2fs|*)
            echo -e "${CYAN}   Using Timeshift with rsync for $fs_type${RESET}"
            setup_timeshift
            ;;
    esac

    echo ""
    echo -e "${GREEN}✅ Snapshot setup complete!${RESET}"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_snapshots
fi

export -f setup_snapshots
