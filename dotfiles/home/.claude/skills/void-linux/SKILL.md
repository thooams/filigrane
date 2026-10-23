---
name: void-linux
description: Administer this Void Linux machine (xbps packages, runit services, niri desktop, boot/network/audio troubleshooting). Use when the user asks to install or remove a package, enable or debug a service, update the system, fix networking, audio, display or boot issues, or change the niri/waybar setup, and before installing any software or service (resource budget check). This is Void, not Debian/Arch/systemd.
---

# Void Linux

Hard rules, declarative workflow, git and forbidden commands: see the repo's `CLAUDE.md`. This skill only holds machine specifics.

## Resource budget

Before installing, check the cost: `xbps-query -R -p installed_size <pkg>`, `xbps-query -Rx <pkg>` (dependencies). Do not enable a service "just in case", do not autostart apps.

If a package or service looks heavy, **stop and warn before installing**, even if asked:

> Avertissement ressources: `<nom>` est lourd (<raison: RAM idle ~X Mo / CPU en tâche de fond / N dépendances / daemon permanent>).
> Alternative légère: `<alt>` (<gain>). Je continue avec `<nom>` ou je prends `<alt>` ?

Heavy: full desktop environments, Electron apps, Docker daemon, JVM/.NET kept running, permanent databases or indexers, IDEs, compositor effects, anything always-on or run at boot. Alternatives and measuring: `references/resources.md`. After installing something that stays running, measure and report the real cost.

## Void specifics

- Enable a service: `sudo ln -s /etc/sv/<nom> /var/service/`. Disable: `sudo sv down <nom>` then `sudo rm /var/service/<nom>`. Declare it in `services/`.
- Service logs: `/var/log/<nom>/current` when the service has a `log` script, else `dmesg` and `/var/log/socklog/*`. Scheduled jobs: `cronie` or `snooze`, no timers.
- Rolling release: never upgrade partially. Old kernels: `sudo vkpurge rm all`. Nonfree: `void-repo-nonfree`. Hold a version: `sudo xbps-pkgdb -m hold <pkg>`.
- `niri-session` does not exist (systemd only): start with `dbus-run-session niri`.

## References

- `references/niri.md`: config, keybinds, menu, wallpaper, waybar.
- `references/resources.md`: light alternatives, measuring.
- `references/troubleshooting.md`: network, audio, display, boot, disk.
