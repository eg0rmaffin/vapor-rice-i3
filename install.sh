#!/bin/bash
set -e

# ─────────────────────────────────────────────
# 🎨 Цвета
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
RESET="\033[0m"

# ─────────────────────────────────────────────
# 🚀 Шапка
echo -e "${CYAN}"
echo "┌────────────────────────────────────────────┐"
echo "│        🚀 Installing your dotfiles         │"
echo "└────────────────────────────────────────────┘"
echo -e "${RESET}"

# ─────────────────────────────────────────────
# 🌐 Обновление зеркал с помощью reflector
if ! command -v reflector &>/dev/null; then
    echo -e "${YELLOW}📦 Устанавливаем reflector для зеркал...${RESET}"
    sudo pacman -S --noconfirm reflector
fi

echo -e "${CYAN}🌐 Обновляем зеркала с помощью reflector...${RESET}"
sudo reflector --country Russia --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
echo -e "${GREEN}✅ Зеркала обновлены${RESET}"


# ─────────────────────────────────────────────
# 📦 Зависимости
deps=(
	xorg
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
)

for pkg in "${deps[@]}"; do
    if ! pacman -Q "$pkg" &>/dev/null; then
        echo -e "${YELLOW}📦 Installing $pkg...${RESET}"
        sudo pacman -S --noconfirm "$pkg"
    else
        echo -e "${GREEN}✅ $pkg already installed${RESET}"
    fi
done

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
# 🔗 Симлинки
echo -e "${CYAN}🔗 Creating symlinks...${RESET}"

ln -sf ~/dotfiles/.xinitrc ~/.xinitrc

# Удалим старый конфиг, чтобы точно не было коллизий
rm -rf ~/.config/i3
mkdir -p ~/.config
ln -s ~/dotfiles/i3 ~/.config/i3

# 🧩 Bash config
echo -e "${CYAN}🔧 Linking .bashrc...${RESET}"
ln -sf ~/dotfiles/bash/.bashrc ~/.bashrc
echo -e "${GREEN}✅ .bashrc linked${RESET}"

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

# 💡 Настройка прав на управление яркостью
echo -e "${CYAN}🔧 Setting up backlight permissions...${RESET}"

UDEV_RULE='/etc/udev/rules.d/90-backlight.rules'

sudo tee "$UDEV_RULE" > /dev/null <<EOF
SUBSYSTEM=="backlight", \
  RUN+="/bin/chgrp video /sys/class/backlight/%k/brightness", \
  RUN+="/bin/chmod g+w /sys/class/backlight/%k/brightness"
EOF

sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=backlight

# Добавим пользователя в группу video
sudo usermod -aG video "$USER"

echo -e "${GREEN}✅ Udev rule written to $UDEV_RULE${RESET}"


# ─── 🌐 Локали ────────
sudo sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
sudo sed -i 's/^#ru_RU.UTF-8 UTF-8/ru_RU.UTF-8 UTF-8/' /etc/locale.gen

sudo locale-gen

echo 'LANG=en_US.UTF-8' | sudo tee /etc/locale.conf
echo 'KEYMAP=us' | sudo tee /etc/vconsole.conf

# ─────────────────────────────────────────────

# 🎉 Финал
echo -e "${GREEN}✅ All done! You can launch i3 with \`startx\` from tty 🎉${RESET}"
