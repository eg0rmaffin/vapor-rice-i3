# Backlight Control Setup Guide

This guide explains how to configure backlight control for various laptop models, including hybrid graphics laptops.

## Overview

The brightness control system supports multiple backlight interfaces with **automatic detection**:

| Interface | Hardware | Works Out of Box |
|-----------|----------|------------------|
| `amdgpu_bl*` | AMD integrated graphics | ✅ Yes |
| `intel_backlight` | Intel integrated graphics | ✅ Yes |
| `nvidia_wmi_ec_backlight` | NVIDIA WMI EC (Lenovo Legion) | ⚠️ May need kernel param |
| `acpi_video*` | Legacy ACPI | ✅ Yes |

## Quick Start

1. **Check available backlight interfaces:**
   ```bash
   ls /sys/class/backlight/
   ```

2. **If you see `amdgpu_bl*` or `intel_backlight`:**
   - Brightness should work automatically
   - Use brightness keys (Fn+F5/F6)

3. **If backlight doesn't work:**
   - Follow the troubleshooting for your specific hardware below

## AMD + NVIDIA Hybrid (Offload Mode)

**This is the most common setup for gaming laptops with AMD CPU and discrete NVIDIA GPU.**

### How It Works

- Primary display: AMD integrated graphics (`amdgpu_bl*`)
- NVIDIA: Used only for specific applications via offload
- Backlight: Controlled by AMD iGPU

### Expected Behavior

```bash
ls /sys/class/backlight/
# Output: amdgpu_bl0  (or similar)
```

**No kernel parameters needed!** The backlight should work automatically because:
- The display is driven by AMD iGPU
- NVIDIA is in offload-only mode (not controlling the display)
- The brightness.sh script auto-detects `amdgpu_bl*`

### If Brightness Doesn't Work

1. **Check what's available:**
   ```bash
   ls /sys/class/backlight/
   ```

2. **If you see `nvidia_0` only:**
   - The NVIDIA driver is incorrectly claiming backlight control
   - Try: `acpi_backlight=native` kernel parameter (see Declarative Setup below)

## Intel + NVIDIA Hybrid (Lenovo Legion, etc.)

### Problem

Some Intel+NVIDIA laptops (like Lenovo Legion) have the backlight controlled by the NVIDIA embedded controller (EC), not the Intel iGPU.

### Symptoms

- `ls /sys/class/backlight/` shows only `nvidia_0`
- Brightness changes but screen doesn't respond
- Or no backlight interface at all

### Solution

Add kernel parameter: `acpi_backlight=nvidia_wmi_ec`

After reboot:
```bash
ls /sys/class/backlight/
# Should show: nvidia_wmi_ec_backlight
```

## Declarative Kernel Parameter Setup

For a more declarative approach, kernel parameters can be managed via a config file:

### Option 1: Kernel command line file (systemd-boot)

```bash
# /boot/loader/entries/arch.conf
options ... acpi_backlight=native
```

### Option 2: GRUB default file

Create `/etc/default/grub.d/backlight.cfg`:
```bash
# Backlight configuration for hybrid laptops
GRUB_CMDLINE_LINUX_DEFAULT="$GRUB_CMDLINE_LINUX_DEFAULT acpi_backlight=native"
```

Then run:
```bash
sudo grub-mkconfig -o /boot/grub/grub.cfg
sudo reboot
```

**Note:** The best value for `acpi_backlight` depends on your hardware:
- `native` - Use native ACPI backlight (works for most AMD laptops)
- `nvidia_wmi_ec` - For Lenovo Legion and similar NVIDIA WMI EC laptops
- `video` - Legacy video mode
- `vendor` - Use vendor-specific interface

### Option 3: Dracut/mkinitcpio kernel parameter

Add to `/etc/dracut.conf.d/backlight.conf` or `/etc/mkinitcpio.conf`:
```bash
kernel_cmdline="acpi_backlight=native"
```

## Permissions Setup

If brightness control requires sudo, add udev rule:

```bash
# /etc/udev/rules.d/90-backlight.rules
ACTION=="add", SUBSYSTEM=="backlight", RUN+="/bin/chgrp video /sys/class/backlight/%k/brightness"
ACTION=="add", SUBSYSTEM=="backlight", RUN+="/bin/chmod g+w /sys/class/backlight/%k/brightness"
```

Then:
```bash
sudo usermod -a -G video $USER
sudo udevadm control --reload-rules
sudo udevadm trigger
# Log out and back in
```

## Testing

1. **Check available interfaces:**
   ```bash
   ls /sys/class/backlight/
   ```

2. **Test brightness control:**
   ```bash
   ~/dotfiles/bin/brightness.sh up
   ~/dotfiles/bin/brightness.sh down
   ```

3. **Test i3 keybindings:**
   - Press `Fn+F5` or `Fn+F6` (or your laptop's brightness keys)
   - Check the status bar for brightness percentage

## Interface Priority

The script selects backlight interface in this order:
1. `nvidia_wmi_ec_backlight` (NVIDIA WMI EC, when available)
2. `intel_backlight` (Intel iGPU)
3. `amdgpu_bl*` (AMD iGPU)
4. `acpi_video*` (Legacy ACPI)

**Excluded interfaces:**
- `ideapad` - Fake interface on some Lenovo IdeaPads
- `nvidia_0` - Doesn't work in hybrid mode

## Troubleshooting

### Brightness keys don't work

Check key names:
```bash
xev | grep XF86
```
Press brightness keys and update i3 config if key names differ.

### Brightness changes but not visible

Wrong interface being used. Check what's available and try different kernel parameters.

### Permission denied

Follow the "Permissions Setup" section.

## References

- [Arch Wiki - Backlight](https://wiki.archlinux.org/title/Backlight)
- [Arch Wiki - NVIDIA Optimus](https://wiki.archlinux.org/title/NVIDIA_Optimus)
- [NVIDIA WMI EC Backlight Driver](https://cateee.net/lkddb/web-lkddb/NVIDIA_WMI_EC_BACKLIGHT.html)
