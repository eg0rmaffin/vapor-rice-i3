# Если login-шелл не интерактивный — просто не делаем ничего
[[ $- != *i* ]] && return

# тянем bashrc
[ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"

# ─── Wayland environment (source before starting sway) ──────
# Uncomment the line below if you want to use Sway/Wayland
# [ -f "$HOME/.bash_wayland_env" ] && . "$HOME/.bash_wayland_env"
