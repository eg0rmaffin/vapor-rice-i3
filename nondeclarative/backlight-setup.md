# Backlight Control Setup Guide

This guide explains how to configure backlight control for various laptop models, including NVIDIA hybrid graphics laptops like Lenovo Legion.

## Overview

The brightness control system now supports multiple backlight interfaces with automatic detection:
- `nvidia_wmi_ec_backlight` - For NVIDIA hybrid laptops (Lenovo Legion, etc.)
- `intel_backlight` - For Intel integrated graphics
- `amdgpu_bl*` - For AMD integrated graphics
- `acpi_video*` - Legacy ACPI interface

## Quick Start

1. **Check available backlight interfaces:**
   ```bash
   ls /sys/class/backlight/
   ```

2. **If backlight works:**
   - Use `XF86MonBrightnessUp` and `XF86MonBrightnessDown` keys (Fn+F5/F6 on most laptops)
   - Brightness indicator appears in the status bar

3. **If backlight doesn't work:**
   - Follow the troubleshooting steps below for your specific hardware

## NVIDIA Hybrid Graphics Laptops (Lenovo Legion, etc.)

### Problem

On NVIDIA hybrid laptops, the backlight is physically controlled by the integrated GPU (Intel/AMD), but the system may try to use the NVIDIA interface which doesn't work in hybrid mode.

### Solution 1: Enable nvidia_wmi_ec_backlight (Recommended)

This is the proper solution for NVIDIA hybrid laptops with EC-controlled backlights.

1. **Edit GRUB configuration:**
   ```bash
   sudo nano /etc/default/grub
   ```

2. **Add kernel parameter:**
   ```
   GRUB_CMDLINE_LINUX_DEFAULT="... acpi_backlight=nvidia_wmi_ec"
   ```

3. **Update GRUB:**
   ```bash
   sudo grub-mkconfig -o /boot/grub/grub.cfg
   ```

4. **Reboot:**
   ```bash
   sudo reboot
   ```

5. **Verify:**
   ```bash
   ls /sys/class/backlight/
   # Should show: nvidia_wmi_ec_backlight
   ```

### Solution 2: Use Native ACPI Backlight

If nvidia_wmi_ec doesn't work, try native ACPI:

1. **Edit GRUB configuration:**
   ```bash
   sudo nano /etc/default/grub
   ```

2. **Add kernel parameter:**
   ```
   GRUB_CMDLINE_LINUX_DEFAULT="... acpi_backlight=native"
   ```

3. **Update and reboot:**
   ```bash
   sudo grub-mkconfig -o /boot/grub/grub.cfg
   sudo reboot
   ```

### Solution 3: Try Video Mode

As a last resort:

```
GRUB_CMDLINE_LINUX_DEFAULT="... acpi_backlight=video"
```

## Lenovo IdeaPad Specific Issues

### Lenovo IdeaPad 83DH

This model has a known fake `ideapad` backlight interface that doesn't actually control the display.

**Solution:**
```
GRUB_CMDLINE_LINUX_DEFAULT="... acpi_backlight=native"
```

After reboot, the system will use the proper backlight interface.

## Intel-only Laptops

Usually work out of the box. If not:

```
GRUB_CMDLINE_LINUX_DEFAULT="... acpi_backlight=video"
```

## AMD-only Laptops

Usually work out of the box. If not:

```
GRUB_CMDLINE_LINUX_DEFAULT="... acpi_backlight=vendor"
```

## Permissions Setup

If brightness control requires sudo, add udev rule:

1. **Create udev rule:**
   ```bash
   sudo nano /etc/udev/rules.d/90-backlight.rules
   ```

2. **Add content:**
   ```
   ACTION=="add", SUBSYSTEM=="backlight", RUN+="/bin/chgrp video /sys/class/backlight/%k/brightness"
   ACTION=="add", SUBSYSTEM=="backlight", RUN+="/bin/chmod g+w /sys/class/backlight/%k/brightness"
   ```

3. **Add user to video group:**
   ```bash
   sudo usermod -a -G video $USER
   ```

4. **Reload udev rules:**
   ```bash
   sudo udevadm control --reload-rules
   sudo udevadm trigger
   ```

5. **Log out and back in**

## Testing

After configuration:

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

## Troubleshooting

### Brightness keys don't work

1. Check if your laptop uses different keys:
   ```bash
   xev | grep XF86
   ```
   Press brightness keys and look for the key names.

2. Update i3 config if needed:
   ```bash
   nano ~/dotfiles/i3/config
   # Change XF86MonBrightnessUp/Down to your actual key names
   ```

### Brightness changes but not visible

This means the wrong backlight interface is being used. Try different kernel parameters:
- `acpi_backlight=nvidia_wmi_ec`
- `acpi_backlight=native`
- `acpi_backlight=video`
- `acpi_backlight=vendor`

### Permission denied errors

Follow the "Permissions Setup" section above.

### Multiple backlight interfaces

The script automatically selects the best one based on priority:
1. nvidia_wmi_ec_backlight
2. intel_backlight
3. amdgpu_bl*
4. acpi_video*

To override, edit `~/dotfiles/bin/brightness.sh` and set `BACKLIGHT_DEVICE` manually.

## References

- [Arch Wiki - Backlight](https://wiki.archlinux.org/title/Backlight)
- [NVIDIA WMI EC Backlight Driver](https://cateee.net/lkddb/web-lkddb/NVIDIA_WMI_EC_BACKLIGHT.html)
- [Lenovo Legion Backlight Issues](https://bbs.archlinux.org/viewtopic.php?pid=2279478)
- [NVIDIA Developer Forums - Backlight Control](https://forums.developer.nvidia.com/t/backlight-brightness-control-not-working-on-lenovo-legion-5-pro-16ach6h/176109)

## Files Modified

- `bin/brightness.sh` - Updated to support NVIDIA backlight interfaces
- `i3/config` - Uses include for backlight config
- `i3/includes/backlight.conf` - Declarative backlight keybindings
- `i3blocks/config` - Enabled brightness indicator
- `i3blocks/brightness` - New script to display brightness percentage
