#!/bin/bash
# Test script for keyboard layout detection logic
# This script tests the logic used in install.sh without actually changing the layout

# Colors
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
RESET="\033[0m"

echo -e "${CYAN}Testing keyboard layout detection logic${RESET}"
echo "========================================"

# Test 1: Simulate having the correct layout
echo -e "\n${CYAN}Test 1: Simulating correct layout (us,ru + grp:alt_shift_toggle)${RESET}"
current_layout="us,ru"
current_options="grp:alt_shift_toggle"

if [[ "$current_layout" == "us,ru" ]] && [[ "$current_options" == *"grp:alt_shift_toggle"* ]]; then
    echo -e "${GREEN}✅ Result: Would SKIP setxkbmap (layout already configured)${RESET}"
else
    echo -e "${YELLOW}⚠️  Result: Would APPLY setxkbmap${RESET}"
fi

# Test 2: Simulate having only US layout
echo -e "\n${CYAN}Test 2: Simulating US-only layout${RESET}"
current_layout="us"
current_options=""

if [[ "$current_layout" == "us,ru" ]] && [[ "$current_options" == *"grp:alt_shift_toggle"* ]]; then
    echo -e "${GREEN}✅ Result: Would SKIP setxkbmap (layout already configured)${RESET}"
else
    echo -e "${YELLOW}⚠️  Result: Would APPLY setxkbmap${RESET}"
fi

# Test 3: Simulate having correct layout but different toggle option
echo -e "\n${CYAN}Test 3: Simulating correct layout with different toggle option${RESET}"
current_layout="us,ru"
current_options="grp:ctrl_shift_toggle"

if [[ "$current_layout" == "us,ru" ]] && [[ "$current_options" == *"grp:alt_shift_toggle"* ]]; then
    echo -e "${GREEN}✅ Result: Would SKIP setxkbmap (layout already configured)${RESET}"
else
    echo -e "${YELLOW}⚠️  Result: Would APPLY setxkbmap${RESET}"
fi

# Test 4: Simulate options with multiple options including the target
echo -e "\n${CYAN}Test 4: Simulating layout with multiple options including target${RESET}"
current_layout="us,ru"
current_options="caps:escape,grp:alt_shift_toggle"

if [[ "$current_layout" == "us,ru" ]] && [[ "$current_options" == *"grp:alt_shift_toggle"* ]]; then
    echo -e "${GREEN}✅ Result: Would SKIP setxkbmap (layout already configured)${RESET}"
else
    echo -e "${YELLOW}⚠️  Result: Would APPLY setxkbmap${RESET}"
fi

# Test 5: Check DISPLAY variable
echo -e "\n${CYAN}Test 5: DISPLAY variable check${RESET}"
if [ -n "$DISPLAY" ]; then
    echo -e "${GREEN}✅ DISPLAY is set: $DISPLAY${RESET}"
else
    echo -e "${YELLOW}⚠️  DISPLAY is not set (no X session)${RESET}"
fi

echo -e "\n${CYAN}All tests completed!${RESET}"
