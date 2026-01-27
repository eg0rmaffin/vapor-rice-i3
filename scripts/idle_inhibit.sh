#!/bin/bash
# scripts/idle_inhibit.sh
# Declarative X11 idle and DPMS management that respects media playback
#
# Problem: X11's default DPMS/screensaver blanks the screen during media playback
# because it doesn't detect audio/video activity.
#
# Solution: Use xidlehook instead of default X11 idle handling.
# xidlehook has built-in --not-when-audio and --not-when-fullscreen flags
# that properly detect media playback and inhibit screen blanking.
#
# References:
# - https://wiki.archlinux.org/title/Display_Power_Management_Signaling
# - https://github.com/jD91mZM2/xidlehook

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
RED="\033[0;31m"
RESET="\033[0m"

# ─── Configuration ───────────────────────────────────────────────────────────
# All timeouts in seconds
IDLE_DIM_TIMEOUT=${IDLE_DIM_TIMEOUT:-300}       # 5 minutes - dim screen
IDLE_BLANK_TIMEOUT=${IDLE_BLANK_TIMEOUT:-60}    # +1 minute after dim - blank screen
IDLE_SUSPEND_TIMEOUT=${IDLE_SUSPEND_TIMEOUT:-1800}  # +30 minutes after blank - suspend (laptop only)

# Debug mode (set IDLE_DEBUG=1 to enable verbose logging)
IDLE_DEBUG=${IDLE_DEBUG:-0}

# ─── Helper Functions ────────────────────────────────────────────────────────

log_info() {
    echo -e "${CYAN}$1${RESET}"
}

log_success() {
    echo -e "${GREEN}$1${RESET}"
}

log_warn() {
    echo -e "${YELLOW}$1${RESET}"
}

log_error() {
    echo -e "${RED}$1${RESET}"
}

check_package() {
    pacman -Q "$1" &>/dev/null
}

install_package() {
    log_info "Installing $1..."
    sudo pacman -S --noconfirm "$1"
}

install_aur_package() {
    if ! command -v yay &>/dev/null; then
        log_warn "yay not installed, cannot install AUR package $1"
        return 1
    fi
    log_info "Installing $1 from AUR..."
    yay -S --noconfirm "$1"
}

