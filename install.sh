#!/bin/bash
set -e

# ─────────────────────────────────────────────
# 🎨 Цвета
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
RED="\033[0;31m"
RESET="\033[0m"

# ─────────────────────────────────────────────
# ⏱ Sync cache: skip pacman sync if already done recently
# Override: pass --force-sync or set FORCE_SYNC=1
# NEW: --upgrade flag to force full system upgrade
# NEW: --no-upgrade flag to skip upgrade even when sync is needed
SYNC_COOLDOWN=3600  # seconds (1 hour)
SYNC_STAMP="$HOME/.cache/vapor-rice/last-sync"
UPGRADE_STAMP="$HOME/.cache/vapor-rice/last-upgrade"

FORCE_SYNC=0
FORCE_UPGRADE=0
NO_UPGRADE=0
for arg in "$@"; do
    [[ "$arg" == "--force-sync" ]] && FORCE_SYNC=1
    [[ "$arg" == "--upgrade" ]] && FORCE_UPGRADE=1
    [[ "$arg" == "--no-upgrade" ]] && NO_UPGRADE=1
done

needs_sync() {
    [[ "$FORCE_SYNC" -eq 1 ]] && return 0
    [[ ! -f "$SYNC_STAMP" ]] && return 0
    local last now age
    last=$(cat "$SYNC_STAMP" 2>/dev/null || echo 0)
    now=$(date +%s)
    age=$(( now - last ))
    [[ "$age" -ge "$SYNC_COOLDOWN" ]]
}

mark_synced() {
    mkdir -p "$(dirname "$SYNC_STAMP")"
    date +%s > "$SYNC_STAMP"
}

mark_upgraded() {
    mkdir -p "$(dirname "$UPGRADE_STAMP")"
    date +%s > "$UPGRADE_STAMP"
}

# ─────────────────────────────────────────────
# 🔐 Keyring: OFFLINE-FIRST keyring repair
# This function is ONLY called as a fallback when PGP signature errors occur.
# It does NOT contact keyservers, does NOT use --refresh-keys.
# Fully offline repair using installed archlinux-keyring package.
repair_keyring_offline() {
    echo -e "${YELLOW}🔐 Repairing keyring (offline mode)...${RESET}"

    # Remove broken keyring and reinitialize from installed archlinux-keyring
    sudo rm -rf /etc/pacman.d/gnupg
    sudo pacman-key --init
    sudo pacman-key --populate archlinux

    echo -e "${GREEN}✅ Keyring repaired (offline)${RESET}"
}

# Legacy function for --upgrade flag (explicit user request)
# Only called when user explicitly requests full upgrade
ensure_keyring_for_upgrade() {
    echo -e "${CYAN}🔐 Checking pacman keyring...${RESET}"

    # Check if keyring directory exists
    if [ ! -d /etc/pacman.d/gnupg ]; then
        echo -e "${YELLOW}⚠️  Keyring not initialized, setting up...${RESET}"
        sudo pacman-key --init
        sudo pacman-key --populate archlinux
        echo -e "${GREEN}✅ Keyring initialized${RESET}"
        return 0
    fi

    echo -e "${GREEN}✅ Keyring OK${RESET}"
}

# ─────────────────────────────────────────────
# 🔄 System Upgrade: FALLBACK-ONLY full system upgrade
# IMPORTANT: This is NOT called during normal runs.
# It is ONLY triggered as a fallback when:
#   1. --upgrade flag is explicitly passed
#   2. Dependency conflict detected during package installation
# This makes -Syu a recovery boundary, not a periodic action.
perform_system_upgrade() {
    echo -e "${CYAN}🔄 Running full system upgrade (pacman -Syu)...${RESET}"

    # Ensure keyring is valid before upgrade
    ensure_keyring_for_upgrade

    sudo pacman -Syu --noconfirm
    mark_synced
    mark_upgraded
    echo -e "${GREEN}✅ System upgraded and synced${RESET}"
}

# Check if explicit upgrade was requested via --upgrade flag
check_explicit_upgrade() {
    if [[ "$FORCE_UPGRADE" -eq 1 ]]; then
        echo -e "${CYAN}🔄 Full system upgrade requested (--upgrade flag)${RESET}"
        perform_system_upgrade
        return 0
    fi
    return 1
}

# ─────────────────────────────────────────────
# 🔧 AUR Helper: self-healing yay installation
# Detects libalpm mismatch and auto-rebuilds
ensure_aur_helper() {
    echo -e "${CYAN}🔧 Checking AUR helper (yay)...${RESET}"

    local yay_path
    yay_path=$(command -v yay 2>/dev/null || true)

    # Check if yay exists
    if [ -z "$yay_path" ]; then
        echo -e "${YELLOW}📦 yay not found, installing...${RESET}"
        _install_yay
        return 0
    fi

    # Check if yay works (catches libalpm mismatch)
    if ! yay --version &>/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  yay is broken (likely libalpm mismatch), rebuilding...${RESET}"
        _rebuild_yay
        return 0
    fi

    # Deep check: verify libalpm linkage
    local ldd_output
    ldd_output=$(ldd "$yay_path" 2>&1 || true)
    if echo "$ldd_output" | grep -q "not found"; then
        echo -e "${YELLOW}⚠️  yay has missing library dependencies, rebuilding...${RESET}"
        _rebuild_yay
        return 0
    fi

    echo -e "${GREEN}✅ yay is working${RESET}"
}

