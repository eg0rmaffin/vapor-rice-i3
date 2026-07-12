# Dark theme delivery matrix

Dark theme on this rice is delivered through **four independent channels**. There is
no single global "dark mode" switch on X11/i3 — each toolkit/family reads its own
source of truth. This table is the answer to any future *"why is app X light?"*.

| Channel | Mechanism | Config that serves it | Example app | Status |
|---|---|---|---|---|
| GTK3 | `gtk-theme=Adwaita-dark` (gsettings) | `install.sh` appearance block (`gsettings set … gtk-theme 'Adwaita-dark'`) | blueman, pavucontrol | ✅ |
| GTK4 / libadwaita | `color-scheme=prefer-dark` (gsettings) | `install.sh` appearance block (`gsettings set … color-scheme 'prefer-dark'`) | nautilus-class GTK4 apps | ✅ |
| Portal (`org.freedesktop.appearance`) | `xdg-desktop-portal` + `-gtk` backend exposes `color-scheme` | `xdg-desktop-portal` + `xdg-desktop-portal-gtk` (packages) | Firefox, Chromium, Electron | ✅ (`ReadOne` → `v u 1`) |
| Qt (system-linked) | `QT_QPA_PLATFORMTHEME=qt6ct` → Fusion + dark palette | `qt6ct/qt6ct.conf` (symlinked) + env in `.xinitrc` | flameshot, future qbittorrent/OBS | ✅ |

## Why four channels

- **gsettings** covers GTK3 and GTK4/libadwaita, but each reads a *different* key
  (`gtk-theme` vs `color-scheme`) — both are set.
- The **portal** re-exports `color-scheme` over D-Bus for sandboxed / non-GTK
  consumers (browsers, Electron). Only the `-gtk` portal backend is installed;
  `xdg-desktop-portal-wlr` is a wlroots/Wayland backend and is **not** used on
  X11/i3.
- **Qt** ignores gsettings entirely. `qt6ct` provides a platform theme; it is
  selected per-session via `QT_QPA_PLATFORMTHEME=qt6ct` exported in `.xinitrc`
  before `exec i3`. `qt5ct` is installed for any Qt5 straggler — flip the env var
  to `qt5ct` if you ever need Qt5-only theming (one value per session).

## The bundled-Qt rule

Apps that **bundle their own Qt** are out of reach of system theming — they load
their own `libQt6*` and `qt.conf` and ignore `QT_QPA_PLATFORMTHEME`:

- **telegram-desktop** — theme managed in-app (Settings → Chat Settings).
- **happ-desktop-bin** — ships `/opt/happ/lib/libQt6*` + own `qt.conf`; theme
  managed in-app.

Rule of thumb: **bundled Qt = in-app setting.** Don't fight it from the system side.
