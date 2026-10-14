# niri desktop

- Config: `~/.config/niri/config.kdl` (symlink to `~/void-setup/dotfiles/config/niri/config.kdl`).
- Validate before applying: `niri validate`.
- niri reloads the config automatically on save.
- Start the session from a tty: `dbus-run-session niri` (`niri-session` is systemd-only and does not exist on Void). The session bus is private to that run, so to talk to it from outside (ssh) read `DBUS_SESSION_BUS_ADDRESS` from `/proc/$(pidof waybar)/environ`.
- Keyboard layout: `input { keyboard { xkb { layout "fr" variant "bepo" } } }`.
- Environment: `environment { ... }` block sets `CHROME_FLAGS` (chromium native Wayland, pipewire screen capture) and `ELECTRON_OZONE_PLATFORM_HINT`. Void's chromium wrapper ignores flags files; it only reads `CHROME_FLAGS`.
- Autostart: `spawn-at-startup "<cmd>" ...` lines in the config (pipewire, waybar are started this way).
- Terminal: `Mod+T` (alacritty). Menu: `Mod+Space` (`~/.local/bin/menu`, fuzzel dmenu, ONE fuzzy list: custom entries from `~/.config/menu/entries`, all .desktop apps, and "Category: Action" system actions; `menu <section>` jumps directly to clip, emoji, calc...). App launcher only: `Mod+D` (fuzzel). Lock: `Super+Alt+L` (swaylock). Claude Code: `Mod+Y`.
- Wallpaper: `swaybg` (static, 41 KB) via `~/.local/bin/wallpaper [image]`; images in `~/.local/share/wallpapers/`. Never use animated wallpapers (cost CPU/GPU at idle).
- Waybar: `~/.config/waybar/config.jsonc` and `style.css`; restart with `pkill waybar; waybar &`.
- Logs: run from a tty as `dbus-run-session niri 2>&1 | tee ~/niri.log` if debugging.

Edit the repo file, not a copy; the symlink makes it live.
