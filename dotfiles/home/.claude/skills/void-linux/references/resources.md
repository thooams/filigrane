# Resources

Goal: the base system idles as low as possible so the browser, agents, containers and apps keep the memory and CPU.

## Measure

- RAM: `free -h`. Top consumers: `ps -eo pid,rss,pcpu,comm --sort=-rss | head -15`.
- Services: `sudo sv status /var/service/*`. Disk (small): `df -h /`, check before big installs.
- Baseline: record `free -h` after a clean boot into niri, compare after each addition, report the delta.

## Light choices

| Need | Prefer |
|---|---|
| Containers | `podman` (daemonless), started only when needed |
| Editor | neovim (installed), `helix` |
| File manager | `yazi`, `nnn`, `lf` |
| Image viewer / PDF / media | `imv` or `swayimg` / `zathura` / `mpv` |
| Notifications | `mako` or `fnott` |
| Network | `dhcpcd` + `wpa_supplicant` (current), `iwd` |
| Search | `ripgrep`, `fd`, `fzf` instead of tracker/baloo |
| Database | SQLite, or start the service only when needed |
| Runtimes (Node/Python/JVM) | on demand, never as a boot service |
| Visuals | static wallpaper (`swaybg`), plain waybar, no blur or animated widgets |

Waybar: few modules, `interval` of 5 s or more, no custom scripts that spawn often. Prefer a maintained Void package over source builds or curl-pipe installers (for those, say what they install and where).
