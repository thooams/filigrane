# niri desktop

- Config: `~/.config/niri/config.kdl` (symlink to `~/void-setup/dotfiles/config/niri/config.kdl`).
- Validate before applying: `niri validate`.
- niri reloads the config automatically on save.
- Start the session from a tty: `niri-session`.
- Keyboard layout: `input { keyboard { xkb { layout "fr" variant "bepo" } } }`.
- Autostart: `spawn-at-startup "<cmd>" ...` lines in the config (pipewire, waybar are started this way).
- Terminal: `Mod+T` (alacritty). Launcher: `Mod+D` (fuzzel). Lock: `Super+Alt+L` (swaylock). Claude Code: `Mod+Y`.
- Waybar: `~/.config/waybar/config.jsonc` and `style.css`; restart with `pkill waybar; waybar &`.
- Logs: run from a tty as `niri-session 2>&1 | tee ~/niri.log` if debugging.

Edit the repo file, not a copy; the symlink makes it live.
