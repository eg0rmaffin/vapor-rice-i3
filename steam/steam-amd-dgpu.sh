#!/bin/bash
# Steam with explicit AMD discrete GPU
# Uses DRI_PRIME for GPU selection on AMD multi-GPU systems
DRI_PRIME=1 \
/usr/bin/steam "$@"
