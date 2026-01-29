#!/bin/bash
# Steam with explicit NVIDIA GPU offload
# Uses PRIME render offload - requires NVIDIA drivers installed
__NV_PRIME_RENDER_OFFLOAD=1 \
__GLX_VENDOR_LIBRARY_NAME=nvidia \
__VK_LAYER_NV_optimus=NVIDIA_only \
/usr/bin/steam "$@"