_install_yay() {
    local tmp_dir="/tmp/yay-install-$$"
    git clone https://aur.archlinux.org/yay.git "$tmp_dir"
    pushd "$tmp_dir" > /dev/null
    makepkg -si --noconfirm
    popd > /dev/null
    rm -rf "$tmp_dir"
    echo -e "${GREEN}✅ yay installed${RESET}"
}

_rebuild_yay() {
    # Remove broken yay first
    sudo pacman -Rns --noconfirm yay 2>/dev/null || true

    # Rebuild from AUR
    _install_yay
    echo -e "${GREEN}✅ yay rebuilt successfully${RESET}"
}

# ─────────────────────────────────────────────
# 🧩 helper: установка списков пакетов (declarative, idempotent)
# Uses --needed flag for efficient batch installation
# OFFLINE-FIRST: No -Syu unless actual errors occur
# Handles dependency conflicts and PGP errors with fallback recovery
install_list() {
    local -a pkgs=("$@")
    local -a missing=()

    # Filter to only missing packages (for cleaner output)
    for pkg in "${pkgs[@]}"; do
        if ! pacman -Q "$pkg" &>/dev/null; then
            missing+=("$pkg")
        fi
    done

    if [ ${#missing[@]} -eq 0 ]; then
        echo -e "${GREEN}✅ All packages already installed${RESET}"
        return 0
    fi

    echo -e "${YELLOW}📦 Installing ${#missing[@]} packages: ${missing[*]::5}...${RESET}"

    # ─── Explicit Capture Boundary ───────────────────────────────────
    # IMPORTANT: Disable errexit locally to guarantee we always capture
    # both stdout/stderr AND the exit code before any error handling.
    #
    # Under global set -e, command substitution with a failing command
    # may exit the script immediately (shell-dependent behavior), which
    # would prevent:
    #   1. Capturing the exit status
    #   2. Printing diagnostic output
    #   3. Running fallback recovery (keyring repair, system upgrade)
    #
    # This pattern preserves global fail-fast semantics while making
    # install_list() an explicit error-capture boundary.
    # ─────────────────────────────────────────────────────────────────
    local install_output install_status
    set +e
    install_output=$(sudo pacman -S --needed --noconfirm "${pkgs[@]}" 2>&1)
    install_status=$?
    set -e

    if [ $install_status -eq 0 ]; then
        echo -e "${GREEN}✅ Packages installed${RESET}"
        return 0
    fi

    # ─── Error Handling: Fallback Recovery ───
    # Always print the error output first so the user sees what happened
    echo -e "${RED}❌ Package installation failed (exit code $install_status)${RESET}"
    echo -e "${YELLOW}─── pacman output ───${RESET}"
    echo "$install_output"
    echo -e "${YELLOW}─────────────────────${RESET}"

    # Check for PGP signature errors → offline keyring repair
    if echo "$install_output" | grep -qi "invalid or corrupted package (PGP signature)"; then
        echo -e "${YELLOW}⚠️  PGP signature error detected${RESET}"
        echo -e "${CYAN}🔐 Attempting offline keyring repair...${RESET}"

        repair_keyring_offline

        echo -e "${CYAN}📦 Retrying package installation...${RESET}"
        if sudo pacman -S --needed --noconfirm "${pkgs[@]}"; then
            echo -e "${GREEN}✅ Packages installed after keyring repair${RESET}"
            return 0
        else
            echo -e "${RED}❌ Package installation still failed after keyring repair${RESET}"
            return 1
        fi
    fi

    # Check for dependency conflict errors → fallback to -Syu
    if echo "$install_output" | grep -qE "could not satisfy dependencies|breaks dependency"; then
        echo -e "${YELLOW}⚠️  Dependency conflict detected:${RESET}"
        echo "$install_output" | grep -E "(could not satisfy|breaks dependency)" | head -5
        echo ""
        echo -e "${CYAN}🔄 Performing single fallback system upgrade to resolve...${RESET}"

        perform_system_upgrade

        echo -e "${CYAN}📦 Retrying package installation...${RESET}"
        if sudo pacman -S --needed --noconfirm "${pkgs[@]}"; then
            echo -e "${GREEN}✅ Packages installed after system upgrade${RESET}"
            return 0
        else
            echo -e "${RED}❌ Package installation still failed after system upgrade${RESET}"
            echo -e "${RED}Please check the error above and resolve manually.${RESET}"
            return 1
        fi
    fi

    # Unknown error - output already printed above, just fail explicitly
    echo -e "${RED}❌ Unknown error - no automatic recovery available${RESET}"
    echo -e "${RED}Please check the pacman output above and resolve manually.${RESET}"
    return 1
}

# ─────────────────────────────────────────────
# 🚀 Шапка
echo -e "${CYAN}"
echo "┌────────────────────────────────────────────┐"
echo "│        🚀 Installing your dotfiles         │"
echo "└────────────────────────────────────────────┘"
echo -e "${RESET}"

# ─────────────────────────────────────────────
# 🧱 Включаем multilib
MULTILIB_CHANGED=0
if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
    echo -e "${YELLOW}🔧 Добавляем multilib репозиторий...${RESET}"
    sudo sed -i '/#\[multilib\]/,/#Include = \/etc\/pacman.d\/mirrorlist/ s/^#//' /etc/pacman.conf
    MULTILIB_CHANGED=1
    echo -e "${GREEN}✅ multilib репозиторий активирован${RESET}"
else
    echo -e "${GREEN}✅ multilib уже включён${RESET}"
fi

# ─────────────────────────────────────────────
# ─────────────────────────────────────────────
# 🌐 Mirror management (offline-first design)
#
# OFFLINE-FIRST RULE: No implicit system upgrades!
# This section ONLY touches /etc/pacman.d/mirrorlist.
# System upgrades are FALLBACK-ONLY (triggered by actual errors during install).

# Note: multilib enabling no longer forces upgrade. The install_list function
# will handle any dependency conflicts via fallback recovery if needed.

# ─────────────────────────────────────────────
# 🪞 Mirror configuration (separate from pacman sync)
# This ONLY touches /etc/pacman.d/mirrorlist, NOT pacman DB

MIRROR_CACHE="$HOME/.cache/mirrorlist"
CACHE_AGE_DAYS=7

# Helper: test if a mirror URL is reachable (no pacman DB refresh!)
test_mirror_reachable() {
    local mirror_url="$1"
    # Use curl to check if mirror is reachable, NOT pacman -Sy
    curl -sI --connect-timeout 5 --max-time 10 "$mirror_url" >/dev/null 2>&1
}

# Helper: update mirrors via reflector
update_mirrors() {
    echo -e "${CYAN}🔄 Обновляем зеркала через reflector (~1 мин)...${RESET}"

    # Ensure reflector is installed (--needed is idempotent)
    if ! command -v reflector &>/dev/null; then
        echo -e "${YELLOW}📦 Installing reflector...${RESET}"
        sudo pacman -S --needed --noconfirm reflector
    fi

    echo 'Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch' > /tmp/mirrorlist.new

    if sudo reflector \
        --country Russia,Kazakhstan,Germany,Netherlands,Sweden,Finland \
        --protocol https \
        --ipv4 \
        --connection-timeout 15 \
        --download-timeout 15 \
        --latest 10 \
        --sort rate \
        --save /tmp/mirrorlist.reflector 2>/dev/null && \
       grep -q '^Server' /tmp/mirrorlist.reflector; then

        cat /tmp/mirrorlist.reflector >> /tmp/mirrorlist.new
        echo -e "${GREEN}✅ Добавлено $(grep -c '^Server' /tmp/mirrorlist.reflector) зеркал${RESET}"
    else
        echo -e "${YELLOW}⚠️ Reflector не отработал, используем только geo CDN${RESET}"
    fi

    mkdir -p "$(dirname "$MIRROR_CACHE")"
    cp /tmp/mirrorlist.new "$MIRROR_CACHE"
    sudo mv /tmp/mirrorlist.new /etc/pacman.d/mirrorlist
    echo -e "${GREEN}✅ Mirrorlist updated${RESET}"
}

# Check if mirrors need updating (independent of pacman sync)
if [ -f "$MIRROR_CACHE" ] && [ -n "$(find "$MIRROR_CACHE" -mtime -$CACHE_AGE_DAYS 2>/dev/null)" ]; then
    echo -e "${GREEN}✅ Используем закешированные зеркала (<$CACHE_AGE_DAYS дней)${RESET}"
    sudo cp "$MIRROR_CACHE" /etc/pacman.d/mirrorlist

    # Validate mirrors work using curl (NOT pacman -Sy)
    if ! test_mirror_reachable "https://geo.mirror.pkgbuild.com/core/os/x86_64/"; then
        echo -e "${YELLOW}⚠️ Cached mirrors unreachable, refreshing...${RESET}"
        update_mirrors
    fi
else
    # Backup current mirrorlist before updating
    sudo cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak 2>/dev/null || true
    update_mirrors
fi

# ─────────────────────────────────────────────
# 🔄 OFFLINE-FIRST: Only perform explicit upgrade if --upgrade flag was passed
# Normal runs (99% of cases) skip system upgrade entirely for fast, deterministic execution.
# System upgrades are FALLBACK-ONLY: triggered by dependency conflicts or PGP errors during install.
check_explicit_upgrade || true

# ─────────────────────────────────────────────
# 📦 Зависимости pacman
deps=(
	xorg-server
	xorg-xinit
	base-devel
	i3-gaps
	i3blocks
	i3lock  # Screen locker for power-menu
	alacritty
	tmux
	rofi
	feh
	picom
	flameshot
	firefox
	xclip
	pamixer
	noto-fonts
	noto-fonts-cjk
	noto-fonts-emoji
	noto-fonts-extra
	neofetch
	thunar
	thunar-volman
	dbus
	polkit
	tumbler
	gvfs
	gvfs-mtp
	telegram-desktop
	discord
	fd
	htop
	unzip
	zip
	network-manager-applet
	obsidian
	light #определяет яркость
	# Звуковая система
    	pipewire
    	pipewire-pulse
    	pipewire-alsa
    	wireplumber
    	alsa-utils
    	pamixer
    	pavucontrol
    	sof-firmware
	# Note: Microphone processing plugin (noise-suppression-for-voice)
	# is installed SEPARATELY below with graceful error handling.
	# Clean Mic is an optional enhancement — installation failures don't break audio.
	#utils
	cbatticon #battery status icon in system tray
	p7zip
	qbittorrent
	firejail #проверка подозрительных appImage
	xournalpp #доска для рисования
	thunderbird #thunderbird (no comments)
    bind #для сетевых тестов
	playerctl #управление медиаплеерами (MPRIS)
	inotify-tools #keyboard backlight OSD watcher (inotifywait)
    mesa-utils   # OpenGL diagnostics (glxinfo, glxgears)
    glmark2      # GPU benchmark (visual sanity check)
	# ─── Steam & Vulkan stack ───
	steam                 # Steam client (runtime managed by Steam itself)
	vulkan-icd-loader     # Vulkan loader (required for Vulkan games)
	vulkan-tools          # vulkaninfo and other diagnostics
	lib32-vulkan-icd-loader # 32-bit Vulkan loader (required for Proton)
	lib32-mesa            # 32-bit Mesa (required for Steam/Proton on Intel/AMD)
	lib32-libglvnd        # 32-bit GL vendor dispatch (multi-GPU support)
	# ─── Wayland / Sway minimal ───
    	sway
        swaylock
        swayidle
        waybar
    	wl-clipboard
    	grim
    	slurp
    	swappy
    	swaybg             # фон
    	xdg-desktop-portal
        xdg-desktop-portal-wlr
        xdg-desktop-portal-gtk #это x вещь для скриншера вроде
)

# было: явный for-цикл; стало: вызов хелпера
install_list "${deps[@]}"

# ─────────────────────────────────────────────
# 🔧 AUR packages (requires yay)
# Use ensure_aur_helper() to handle broken yay (libalpm mismatch, etc.)
ensure_aur_helper

aur_pkgs=(
    xkb-switch
    light
    xidlehook #media-aware idle detection (prevents screen blanking during video/audio)
    catppuccin-gtk-theme-mocha
    chicago95-icon-theme
    shadowsocks-rust #sslocal для аутлайн протокола впн
    woeusb-ng #типо rufus для прошивки флешек (только iso винды)
    hiddify-next-bin #современный клиент для VLESS+Reality протоколов впн
)

for pkg in "${aur_pkgs[@]}"; do
    if ! yay -Q "$pkg" &>/dev/null; then
        echo -e "${YELLOW}📦 Trying to install $pkg from AUR (with fallback patch)...${RESET}"
        if ! yay -S --noconfirm "$pkg"; then
            echo -e "${CYAN}⚠️  Standard install failed — trying cmake patch for $pkg...${RESET}"
            ~/dotfiles/bin/cmake-patch.sh "$pkg"
        fi
    else
        echo -e "${GREEN}✅ $pkg already installed${RESET}"
    fi
done

# ─────────────────────────────────────────────
# 🧰 VirtualBox support

vbox_pkgs=(
    virtualbox
    virtualbox-host-dkms
    dkms
    linux-headers
    virtualbox-guest-iso
)

echo -e "${CYAN}📦 Installing VirtualBox and modules...${RESET}"
# было: второй явный for-цикл; стало: тот же хелпер
install_list "${vbox_pkgs[@]}"

if ! lsmod | grep -q '^vboxdrv'; then
    echo -e "${CYAN}📦 Loading vboxdrv module...${RESET}"
    sudo modprobe vboxdrv || echo -e "${YELLOW}⚠️ Не удалось загрузить vboxdrv — возможно, нужно перезагрузить систему${RESET}"
else
    echo -e "${GREEN}✅ vboxdrv already loaded${RESET}"
fi

echo -e "${CYAN}👤 Добавляем пользователя в группу vboxusers...${RESET}"
sudo usermod -aG vboxusers "$USER"

# ─────────────────────────────────────────────
# 🔗 Симлинки
echo -e "${CYAN}🔗 Creating symlinks...${RESET}"

ln -sf ~/dotfiles/.xinitrc ~/.xinitrc

# Удалим старый конфиг, чтобы точно не было коллизий
rm -rf ~/.config/i3
mkdir -p ~/.config
ln -s ~/dotfiles/i3 ~/.config/i3

# 🧩 Bash config
echo -e "${CYAN}🔧 Linking .bashrc & .bash_profile...${RESET}"
ln -sf ~/dotfiles/bash/.bashrc ~/.bashrc
ln -sf ~/dotfiles/bash/.bash_profile ~/.bash_profile
echo -e "${GREEN}✅ bash configs linked${RESET}"

# 🧩 Конфиг picom
echo -e "${CYAN}🔧 Setting up picom...${RESET}"
mkdir -p ~/.config/picom
ln -sf ~/dotfiles/picom/picom.conf ~/.config/picom/picom.conf
echo -e "${GREEN}✅ picom config linked${RESET}"

# 🧩 GTK 3.0 settings
echo -e "${CYAN}🔧 Linking GTK 3.0 settings...${RESET}"
mkdir -p ~/.config/gtk-3.0
ln -sf ~/dotfiles/gtk-3.0/settings.ini ~/.config/gtk-3.0/settings.ini

# ─────────────────────────────────────────────
# 📁 XDG-папки + иконки + закладки Thunar
echo -e "${CYAN}📁 Setting up XDG directories...${RESET}"
XDG_USER_DIRS=("Downloads" "Documents" "Pictures" "Music" "Videos")
for dir in "${XDG_USER_DIRS[@]}"; do
    mkdir -p "$HOME/$dir"
done
echo -e "${GREEN}✅ XDG directories ready${RESET}"

# user-dirs.dirs — Thunar uses this to show folder icons
mkdir -p ~/.config
cat > ~/.config/user-dirs.dirs << 'EOF'
XDG_DOWNLOAD_DIR="$HOME/Downloads"
XDG_DOCUMENTS_DIR="$HOME/Documents"
XDG_PICTURES_DIR="$HOME/Pictures"
XDG_MUSIC_DIR="$HOME/Music"
XDG_VIDEOS_DIR="$HOME/Videos"
EOF
echo -e "${GREEN}✅ XDG user-dirs.dirs written${RESET}"

# Thunar bookmarks
_bookmarks=""
for dir in "${XDG_USER_DIRS[@]}"; do
    _bookmarks+="file://$HOME/$dir $dir"$'\n'
done
printf '%s' "$_bookmarks" > ~/.config/gtk-3.0/bookmarks
echo -e "${GREEN}✅ Thunar bookmarks written${RESET}"

# 🧩 Alacritty
echo -e "${CYAN}🔧 Linking Alacritty config...${RESET}"
mkdir -p ~/.config/alacritty
ln -sf ~/dotfiles/alacritty/alacritty.toml ~/.config/alacritty/alacritty.toml
echo -e "${GREEN}✅ Alacritty config linked${RESET}"

# 🧩 tmux конфиг
echo -e "${CYAN}🔧 Setting up tmux config...${RESET}"
mkdir -p ~/.config/tmux
ln -sf ~/dotfiles/tmux/.tmux.conf ~/.tmux.conf
echo -e "${GREEN}✅ tmux config linked${RESET}"

# 🧩 i3blocks config
echo -e "${CYAN}🔧 Linking i3blocks config...${RESET}"
mkdir -p ~/.config/i3blocks
ln -sf ~/dotfiles/i3blocks/config ~/.config/i3blocks/config
echo -e "${GREEN}✅ i3blocks config linked${RESET}"

# 🧩 Thunar custom actions for archive handling
# Uses external scripts instead of inline commands for robust special character handling
echo -e "${CYAN}🔧 Setting up Thunar custom actions...${RESET}"
mkdir -p ~/.config/Thunar
ln -sf ~/dotfiles/thunar/uca.xml ~/.config/Thunar/uca.xml

# Link Thunar archive helper scripts
mkdir -p ~/.local/bin
ln -sf ~/dotfiles/bin/thunar-extract-here.sh ~/.local/bin/thunar-extract-here.sh
ln -sf ~/dotfiles/bin/thunar-extract-to-folder.sh ~/.local/bin/thunar-extract-to-folder.sh
ln -sf ~/dotfiles/bin/thunar-compress-zip.sh ~/.local/bin/thunar-compress-zip.sh
ln -sf ~/dotfiles/bin/thunar-compress-7z.sh ~/.local/bin/thunar-compress-7z.sh
echo -e "${GREEN}✅ Thunar custom actions linked${RESET}"

# 🧩 Vim config
echo -e "${CYAN}🔧 Linking Vim config...${RESET}"
ln -sf ~/dotfiles/vim/.vimrc ~/.vimrc
echo -e "${GREEN}✅ Vim config linked${RESET}"

# 🧩 Git config (vim as editor)
echo -e "${CYAN}🔧 Linking Git config...${RESET}"
ln -sf ~/dotfiles/git/.gitconfig ~/.gitconfig
echo -e "${GREEN}✅ Git config linked${RESET}"

# 🧩 Rofi config
echo -e "${CYAN}🔧 Linking Rofi config...${RESET}"
mkdir -p ~/.config/rofi
ln -sf ~/dotfiles/rofi/config.rasi ~/.config/rofi/config.rasi
echo -e "${GREEN}✅ Rofi config linked${RESET}"

# 🟣 Discord Proxy
echo -e "${CYAN}🔧 Linking Discord Proxy...${RESET}"

mkdir -p ~/.local/bin
ln -sf ~/dotfiles/discord/discord-proxy.sh ~/.local/bin/discord-proxy

mkdir -p ~/.local/share/applications
ln -sf ~/dotfiles/discord/discord-proxy.desktop ~/.local/share/applications/discord-proxy.desktop

# опционально, чтобы меню обновилось
update-desktop-database ~/.local/share/applications 2>/dev/null || true

echo -e "${GREEN}✅ Discord Proxy linked${RESET}"


echo -e "${GREEN}✅ All symlinks created${RESET}"

# ─────────────────────────────────────────────
# 🖼 Обои (только если в X сессии)
if [ -n "$DISPLAY" ] && [ -f ~/dotfiles/wallpapers/default.jpg ]; then
    echo -e "${CYAN}🖼 Setting wallpaper...${RESET}"
    feh --bg-scale ~/dotfiles/wallpapers/default.jpg
else
    echo -e "${YELLOW}⚠️  Skipping wallpaper — either not in X or file missing${RESET}"
fi

# 🔗 vapor-radio
echo -e "${CYAN}🎶 Linking vapor-radio...${RESET}"
mkdir -p ~/.local/bin
ln -sf ~/dotfiles/bin/vapor-radio.sh ~/.local/bin/vapor-radio.sh
echo -e "${GREEN}✅ vapor-radio linked to ~/.local/bin${RESET}"

# ─────────────────────────────────────────────
# 🛠 Добавляем ~/.local/bin в PATH (если не добавлен)
echo -e "${CYAN}🔧 Ensuring ~/.local/bin is in PATH...${RESET}"

mkdir -p ~/.local/bin

if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' ~/.bashrc; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    echo -e "${GREEN}✅ PATH updated in ~/.bashrc${RESET}"
else
    echo -e "${GREEN}✅ ~/.local/bin already in PATH${RESET}"
fi

# ─── Natural Scrolling ──────
TOUCHPAD_ID=$(xinput list | grep -iE 'touchpad' | grep -o 'id=[0-9]\+' | cut -d= -f2)
if [ -n "$TOUCHPAD_ID" ]; then
    xinput set-prop "$TOUCHPAD_ID" "libinput Natural Scrolling Enabled" 1
fi

# Добавим пользователя в группу video
sudo usermod -aG video "$USER"

echo -e "${GREEN}✅ Udev rule written to $UDEV_RULE${RESET}"


# ─── 🌐 Локали ────────
LOCALE_CHANGED=0
if ! grep -q '^en_US.UTF-8 UTF-8' /etc/locale.gen; then
    sudo sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
    LOCALE_CHANGED=1
fi
if ! grep -q '^ru_RU.UTF-8 UTF-8' /etc/locale.gen; then
    sudo sed -i 's/^#ru_RU.UTF-8 UTF-8/ru_RU.UTF-8 UTF-8/' /etc/locale.gen
    LOCALE_CHANGED=1
fi

if [[ "$LOCALE_CHANGED" -eq 1 ]] || ! locale -a 2>/dev/null | grep -q 'en_US.utf8'; then
    sudo locale-gen
    echo -e "${GREEN}✅ Локали сгенерированы${RESET}"
else
    echo -e "${GREEN}✅ Локали уже настроены${RESET}"
fi

echo 'LANG=en_US.UTF-8' | sudo tee /etc/locale.conf > /dev/null
echo 'KEYMAP=us' | sudo tee /etc/vconsole.conf > /dev/null


# Активируем службы systemd для звука (после установки пакетов)
echo -e "${CYAN}🔧 Активация служб PipeWire...${RESET}"
for service in pipewire.service pipewire-pulse.service wireplumber.service; do
    if systemctl --user list-unit-files | grep -q "$service"; then
        systemctl --user enable "$service" 2>/dev/null || true
        systemctl --user start "$service" 2>/dev/null || true
        echo -e "${GREEN}✅ Служба $service настроена${RESET}"
    else
        echo -e "${YELLOW}⚠️ Служба $service не найдена, пропускаем${RESET}"
    fi
done

# ─── 🎙 Microphone enhancement: Clean Mic RNNoise plugin (OPTIONAL) ───
# This plugin enables the Clean Mic filter-chain:
#   - noise-suppression-for-voice: RNNoise for background noise removal
#
# NOTE: Limiter (swh-plugins) removed for version-tolerance.
#   The fast_lookahead_limiter uses port names that vary between PipeWire versions,
#   causing filter-chain failures on PipeWire 1.4.x. RNNoise alone provides the
#   primary value (noise reduction) and is stable across all PipeWire versions.
#
# IMPORTANT: This is NON-FATAL. Clean Mic is an optional enhancement layer.
# If plugin fails to install due to dependency conflicts:
#   - PipeWire will still start (thanks to 'nofail' flag in 60-clean-mic.conf)
#   - All other audio functionality continues to work
#   - Only the noise-suppression feature is unavailable
#
# The user can retry installation after a full system update:
#   sudo pacman -Syu && sudo pacman -S noise-suppression-for-voice
echo -e "${CYAN}🎙 Installing Clean Mic plugin (RNNoise)...${RESET}"

CLEAN_MIC_OK=1

# Install RNNoise (noise suppression)
echo -e "${CYAN}📦 Installing noise-suppression-for-voice...${RESET}"
if install_list noise-suppression-for-voice; then
    echo -e "${GREEN}✅ RNNoise installed${RESET}"
else
    echo -e "${YELLOW}⚠️  noise-suppression-for-voice failed to install${RESET}"
    CLEAN_MIC_OK=0
fi

# Report Clean Mic status
if [ "$CLEAN_MIC_OK" -eq 1 ]; then
    echo -e "${GREEN}✅ Clean Mic dependency ready (RNNoise)${RESET}"
else
    echo -e "${YELLOW}⚠️  Clean Mic plugin failed to install (dependency conflict?)${RESET}"
    echo -e "${YELLOW}   Clean Mic feature will be unavailable until dependency resolves.${RESET}"
    echo -e "${YELLOW}   Try: sudo pacman -Syu && sudo pacman -S noise-suppression-for-voice${RESET}"
    echo -e "${YELLOW}   Note: Audio baseline (output + routing) will still work normally.${RESET}"
fi

# ─── 🎧 Deterministic audio policy (Windows-like) ───
source ~/dotfiles/scripts/audio_policy.sh
setup_audio_policy

# ─── 🎨 Appearance policy (dark mode for browsers / portal / electron) ───
if command -v gsettings >/dev/null && [ -n "$DBUS_SESSION_BUS_ADDRESS" ]; then
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
else
  echo -e "${YELLOW}⚠️ Skipping gsettings (no DBus session)${RESET}"
fi

# ─────────────────────────────────────────────
# 🔵 Bluetooth
echo -e "${CYAN}🔧 Настраиваем Bluetooth...${RESET}"
install_list bluez bluez-utils blueman
sudo systemctl enable bluetooth.service
sudo systemctl start bluetooth.service
echo -e "${GREEN}✅ Bluetooth установлен${RESET}"


# ─── 🟣 Notifications / OSD ─────────────────────────────
echo -e "${CYAN}🔧 Setting up notification daemon (dunst)...${RESET}"
install_list dunst libnotify pamixer

mkdir -p ~/.config/dunst
ln -sf ~/dotfiles/dunst/dunstrc ~/.config/dunst/dunstrc
echo -e "${GREEN}✅ dunst config linked${RESET}"

systemctl --user enable --now dunst.service 2>/dev/null || true

# 🔗 OSD scripts (dunst panel support for volume and keyboard backlight)
echo -e "${CYAN}🔧 Linking OSD scripts...${RESET}"
mkdir -p ~/.local/bin
ln -sf ~/dotfiles/scripts/osd/osd-panel.sh ~/.local/bin/osd-panel.sh
ln -sf ~/dotfiles/scripts/osd/volume.sh ~/.local/bin/volume.sh
ln -sf ~/dotfiles/scripts/osd/kbd-backlight.sh ~/.local/bin/kbd-backlight-osd.sh
ln -sf ~/dotfiles/bin/audio-policy-check.sh ~/.local/bin/audio-policy-check.sh
ln -sf ~/dotfiles/bin/audio-ensure-default.sh ~/.local/bin/audio-ensure-default.sh
ln -sf ~/dotfiles/bin/clean-mic-status.sh ~/.local/bin/clean-mic-status.sh
echo -e "${GREEN}✅ OSD scripts linked (volume, keyboard backlight, audio-policy-check, audio-ensure-default, clean-mic-status)${RESET}"

# ⚡ Power menu (Win95 vaporwave style)
echo -e "${CYAN}⚡ Linking power-menu...${RESET}"
mkdir -p ~/.config/rofi
ln -sf ~/dotfiles/rofi/power-menu.rasi ~/.config/rofi/power-menu.rasi
ln -sf ~/dotfiles/bin/power-menu.sh ~/.local/bin/power-menu.sh
echo -e "${GREEN}✅ power-menu linked${RESET}"

# ─── 💡 Keyboard Backlight Support ──────
echo -e "${CYAN}💡 Setting up keyboard backlight support...${RESET}"
mkdir -p ~/.local/bin
ln -sf ~/dotfiles/bin/kbd-backlight.sh ~/.local/bin/kbd-backlight.sh
ln -sf ~/dotfiles/bin/kbd-backlight-watcher.sh ~/.local/bin/kbd-backlight-watcher.sh
echo -e "${GREEN}✅ kbd-backlight.sh linked${RESET}"

# Create udev rule for keyboard backlight permissions
KBD_UDEV_RULE="/etc/udev/rules.d/90-kbd-backlight.rules"
if [ ! -f "$KBD_UDEV_RULE" ]; then
    echo -e "${CYAN}🔧 Creating udev rule for keyboard backlight...${RESET}"
    sudo tee "$KBD_UDEV_RULE" > /dev/null <<'EOF'
# Allow users in video group to control keyboard backlight
ACTION=="add", SUBSYSTEM=="leds", KERNEL=="*kbd*", RUN+="/bin/chmod g+w /sys/class/leds/%k/brightness", RUN+="/bin/chgrp video /sys/class/leds/%k/brightness"
ACTION=="add", SUBSYSTEM=="leds", KERNEL=="*kbd*", RUN+="/bin/chmod g+w /sys/class/leds/%k/brightness_hw_changed", RUN+="/bin/chgrp video /sys/class/leds/%k/brightness_hw_changed"
EOF
    sudo udevadm control --reload-rules
    echo -e "${GREEN}✅ Keyboard backlight udev rule created${RESET}"
else
    echo -e "${GREEN}✅ Keyboard backlight udev rule already exists${RESET}"
fi

# Setup keyboard backlight watcher systemd service (for OSD notifications on Fn+Space)
echo -e "${CYAN}🔧 Setting up keyboard backlight watcher service...${RESET}"
mkdir -p ~/.config/systemd/user
ln -sf ~/dotfiles/systemd/kbd-backlight-watcher.service ~/.config/systemd/user/kbd-backlight-watcher.service
systemctl --user daemon-reload
# Enable the service (it will start automatically with graphical session)
systemctl --user enable kbd-backlight-watcher.service 2>/dev/null || true
# Start now if we have a display
if [ -n "$DISPLAY" ]; then
    systemctl --user restart kbd-backlight-watcher.service 2>/dev/null || true
    echo -e "${GREEN}✅ Keyboard backlight watcher service enabled and started${RESET}"
else
    echo -e "${GREEN}✅ Keyboard backlight watcher service enabled (will start on next login)${RESET}"
fi

# ─── 🕰️ RTC policy (localtime mode for dual-boot with Windows) ──────
source ~/dotfiles/scripts/rtc_policy.sh
setup_rtc_policy

# ────── Раскладка alt shift ──────────────────────────

echo -e "${CYAN}🎹 Проверяем раскладку клавиатуры...${RESET}"

# Check if we're in X session
if [ -n "$DISPLAY" ]; then
    # Get current layout configuration
    current_layout=$(setxkbmap -query 2>/dev/null | grep layout | awk '{print $2}')
    current_options=$(setxkbmap -query 2>/dev/null | grep options | awk '{print $2}')

    # Check if us,ru layout and alt_shift_toggle are already configured
    if [[ "$current_layout" == "us,ru" ]] && [[ "$current_options" == *"grp:alt_shift_toggle"* ]]; then
        echo -e "${GREEN}✅ Раскладка уже настроена (us,ru + Alt+Shift)${RESET}"
    else
        echo -e "${CYAN}🎹 Применяем переключение раскладки Alt+Shift...${RESET}"
        setxkbmap -layout us,ru -option grp:alt_shift_toggle
        echo -e "${GREEN}✅ Раскладка настроена${RESET}"
    fi
else
    echo -e "${YELLOW}⚠️  Пропускаем настройку раскладки — нет X сессии${RESET}"
fi

# ─────────────────────────────────────────────
source ~/dotfiles/scripts/audio_setup.sh
audio_setup

source ~/dotfiles/scripts/detect_hardware.sh
install_drivers

source ~/dotfiles/scripts/laptop_power.sh
setup_power_management

source ~/dotfiles/scripts/hardware_config.sh
configure_hardware

# ─── 🎮 Steam & GPU launcher setup ───
source ~/dotfiles/scripts/steam_setup.sh
setup_steam

# ─── Media-aware idle inhibit (prevents screen blanking during playback) ───
source ~/dotfiles/scripts/idle_inhibit.sh
setup_idle_inhibit

# ─── 📸 Snapshot helper scripts ──────────────────────────
echo -e "${CYAN}🔧 Linking snapshot scripts...${RESET}"
mkdir -p ~/.local/bin
for script in snapshot-create snapshot-list snapshot-diff snapshot-delete snapshot-rollback; do
    if [ -f ~/dotfiles/bin/snapshots/$script ]; then
        ln -sf ~/dotfiles/bin/snapshots/$script ~/.local/bin/$script
        echo -e "${GREEN}✅ $script linked${RESET}"
    fi
done

# ─── 📸 Snapshots (Timeshift for ext4, Snapper for Btrfs) ───
source ~/dotfiles/scripts/snapshot_setup.sh
setup_snapshots

# ─── 🧠 zram: Compressed RAM swap for memory pressure stability ───
# Prevents full-system stalls under heavy workloads (JVM + browser + hybrid GPU)
# by providing a compressed memory buffer before OOM conditions.
source ~/dotfiles/scripts/zram_setup.sh
setup_zram

# Link zram diagnostic script
echo -e "${CYAN}🔧 Linking zram-status.sh...${RESET}"
ln -sf ~/dotfiles/bin/zram-status.sh ~/.local/bin/zram-status.sh
echo -e "${GREEN}✅ zram-status.sh linked${RESET}"

# 🎉 Финал
echo -e "${GREEN}✅ All done! You can launch i3 with \`startx\` from tty 🎉${RESET}"
