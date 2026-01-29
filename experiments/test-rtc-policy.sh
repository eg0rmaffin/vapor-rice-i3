#!/bin/bash
# Test script for RTC policy idempotency
# This script demonstrates what the install.sh RTC section does
# WITHOUT actually making changes (dry-run mode by default)

set -e

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
RED="\033[0;31m"
RESET="\033[0m"

DRY_RUN=true
if [ "$1" = "--apply" ]; then
    DRY_RUN=false
    echo -e "${RED}⚠️  Running in APPLY mode - changes will be made!${RESET}"
else
    echo -e "${CYAN}ℹ️  Running in DRY-RUN mode (use --apply to make changes)${RESET}"
fi

echo ""
echo -e "${CYAN}═══════════════════════════════════════${RESET}"
echo -e "${CYAN} RTC Policy Test Script${RESET}"
echo -e "${CYAN}═══════════════════════════════════════${RESET}"
echo ""

# Read current state
echo -e "${CYAN}📊 Current system state:${RESET}"
echo ""
timedatectl
echo ""

rtc_local=$(timedatectl show --property=LocalRTC --value 2>/dev/null || echo "unknown")
ntp_active=$(timedatectl show --property=NTP --value 2>/dev/null || echo "unknown")

echo -e "LocalRTC: ${rtc_local}"
echo -e "NTP: ${ntp_active}"
echo ""

# 1️⃣ Check RTC localtime policy
echo -e "${CYAN}─── Step 1: RTC Localtime Policy ───${RESET}"
if [ "$rtc_local" = "yes" ]; then
    echo -e "${GREEN}✅ RTC already in localtime mode - no action needed${RESET}"
else
    echo -e "${YELLOW}🔧 Would set RTC to localtime mode${RESET}"
    echo -e "   Command: sudo timedatectl set-local-rtc 1"
    echo -e "   (Note: NO --adjust-system-clock flag!)"
    if [ "$DRY_RUN" = false ]; then
        sudo timedatectl set-local-rtc 1
        echo -e "${GREEN}✅ Applied!${RESET}"
    fi
fi
echo ""

# 2️⃣ Check NTP status
echo -e "${CYAN}─── Step 2: NTP Status ───${RESET}"
if [ "$ntp_active" = "yes" ]; then
    echo -e "${GREEN}✅ NTP already active - no action needed${RESET}"
else
    echo -e "${YELLOW}🔧 Would enable NTP${RESET}"
    echo -e "   Command: sudo timedatectl set-ntp true"
    if [ "$DRY_RUN" = false ]; then
        sudo timedatectl set-ntp true
        echo -e "${GREEN}✅ Applied!${RESET}"
    fi
fi
echo ""

# 3️⃣ Check clock drift
echo -e "${CYAN}─── Step 3: Clock Drift Check ───${RESET}"
DRIFT_THRESHOLD=300

rtc_raw=$(sudo hwclock --get 2>/dev/null || echo "")
if [ -n "$rtc_raw" ]; then
    echo -e "RTC time (raw): ${rtc_raw}"
    rtc_epoch=$(echo "$rtc_raw" | xargs -I{} date -d "{}" +%s 2>/dev/null || echo "0")
    sys_epoch=$(date +%s)

    if [ "$rtc_epoch" != "0" ] && [ -n "$rtc_epoch" ]; then
        drift=$((sys_epoch - rtc_epoch))
        abs_drift=$drift
        if [ "$drift" -lt 0 ]; then
            abs_drift=$((-drift))
        fi

        echo -e "RTC epoch: ${rtc_epoch}"
        echo -e "System epoch: ${sys_epoch}"
        echo -e "Drift: ${drift}s (absolute: ${abs_drift}s)"
        echo -e "Threshold: ${DRIFT_THRESHOLD}s"
        echo ""

        if [ "$abs_drift" -gt "$DRIFT_THRESHOLD" ]; then
            echo -e "${YELLOW}⚠️ Drift exceeds threshold!${RESET}"
            echo -e "${YELLOW}🔧 Would sync system clock from RTC${RESET}"
            echo -e "   Command: sudo hwclock --hctosys --localtime"
            if [ "$DRY_RUN" = false ]; then
                sudo hwclock --hctosys --localtime
                echo -e "${GREEN}✅ Applied!${RESET}"
            fi
        else
            echo -e "${GREEN}✅ Clock drift within acceptable range - no action needed${RESET}"
        fi
    else
        echo -e "${YELLOW}⚠️ Could not parse RTC time${RESET}"
    fi
else
    echo -e "${YELLOW}⚠️ Could not read RTC time${RESET}"
fi

echo ""
echo -e "${CYAN}═══════════════════════════════════════${RESET}"
echo -e "${GREEN}✅ Test complete${RESET}"