is_laptop() {
    # Check for battery
    if [ -d "/sys/class/power_supply" ]; then
        for supply in /sys/class/power_supply/*; do
            if [ -f "$supply/type" ] && grep -q "Battery" "$supply/type"; then
                return 0
            fi
        done
    fi
    # Check chassis type
    if [ -f "/sys/class/dmi/id/chassis_type" ]; then
        CHASSIS_TYPE=$(cat /sys/class/dmi/id/chassis_type)
        # Laptop chassis types: 8=Portable, 9=Laptop, 10=Notebook, 11=Hand Held, 14=Sub Notebook
        if [[ "$CHASSIS_TYPE" =~ ^(8|9|10|11|14)$ ]]; then
            return 0
        fi
    fi
    return 1
}

get_brightness_backend() {
    # Detect available brightness control backend
    if [ -d "/sys/class/backlight" ]; then
        for backend in /sys/class/backlight/*; do
            if [ -f "$backend/brightness" ]; then
                echo "$(basename "$backend")"
                return 0
            fi
        done
    fi
    return 1
}

# ─── Installation ────────────────────────────────────────────────────────────

install_idle_inhibit_deps() {
    log_info "Installing idle inhibit dependencies..."

    # Core dependency: xidlehook
    if ! check_package "xidlehook"; then
        install_aur_package "xidlehook" || {
            log_error "Failed to install xidlehook"
            return 1
        }
    else
        log_success "xidlehook already installed"
    fi

    # Required for brightness control during dim
    if ! check_package "light"; then
        install_aur_package "light" || log_warn "light not installed - dimming will be skipped"
    else
        log_success "light already installed"
    fi

    # xset for disabling default DPMS
    if ! check_package "xorg-xset"; then
        install_package "xorg-xset"
    else
        log_success "xorg-xset already installed"
    fi

    log_success "Idle inhibit dependencies installed"
}

# ─── DPMS Configuration ──────────────────────────────────────────────────────

disable_default_dpms() {
    # Disable X11's default DPMS and screensaver
    # This must be run AFTER X11 starts (e.g., in .xinitrc or i3 exec)
    log_info "Disabling default X11 DPMS and screensaver..."

    # Disable screen saver
    xset s off
    xset s noblank

    # Disable DPMS (Display Power Management Signaling)
    xset -dpms

    log_success "Default DPMS disabled - xidlehook will manage idle behavior"
}

# ─── xidlehook Management ────────────────────────────────────────────────────

start_xidlehook() {
    # Start xidlehook with media-aware idle detection
    log_info "Starting xidlehook..."

    # Check if already running
    if pgrep -x xidlehook >/dev/null; then
        log_warn "xidlehook is already running"
        return 0
    fi

    # Check if xidlehook is installed
    if ! command -v xidlehook &>/dev/null; then
        log_error "xidlehook not found. Run install_idle_inhibit_deps first."
        return 1
    fi

    # Build the xidlehook command
    local cmd="xidlehook"

    # Core flags: don't trigger idle actions during media playback
    cmd+=" --not-when-fullscreen"  # Don't trigger when any window is fullscreen
    cmd+=" --not-when-audio"       # Don't trigger when audio is playing

    # Detect sleep (for proper suspend handling)
    cmd+=" --detect-sleep"

    # Brightness control for dimming (if available)
    local has_brightness=false
    if command -v light &>/dev/null && get_brightness_backend &>/dev/null; then
        has_brightness=true
    fi

    # Timer 1: Dim screen after IDLE_DIM_TIMEOUT
    if [ "$has_brightness" = true ]; then
        # Save current brightness, then dim to 10%
        cmd+=" --timer $IDLE_DIM_TIMEOUT"
        cmd+=" 'light -O && light -S 10'"  # Save and dim
        cmd+=" 'light -I'"                  # Restore on activity
    fi

    # Timer 2: Blank screen after IDLE_BLANK_TIMEOUT (after dim)
    cmd+=" --timer $IDLE_BLANK_TIMEOUT"
    cmd+=" 'xset dpms force off'"  # Blank screen
    cmd+=" ''"                      # No canceller needed

    # Timer 3: Suspend after IDLE_SUSPEND_TIMEOUT (laptop only)
    if is_laptop; then
        cmd+=" --timer $IDLE_SUSPEND_TIMEOUT"
        cmd+=" 'systemctl suspend'"
        cmd+=" ''"
    fi

    # Debug logging
    if [ "$IDLE_DEBUG" = "1" ]; then
        log_info "xidlehook command: $cmd"
    fi

    # Start xidlehook in background
    eval "$cmd" &

    # Wait briefly and verify it started
    sleep 0.5
    if pgrep -x xidlehook >/dev/null; then
        log_success "xidlehook started successfully"
        log_info "  - Screen will dim after ${IDLE_DIM_TIMEOUT}s of inactivity"
        log_info "  - Screen will blank after additional ${IDLE_BLANK_TIMEOUT}s"
        if is_laptop; then
            log_info "  - System will suspend after additional ${IDLE_SUSPEND_TIMEOUT}s"
        fi
        log_info "  - Idle detection is inhibited during audio playback"
        log_info "  - Idle detection is inhibited when a window is fullscreen"
    else
        log_error "Failed to start xidlehook"
        return 1
    fi
}

stop_xidlehook() {
    log_info "Stopping xidlehook..."
    pkill -x xidlehook && log_success "xidlehook stopped" || log_warn "xidlehook was not running"
}

restart_xidlehook() {
    stop_xidlehook
    sleep 0.5
    start_xidlehook
}

# ─── Status ──────────────────────────────────────────────────────────────────

status_idle_inhibit() {
    echo "=== Idle Inhibit Status ==="
    echo ""

    # xidlehook status
    if pgrep -x xidlehook >/dev/null; then
        echo -e "${GREEN}xidlehook: running${RESET}"
        echo "  PID: $(pgrep -x xidlehook)"
    else
        echo -e "${RED}xidlehook: not running${RESET}"
    fi
    echo ""

    # DPMS status
    echo "DPMS Status:"
    if command -v xset &>/dev/null && [ -n "$DISPLAY" ]; then
        xset q | grep -A 5 "DPMS"
    else
        echo "  Cannot query (no display or xset not available)"
    fi
    echo ""

    # Screensaver status
    echo "Screensaver Status:"
    if command -v xset &>/dev/null && [ -n "$DISPLAY" ]; then
        xset q | grep -A 3 "Screen Saver"
    else
        echo "  Cannot query (no display or xset not available)"
    fi
    echo ""

    # Audio status
    echo "Audio Playing:"
    if command -v pactl &>/dev/null; then
        local playing=$(pactl list sink-inputs 2>/dev/null | grep -c "State: RUNNING")
        if [ "$playing" -gt 0 ]; then
            echo -e "  ${GREEN}Yes ($playing audio stream(s) active)${RESET}"
            echo "  -> xidlehook will NOT trigger idle actions"
        else
            echo "  No active audio streams"
        fi
    else
        echo "  Cannot check (pactl not available)"
    fi
    echo ""

    # Fullscreen status
    echo "Fullscreen Window:"
    if command -v xprop &>/dev/null && [ -n "$DISPLAY" ]; then
        local active_window=$(xprop -root _NET_ACTIVE_WINDOW 2>/dev/null | awk '{print $5}')
        if [ -n "$active_window" ] && [ "$active_window" != "0x0" ]; then
            local is_fullscreen=$(xprop -id "$active_window" _NET_WM_STATE 2>/dev/null | grep -c "_NET_WM_STATE_FULLSCREEN")
            if [ "$is_fullscreen" -gt 0 ]; then
                echo -e "  ${GREEN}Yes (active window is fullscreen)${RESET}"
                echo "  -> xidlehook will NOT trigger idle actions"
            else
                echo "  No fullscreen window active"
            fi
        else
            echo "  No active window"
        fi
    else
        echo "  Cannot check (xprop not available)"
    fi
}

# ─── Setup Function (called from install.sh) ─────────────────────────────────

setup_idle_inhibit() {
    echo -e "${CYAN}"
    echo "+-----------------------------------------+"
    echo "|   Setting up media-aware idle inhibit   |"
    echo "+-----------------------------------------+"
    echo -e "${RESET}"

    # Install dependencies
    install_idle_inhibit_deps || return 1

    log_success "Idle inhibit setup complete!"
    log_info ""
    log_info "How it works:"
    log_info "  1. Default X11 DPMS is disabled (via xset in .xinitrc)"
    log_info "  2. xidlehook manages screen dimming/blanking/suspend"
    log_info "  3. xidlehook's --not-when-audio flag prevents idle"
    log_info "     detection when any application plays audio"
    log_info "  4. xidlehook's --not-when-fullscreen flag prevents"
    log_info "     idle detection when a window is fullscreen"
    log_info ""
    log_info "This means: YouTube, videos, music, etc. will prevent"
    log_info "            your screen from blanking automatically!"
}

# ─── Main ────────────────────────────────────────────────────────────────────

# If script is run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        install|setup)
            setup_idle_inhibit
            ;;
        start)
            disable_default_dpms
            start_xidlehook
            ;;
        stop)
            stop_xidlehook
            ;;
        restart)
            disable_default_dpms
            restart_xidlehook
            ;;
        status)
            status_idle_inhibit
            ;;
        disable-dpms)
            disable_default_dpms
            ;;
        *)
            echo "Usage: $0 {install|start|stop|restart|status|disable-dpms}"
            echo ""
            echo "Commands:"
            echo "  install      Install dependencies (xidlehook, light, xorg-xset)"
            echo "  start        Disable default DPMS and start xidlehook"
            echo "  stop         Stop xidlehook"
            echo "  restart      Restart xidlehook"
            echo "  status       Show current idle inhibit status"
            echo "  disable-dpms Disable default X11 DPMS (use with custom setup)"
            echo ""
            echo "Environment variables:"
            echo "  IDLE_DIM_TIMEOUT     Seconds before dimming (default: 300)"
            echo "  IDLE_BLANK_TIMEOUT   Seconds after dim before blanking (default: 60)"
            echo "  IDLE_SUSPEND_TIMEOUT Seconds after blank before suspend (default: 1800)"
            echo "  IDLE_DEBUG           Set to 1 for verbose output"
            exit 1
            ;;
    esac
fi

# Export functions for use in other scripts
export -f setup_idle_inhibit
export -f disable_default_dpms
export -f start_xidlehook
export -f stop_xidlehook
export -f status_idle_inhibit
