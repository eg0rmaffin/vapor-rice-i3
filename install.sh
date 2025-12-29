#!/bin/bash
set -e

# ─────────────────────────────────────────────
# 🎨 Цвета
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
RESET="\033[0m"

# ─────────────────────────────────────────────
# 🧩 helper: установка списков пакетов
install_list() {
  local -a pkgs=("$@")
  for pkg in "${pkgs[@]}"; do
    if ! pacman -Q "$pkg" &>/dev/null; then
      echo -e "${YELLOW}📦 Installing $pkg...${RESET}"
      sudo pacman -S --noconfirm "$pkg"
    else
      echo -e "${GREEN}✅ $pkg already installed${RESET}"
    fi
  done
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
if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
    echo -e "${YELLOW}🔧 Добавляем multilib репозиторий...${RESET}"
    sudo sed -i '/#\[multilib\]/,/#Include = \/etc\/pacman.d\/mirrorlist/ s/^#//' /etc/pacman.conf
    echo -e "${CYAN}🔄 Обновляем кеш pacman...${RESET}"
    sudo pacman -Sy
    echo -e "${GREEN}✅ multilib репозиторий активирован${RESET}"
else
    echo -e "${GREEN}✅ multilib уже включён${RESET}"
fi

# ─────────────────────────────────────────────
# ─────────────────────────────────────────────
# 🌐 Обновление зеркал (с кешем и фоллбеком)
echo -e "${CYAN}🌐 Проверяем зеркала...${RESET}"

MIRROR_CACHE="$HOME/.cache/mirrorlist"
CACHE_AGE_DAYS=7

# 1️⃣ Убедимся, что reflector установлен
if ! command -v reflector &>/dev/null; then
    echo -e "${YELLOW}📦 Устанавливаем reflector...${RESET}"
    sudo pacman -S --noconfirm reflector
fi

# 2️⃣ Бэкапим текущий список
sudo cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak 2>/dev/null || true

# 3️⃣ Функция обновления зеркал
update_mirrors() {
    echo -e "${CYAN}🔄 Обновляем зеркала через reflector (~1 мин)...${RESET}"
    
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
}

# 4️⃣ Проверяем кеш
if [ -f "$MIRROR_CACHE" ] && [ -n "$(find "$MIRROR_CACHE" -mtime -$CACHE_AGE_DAYS 2>/dev/null)" ]; then
    echo -e "${GREEN}✅ Используем закешированные зеркала (<$CACHE_AGE_DAYS дней)${RESET}"
    sudo cp "$MIRROR_CACHE" /etc/pacman.d/mirrorlist
    
    # Проверяем, работают ли зеркала
    if ! sudo pacman -Sy --noconfirm 2>/dev/null; then
        echo -e "${YELLOW}⚠️ Закешированные зеркала не работают, обновляем...${RESET}"
        update_mirrors
    fi
else
    update_mirrors
fi

# 5️⃣ Финальная синхронизация
sudo pacman -Syy --noconfirm
echo -e "${GREEN}✅ Mirrorlist готов${RESET}"

# ─────────────────────────────────────────────
# 📦 Зависимости pacman
deps=(
	xorg-server
	xorg-xinit
	base-devel
	i3-gaps
	i3blocks
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
	thunar-archive-plugin
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
	#utils
	p7zip
	qbittorrent
	firejail #проверка подозрительных appImage
	xournalpp #доска для рисования
	thunderbird #thunderbird (no comments)
    bind #для сетевых тестов
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
)

# было: явный for-цикл; стало: вызов хелпера
install_list "${deps[@]}"

#-------- AUR pacs ----------

if ! command -v yay &>/dev/null; then
    echo -e "${YELLOW}📦 yay не найден, клонируем и устанавливаем...${RESET}"
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    pushd /tmp/yay > /dev/null
    makepkg -si --noconfirm
    popd > /dev/null
    rm -rf /tmp/yay
    echo -e "${GREEN}🧹 Временная папка /tmp/yay удалена${RESET}"
else
    echo -e "${GREEN}✅ yay уже установлен${RESET}"
fi

aur_pkgs=(
    xkb-switch
    light
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

echo -e "${CYAN}📦 Loading vboxdrv module...${RESET}"
sudo modprobe vboxdrv || echo -e "${YELLOW}⚠️ Не удалось загрузить vboxdrv — возможно, нужно перезагрузить систему${RESET}"

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
echo -e "${GREEN}✅ GTK 3.0 settings linked${RESET}"

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

# 🧩 Vim config
echo -e "${CYAN}🔧 Linking Vim config...${RESET}"
ln -sf ~/dotfiles/vim/.vimrc ~/.vimrc
echo -e "${GREEN}✅ Vim config linked${RESET}"

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
sudo sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
sudo sed -i 's/^#ru_RU.UTF-8 UTF-8/ru_RU.UTF-8 UTF-8/' /etc/locale.gen

sudo locale-gen

echo 'LANG=en_US.UTF-8' | sudo tee /etc/locale.conf
echo 'KEYMAP=us' | sudo tee /etc/vconsole.conf


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

# 🔗 OSD scripts
echo -e "${CYAN}🔧 Linking OSD scripts...${RESET}"
mkdir -p ~/.local/bin
ln -sf ~/dotfiles/scripts/osd/volume.sh ~/.local/bin/volume.sh
echo -e "${GREEN}✅ volume.sh linked${RESET}"

# ─── 💡 Keyboard Backlight Support ──────
echo -e "${CYAN}💡 Setting up keyboard backlight support...${RESET}"
mkdir -p ~/.local/bin
ln -sf ~/dotfiles/bin/kbd-backlight.sh ~/.local/bin/kbd-backlight.sh
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

# ─── 🕰️ Настройка локального времени RTC ──────
echo -e "${CYAN}🕰️ Настраиваем RTC в режиме localtime...${RESET}"
sudo timedatectl set-local-rtc 1 --adjust-system-clock
echo -e "${GREEN}✅ RTC теперь работает в localtime${RESET}"

# ────── Раскладка alt shift ──────────────────────────

echo -e "${CYAN}🎹 Применяем переключение раскладки Alt+Shift...${RESET}"
setxkbmap -layout us,ru -option grp:alt_shift_toggle

# ─────────────────────────────────────────────
source ~/dotfiles/scripts/audio_setup.sh
audio_setup

source ~/dotfiles/scripts/detect_hardware.sh
install_drivers

source ~/dotfiles/scripts/laptop_power.sh
setup_power_management

source ~/dotfiles/scripts/hardware_config.sh
configure_hardware

# ─── 📸 Snapshot helper scripts ──────────────────────────
echo -e "${CYAN}🔧 Linking snapshot scripts...${RESET}"
mkdir -p ~/.local/bin
for script in snapshot-create snapshot-list snapshot-diff snapshot-delete snapshot-rollback; do
    if [ -f ~/dotfiles/bin/snapshots/$script ]; then
        ln -sf ~/dotfiles/bin/snapshots/$script ~/.local/bin/$script
        echo -e "${GREEN}✅ $script linked${RESET}"
    fi
done

# ─── 📸 Snapshots (Btrfs + Snapper) ──────────────────────
source ~/dotfiles/scripts/snapshot_setup.sh
setup_snapshots

# 🎉 Финал
echo -e "${GREEN}✅ All done! You can launch i3 with \`startx\` from tty 🎉${RESET}"
