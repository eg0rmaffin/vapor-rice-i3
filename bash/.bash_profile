# Если login-шелл не интерактивный — просто не делаем ничего
[[ $- != *i* ]] && return

# тянем bashrc
[ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"
