# 🎮 NVIDIA GPU Support

This rice now includes **declarative NVIDIA support** that automatically detects your NVIDIA GPU and installs the appropriate drivers.

## 🚀 Automatic Installation

The installation script now automatically:

1. **Detects** your NVIDIA GPU model
2. **Determines** the GPU generation (Turing/Ampere/Ada/Blackwell or Pascal/Maxwell/Kepler)
3. **Installs** the correct driver packages:
   - **Modern GPUs** (RTX 20xx+): `nvidia-open-dkms`, `nvidia-utils`, `nvidia-settings`
   - **Legacy GPUs** (GTX 10xx and older): `nvidia-580xx-dkms`, `nvidia-580xx-utils` from AUR
4. **Configures** kernel modules with proper modesetting
5. **Creates** X11 configuration for optimal performance
6. **Sets up** environment variables for both X11 and Wayland

## 📋 Supported GPUs

### Modern GPUs (Open Kernel Modules)
- RTX 50 series (Blackwell) - 2025+
- RTX 40 series (Ada Lovelace) - 2022+
- RTX 30 series (Ampere) - 2020+
- RTX 20 / GTX 16 series (Turing) - 2018+

**Packages**: `nvidia-open-dkms`, `nvidia-utils`, `nvidia-settings`, `lib32-nvidia-utils`

### Legacy GPUs (NVIDIA 580xx)
- GTX 10 series (Pascal) - 2016-2017
- GTX 900 series (Maxwell) - 2014-2016
- GTX 700/600 series (Kepler) - 2012-2014

**Packages**: `nvidia-580xx-dkms`, `nvidia-580xx-utils`, `nvidia-settings`, `lib32-nvidia-580xx-utils` (from AUR)

## 🔧 What Gets Configured

### Kernel Modules
```bash
# /etc/modprobe.d/nvidia.conf
options nvidia-drm modeset=1
options nvidia-drm fbdev=1
```

### Mkinitcpio
NVIDIA modules are added to early boot:
```bash
MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
```

### X11 Configuration
```bash
# /etc/X11/xorg.conf.d/20-nvidia.conf
Section "Device"
    Identifier     "NVIDIA Graphics"
    Driver         "nvidia"
    Option         "NoLogo" "true"
    Option         "TripleBuffer" "true"
    Option         "AccelMethod" "glamor"
    Option         "DRI" "3"
EndSection

Section "Screen"
    Option         "metamodes" "nvidia-auto-select +0+0 {ForceFullCompositionPipeline=On}"
EndSection
```

### Environment Variables

#### For X11 (.xinitrc)
```bash
export __GLX_VENDOR_LIBRARY_NAME=nvidia
export __GL_SHADER_DISK_CACHE=1
export __GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1
```

#### For Wayland (.bash_wayland_env)
```bash
export GBM_BACKEND=nvidia-drm
export __GLX_VENDOR_LIBRARY_NAME=nvidia
export MOZ_ENABLE_WAYLAND=1
export QT_QPA_PLATFORM=wayland
export WLR_NO_HARDWARE_CURSORS=1
```

## 🌊 Wayland/Sway Support

To use Sway with NVIDIA:

1. Uncomment the line in `~/.bash_profile`:
   ```bash
   [ -f "$HOME/.bash_wayland_env" ] && . "$HOME/.bash_wayland_env"
   ```

2. Start Sway from TTY:
   ```bash
   sway
   ```

**Note**: NVIDIA Wayland support requires:
- Driver version 495.44 or newer
- Kernel mode setting enabled (automatically configured)
- `nvidia-drm.modeset=1` kernel parameter (automatically configured)

## 🎯 Manual Installation

If you need to install drivers manually or reinstall them:

```bash
# Run the hardware detection script directly
~/dotfiles/scripts/detect_hardware.sh
```

## 🔍 Testing NVIDIA Detection

You can test the NVIDIA detection logic without installing anything:

```bash
# Run the experiment script
~/dotfiles/experiments/nvidia-detection-test.sh
```

This will show:
- Whether NVIDIA GPU is detected
- GPU generation detection for various models
- Recommended packages for each generation
- Current kernel version
- Current NVIDIA module status

## 🐛 Troubleshooting

### Driver not loading after installation
```bash
# Check if modules are loaded
lsmod | grep nvidia

# If not, load them manually
sudo modprobe nvidia
sudo modprobe nvidia_drm modeset=1

# Reboot to apply all changes
sudo reboot
```

### Black screen after installation
1. Check Xorg logs: `cat /var/log/Xorg.0.log | grep -i nvidia`
2. Try removing custom Xorg config: `sudo rm /etc/X11/xorg.conf.d/20-nvidia.conf`
3. Let Xorg auto-detect: `startx`

### Wayland/Sway not starting
1. Ensure kernel modesetting is enabled: `cat /sys/module/nvidia_drm/parameters/modeset` (should show 'Y')
2. Check Sway logs: `sway --debug 2>&1 | tee ~/sway.log`
3. Verify environment: `echo $GBM_BACKEND` (should show 'nvidia-drm')

### Hybrid Graphics (NVIDIA + Intel/AMD)
The script will warn you about hybrid graphics and skip automatic Xorg configuration. For hybrid setups, consider:
- Using `nvidia-prime` for switching
- Using `optimus-manager` for dynamic switching
- Manual Xorg configuration for your specific setup

## 📚 References

- [Arch Wiki: NVIDIA](https://wiki.archlinux.org/title/NVIDIA)
- [Arch Wiki: NVIDIA Optimus](https://wiki.archlinux.org/title/NVIDIA_Optimus)
- [NVIDIA Wayland Support](https://wiki.archlinux.org/title/Wayland#NVIDIA)

## ⚠️ Important Notes

1. **Reboot required**: After driver installation, you must reboot for changes to take effect
2. **DKMS compilation**: First boot after installation may take longer as DKMS compiles modules
3. **Legacy GPU support**: GTX 10xx and older GPUs require AUR packages (automatically handled by script)
4. **32-bit support**: Automatically installed for gaming and Wine compatibility

## 🎮 Gaming on NVIDIA

All necessary packages for gaming are automatically installed:
- OpenGL and Vulkan support
- 32-bit libraries for Steam and Wine
- Shader cache enabled for better performance
- Variable refresh rate (VRR) support enabled

Just install Steam and start gaming!
