#!/bin/bash
# Test script for kbd-backlight.sh cycle logic

# Test the brightness level detection for different max_brightness values
test_levels() {
    local MAX_BRIGHTNESS=$1
    local levels=()

    # Always include off (0)
    levels+=(0)

    if [ "$MAX_BRIGHTNESS" -eq 1 ]; then
        # Binary on/off only (max=1)
        levels+=($MAX_BRIGHTNESS)
    elif [ "$MAX_BRIGHTNESS" -eq 2 ]; then
        # Three levels: off, low, high
        levels+=(1 2)
    elif [ "$MAX_BRIGHTNESS" -le 4 ]; then
        # Few levels: off, mid, max
        local mid=$((MAX_BRIGHTNESS / 2))
        [ "$mid" -lt 1 ] && mid=1
        levels+=($mid $MAX_BRIGHTNESS)
    else
        # Many levels available: off, low (~33%), high (~66%), max
        local low=$((MAX_BRIGHTNESS / 3))
        local high=$((MAX_BRIGHTNESS * 2 / 3))
        [ "$low" -lt 1 ] && low=1
        [ "$high" -le "$low" ] && high=$((low + 1))
        levels+=($low $high $MAX_BRIGHTNESS)
    fi

    echo "Max=$MAX_BRIGHTNESS: levels=${levels[*]}"
}

# Test cycle behavior
test_cycle() {
    local MAX_BRIGHTNESS=$1
    local levels=()

    # Same logic as above to get levels
    levels+=(0)
    if [ "$MAX_BRIGHTNESS" -eq 1 ]; then
        levels+=($MAX_BRIGHTNESS)
    elif [ "$MAX_BRIGHTNESS" -eq 2 ]; then
        levels+=(1 2)
    elif [ "$MAX_BRIGHTNESS" -le 4 ]; then
        local mid=$((MAX_BRIGHTNESS / 2))
        [ "$mid" -lt 1 ] && mid=1
        levels+=($mid $MAX_BRIGHTNESS)
    else
        local low=$((MAX_BRIGHTNESS / 3))
        local high=$((MAX_BRIGHTNESS * 2 / 3))
        [ "$low" -lt 1 ] && low=1
        [ "$high" -le "$low" ] && high=$((low + 1))
        levels+=($low $high $MAX_BRIGHTNESS)
    fi

    local num_levels=${#levels[@]}
    echo -n "  Cycle: "
    
    local current=0
    for ((c=0; c<num_levels+1; c++)); do
        # Find current position
        local current_idx=0
        for ((i=0; i<num_levels; i++)); do
            if [ "$current" -ge "${levels[$i]}" ]; then
                current_idx=$i
            fi
        done
        
        # Move to next
        local next_idx=$(( (current_idx + 1) % num_levels ))
        local next=${levels[$next_idx]}
        
        echo -n "$current -> "
        current=$next
    done
    echo "(wrap around)"
}

echo "=== Testing declarative brightness level detection ==="
echo ""

echo "--- Binary keyboards (max=1) ---"
test_levels 1
test_cycle 1
echo ""

echo "--- 3-level keyboards (max=2) ---"
test_levels 2
test_cycle 2
echo ""

echo "--- Common laptop keyboards (max=3) ---"
test_levels 3
test_cycle 3
echo ""

echo "--- ASUS/ThinkPad style (max=4) ---"
test_levels 4
test_cycle 4
echo ""

echo "--- Multi-level keyboards (max=5) ---"
test_levels 5
test_cycle 5
echo ""

echo "--- Multi-level keyboards (max=10) ---"
test_levels 10
test_cycle 10
echo ""

echo "--- High-resolution keyboards (max=100) ---"
test_levels 100
test_cycle 100
echo ""

echo "=== All tests complete ==="
