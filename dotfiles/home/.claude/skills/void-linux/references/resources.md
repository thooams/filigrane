# Resources

Goal: the base system idles as low as possible so the browser, agents, containers and apps keep the memory and CPU.

## Measure

| What | Command |
|---|---|
| RAM now | `free -h` |
| Top RAM/CPU | `ps -eo pid,rss,pcpu,comm --sort=-rss \| head -15` |
| Live view | `htop` |
| Package size | `xbps-query -R -p installed_size <pkg>` |
| Dependencies | `xbps-query -Rx <pkg>` (direct), count them before installing |
| Running services | `sudo sv status /var/service/*` |
| Disk | `df -h /` (the disk is small: check free space before big installs) |

Baseline to protect: record `free -h` after a clean boot into niri and compare after each addition. Report the delta.

## Heavy vs light

| Need | Avoid (heavy) | Prefer (light) |
|---|---|---|
| Desktop | GNOME, KDE, XFCE | niri + waybar + fuzzel (current) |
| Containers | Docker daemon (dockerd + containerd always on) | `podman` (daemonless), start only when needed |
| Editor | VS Code, other Electron IDEs, JetBrains | neovim (installed), `helix` |
| Notes/chat apps | Electron wrappers | browser tab, terminal client |
| File manager | Nautilus, Dolphin | `yazi`, `nnn`, `lf` |
| Image viewer | Gwenview, Eye of GNOME | `imv`, `swayimg` |
| PDF | Okular, Evince | `zathura` |
| Media | VLC with full stack | `mpv` |
| Notifications | Dunst + heavy daemons | `mako` or `fnott` |
| Screenshots | GUI tools | `grim` + `slurp` |
| Network | NetworkManager stack | `dhcpcd` + `wpa_supplicant` (current), `iwd` |
| Search/indexing | tracker, baloo, Elasticsearch | `ripgrep`, `fd`, `fzf` |
| Database | Postgres/MySQL always on | SQLite, or start the service only when needed |
| Logs | journald-like heavy stacks | runit `svlogd` (current) |
| Scripting runtimes | Node/Python/JVM daemons at boot | run on demand, never enable as a service |
| Visuals | animated wallpapers, blur, widgets (eww with polling) | static wallpaper (`swaybg`), plain waybar |
| Package formats | flatpak, snap, AppImage layers | native xbps package |

## Beautiful but cheap

- Fonts and a coherent palette cost nothing: `dejavu-fonts-ttf`, `noto-fonts-ttf`, `font-awesome6` are in place.
- niri gaps, borders, rounded corners and focus ring are configured in `config.kdl` and are essentially free. Disable animations if they cost anything on weak GPUs.
- Waybar: few modules, long polling intervals (`interval` of 5 s or more), no custom scripts that spawn often.
- Terminal: foot (Wayland natif, ~20 Mo, sans GPU).

## Rules of thumb

- A new always-on service needs a reason. Default is "no".
- Prefer a maintained package from the Void repo over building from source or curl-pipe installers (installer scripts: tell the user what it installs and where).
- If two options exist, pick the one with fewer dependencies and no background daemon.
- Autostart in niri (`spawn-at-startup`) only what the session needs: pipewire, waybar.
