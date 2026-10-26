# Resources

The base system idles as low as possible: the browser, agents and containers keep the RAM and CPU.

- **Measure** after any durable install and report the delta: `free -h`, `ps -eo pid,rss,pcpu,comm --sort=-rss | head -15`, `sudo sv status /var/service/*`, `df -h /` before big installs.
- **Chosen tools** (keep them, propose these first): podman (daemonless), neovim, yazi + Thunar on demand, imv, mpv, mako, iwd, ripgrep/fd/fzf, swaybg, waybar with few modules (interval ≥ 5 s, no frequently spawned scripts). Runtimes (Node, Python, JVM) on demand, never as a boot service. Prefer a Void package over source builds or curl-pipe installers.

## Home-made tools (`apps/`)

Native Rust binary rather than a script loading a heavy runtime (Python/GTK, Node). Example: `menu-backdrop` 6 ms / 2.4 MB RSS vs 185 ms / 69 MB in Python/GTK. Shell stays fine for glue.

- `apps/<name>/`, `Cargo.lock` committed, built `--locked`; minimal deps (raw `wayland-client` + `wayland-protocols*`, no toolkit).
- Release profile: `opt-level = "s"`, `lto`, `codegen-units = 1`, `panic = "abort"`, `strip`.
- `bootstrap.sh` (`setup_apps`) builds into `~/.local/opt/<name>-<hash>`, links `~/.local/bin/<name>`, rebuilds only on source change; `target/` in `~/.cache/void-setup-apps`.
- Report startup time and RSS against what it replaces.
