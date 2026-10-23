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
| Visuals | static wallpaper (`swaybg`), plain waybar, no animated widgets; blur only behind the menu (`menu-backdrop`, computed while it is open) |

Waybar: few modules, `interval` of 5 s or more, no custom scripts that spawn often. Prefer a maintained Void package over source builds or curl-pipe installers (for those, say what they install and where).

## Home-made tools (`apps/`)

Prefer a light, fast native binary even if it has to be compiled, over a script that loads a heavy runtime on every launch (Python + GTK, Node, Electron). Example: `menu-backdrop` in Rust starts in ~6 ms with 2.4 MB RSS, the Python/GTK version took ~185 ms and 69 MB.

- Sources in `apps/<name>/` (Cargo project, `Cargo.lock` committed, `--locked`). Keep dependencies minimal: raw `wayland-client` + `wayland-protocols*` rather than a toolkit for a small Wayland client.
- Release profile: `opt-level = "s"`, `lto`, `codegen-units = 1`, `panic = "abort"`, `strip`.
- `bootstrap.sh` (`setup_apps`, dotfiles step) builds into `~/.local/opt/<name>-<source hash>`, links `~/.local/bin/<name>`, rebuilds only when sources change; `target/` stays in `~/.cache/void-setup-apps` (and `apps/*/target/` is git-ignored).
- Measure startup time and RSS against what it replaces, and report both.
- Shell scripts stay fine for glue (they spawn existing binaries); the rule targets programs that would load an interpreter or toolkit.
