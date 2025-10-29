#!/bin/bash

# Запускает Firefox в киоске с профилем "vapor" на сайте plaza.one
if ! pgrep -f "firefox.*--class vaporwave" >/dev/null; then
  firefox --no-remote --kiosk --class vaporwave -P vapor https://plaza.one &
fi
