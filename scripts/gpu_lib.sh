#!/bin/bash
# scripts/gpu_lib.sh
# Общие функции определения видеокарты.
# Решаем по драйверу ядра, который реально взял устройство, а не по названию в lspci:
# "ATI/AMD" в lspci бывает и у современных карт (amdgpu), и у карт до GCN (radeon).

# Печатает драйверы ядра всех видеоустройств DRM (radeon, amdgpu, i915, nouveau, nvidia...)
gpu_kernel_drivers() {
    local dev
    for dev in /sys/class/drm/card[0-9]*/device; do
        [ -e "$dev/driver" ] && basename "$(readlink -f "$dev/driver")"
    done | sort -u
}

# Старая AMD/ATI (до GCN, например Radeon HD 2000–6000): ядро использует radeon, а не amdgpu.
# Таким картам не подходят xf86-video-amdgpu, 20-amdgpu.conf (чёрный экран) и vulkan-radeon.
amd_gpu_is_legacy() {
    local drivers
    drivers=$(gpu_kernel_drivers)
    grep -qx radeon <<< "$drivers" && ! grep -qx amdgpu <<< "$drivers"
}
