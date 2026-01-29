#!/bin/bash
# ─────────────────────────────────────────────
# 🕰️ Idempotent RTC policy (localtime mode for dual-boot with Windows)
# See: https://github.com/eg0rmaffin/vapor-rice-i3/issues/53
setup_rtc_policy() {
    echo -e "${CYAN}🕰️ Checking RTC policy (localtime mode)...${RESET}"

    # Read current state using machine-parseable output
    rtc_local=$(timedatectl show --property=LocalRTC --value 2>/dev/null || echo "unknown")
    ntp_active=$(timedatectl show --property=NTP --value 2>/dev/null || echo "unknown")

    # 1️⃣ Set RTC to localtime if not already configured (WITHOUT --adjust-system-clock)
    if [ "$rtc_local" = "yes" ]; then
        echo -e "${GREEN}✅ RTC already in localtime mode${RESET}"
    else
        echo -e "${YELLOW}🔧 Setting RTC to localtime mode...${RESET}"
        # IMPORTANT: Do NOT use --adjust-system-clock here!
        # We only want to change the RTC interpretation policy, not mutate clocks.
        sudo timedatectl set-local-rtc 1
        echo -e "${GREEN}✅ RTC policy set to localtime${RESET}"
    fi

    # 2️⃣ Enable NTP if not already active (for system clock sync)
    if [ "$ntp_active" = "yes" ]; then
        echo -e "${GREEN}✅ NTP already active${RESET}"
    else
        echo -e "${YELLOW}🔧 Enabling NTP...${RESET}"
        sudo timedatectl set-ntp true
        echo -e "${GREEN}✅ NTP enabled${RESET}"
    fi

    # 3️⃣ Auto-healing: only correct time if drift exceeds threshold (5 minutes = 300 seconds)
    local DRIFT_THRESHOLD=300

    # Get RTC time and system time in epoch seconds for comparison
    local rtc_epoch=$(sudo hwclock --get 2>/dev/null | xargs -I{} date -d "{}" +%s 2>/dev/null || echo "0")
    local sys_epoch=$(date +%s)

    if [ "$rtc_epoch" != "0" ] && [ -n "$rtc_epoch" ]; then
        local drift=$((sys_epoch - rtc_epoch))
        # Get absolute value
        if [ "$drift" -lt 0 ]; then
            drift=$((-drift))
        fi

        if [ "$drift" -gt "$DRIFT_THRESHOLD" ]; then
            echo -e "${YELLOW}⚠️ Clock drift detected (${drift}s > ${DRIFT_THRESHOLD}s threshold)${RESET}"
            echo -e "${CYAN}🔧 Syncing system clock from RTC...${RESET}"
            sudo hwclock --hctosys --localtime
            echo -e "${GREEN}✅ System clock synced from RTC${RESET}"
        else
            echo -e "${GREEN}✅ Clock drift within acceptable range (${drift}s)${RESET}"
        fi
    else
        echo -e "${YELLOW}⚠️ Could not read RTC time, skipping drift check${RESET}"
    fi

    echo -e "${GREEN}✅ RTC policy configured (idempotent)${RESET}"
}
