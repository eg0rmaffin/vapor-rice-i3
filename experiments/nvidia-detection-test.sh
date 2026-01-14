#!/bin/bash
# Experiment script for testing NVIDIA GPU detection logic
# This script tests the detection of NVIDIA GPU generation and package selection

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
RED="\033[0;31m"
RESET="\033[0m"

echo -e "${CYAN}🔬 NVIDIA GPU Detection Experiment${RESET}"
echo "=================================================="

# Test 1: Check if NVIDIA GPU is present
echo -e "\n${CYAN}Test 1: NVIDIA GPU Detection${RESET}"
if lspci | grep -i 'vga\|3d\|display' | grep -i 'nvidia' &>/dev/null; then
    nvidia_info=$(lspci | grep -i 'vga\|3d\|display' | grep -i 'nvidia')
    echo -e "${GREEN}✅ NVIDIA GPU detected:${RESET}"
    echo "   $nvidia_info"
else
    echo -e "${YELLOW}⚠️ No NVIDIA GPU detected${RESET}"
    echo -e "${YELLOW}This test will simulate detection for demonstration purposes${RESET}"
fi

# Test 2: Detect GPU generation (simulate with various GPU names)
echo -e "\n${CYAN}Test 2: GPU Generation Detection${RESET}"

detect_nvidia_generation() {
    local gpu_info="$1"

    # RTX 40 series (Ada Lovelace) - 2022+
    if echo "$gpu_info" | grep -iE 'RTX 40[0-9]{2}|RTX 4[0-9]{3}' &>/dev/null; then
        echo "ada"
        return
    fi

    # RTX 30 series (Ampere) - 2020+
    if echo "$gpu_info" | grep -iE 'RTX 30[0-9]{2}|RTX 3[0-9]{3}|A[0-9]{2,4}|A100|A40' &>/dev/null; then
        echo "ampere"
        return
    fi

    # RTX 20/GTX 16 series (Turing) - 2018+
    if echo "$gpu_info" | grep -iE 'RTX 20[0-9]{2}|GTX 16[0-9]{2}' &>/dev/null; then
        echo "turing"
        return
    fi

    # GTX 10 series (Pascal) - 2016-2017
    if echo "$gpu_info" | grep -iE 'GTX 10[0-9]{2}|GT 10[0-9]{2}' &>/dev/null; then
        echo "pascal"
        return
    fi

    # GTX 900 series (Maxwell) - 2014-2016
    if echo "$gpu_info" | grep -iE 'GTX 9[0-9]{2}|GTX TITAN X' &>/dev/null; then
        echo "maxwell"
        return
    fi

    # GTX 700/600 series (Kepler) - 2012-2014
    if echo "$gpu_info" | grep -iE 'GTX [67][0-9]{2}|GT [67][0-9]{2}|TITAN' &>/dev/null; then
        echo "kepler"
        return
    fi

    echo "unknown"
}

recommend_packages() {
    local generation="$1"

    case "$generation" in
        ada|ampere)
            echo "nvidia-open-dkms nvidia-utils nvidia-settings lib32-nvidia-utils"
            ;;
        turing)
            echo "nvidia-open-dkms nvidia-utils nvidia-settings lib32-nvidia-utils"
            ;;
        pascal|maxwell|kepler)
            echo "nvidia-580xx-dkms nvidia-580xx-utils nvidia-settings lib32-nvidia-580xx-utils (from AUR)"
            ;;
        *)
            echo "unknown - manual configuration required"
            ;;
    esac
}

# Test with various GPU examples
test_cases=(
    "NVIDIA Corporation GA102 [GeForce RTX 3090]"
    "NVIDIA Corporation TU116 [GeForce GTX 1660 Ti]"
    "NVIDIA Corporation GP107 [GeForce GTX 1050 Ti]"
    "NVIDIA Corporation GM206 [GeForce GTX 960]"
    "NVIDIA Corporation GK107 [GeForce GT 640]"
    "NVIDIA Corporation AD102 [GeForce RTX 4090]"
)

for gpu in "${test_cases[@]}"; do
    generation=$(detect_nvidia_generation "$gpu")
    packages=$(recommend_packages "$generation")
    echo -e "\nGPU: ${CYAN}$gpu${RESET}"
    echo -e "  Generation: ${YELLOW}$generation${RESET}"
    echo -e "  Packages: ${GREEN}$packages${RESET}"
done

# Test 3: Check current kernel version
echo -e "\n${CYAN}Test 3: Kernel Version Check${RESET}"
kernel_version=$(uname -r)
echo -e "Current kernel: ${GREEN}$kernel_version${RESET}"

# Test 4: Check if nvidia modules would be loaded
echo -e "\n${CYAN}Test 4: Check NVIDIA Module Status${RESET}"
if lsmod | grep -i nvidia &>/dev/null; then
    echo -e "${GREEN}✅ NVIDIA kernel modules currently loaded:${RESET}"
    lsmod | grep nvidia
else
    echo -e "${YELLOW}⚠️ No NVIDIA kernel modules currently loaded${RESET}"
fi

# Test 5: Check current Xorg configuration
echo -e "\n${CYAN}Test 5: Current Xorg Configuration${RESET}"
if [ -d /etc/X11/xorg.conf.d ]; then
    echo -e "${GREEN}✅ Xorg config directory exists${RESET}"
    if ls /etc/X11/xorg.conf.d/*nvidia* 2>/dev/null; then
        echo -e "${GREEN}Found NVIDIA-related configs:${RESET}"
        ls -la /etc/X11/xorg.conf.d/*nvidia* 2>/dev/null || true
    else
        echo -e "${YELLOW}⚠️ No NVIDIA-specific Xorg configs found${RESET}"
    fi
else
    echo -e "${YELLOW}⚠️ /etc/X11/xorg.conf.d does not exist${RESET}"
fi

echo -e "\n${GREEN}✅ Experiment completed${RESET}"
