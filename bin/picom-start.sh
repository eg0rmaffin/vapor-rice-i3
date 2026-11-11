#!/bin/bash
# Запуск picom под возможности видеокарты.
# На старых AMD/ATI (драйвер radeon) glx-бэкенд с блюром тормозит —
# там берём лёгкий xrender без блюра. Остальным — picom.conf как есть.
source ~/dotfiles/scripts/gpu_lib.sh

CONF="$HOME/.config/picom/picom.conf"

if amd_gpu_is_legacy; then
    exec picom --config "$CONF" --backend xrender --blur-method none
fi

exec picom --config "$CONF"
