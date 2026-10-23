---
name: void-linux
description: Administer this Void Linux machine (xbps packages, runit services, niri desktop, boot/network/audio troubleshooting). Use when the user asks to install or remove a package, enable or debug a service, update the system, fix networking, audio, display or boot issues, or change the niri/waybar setup, and before installing any software or service (resource budget check). This is Void, not Debian/Arch/systemd.
---

# Void Linux

Rules, declarative workflow, git, forbidden commands: repo `CLAUDE.md`.

Before installing: `xbps-query -R -p installed_size <pkg>` and `xbps-query -Rx <pkg>`. If it looks heavy (desktop environment, Electron, Docker daemon, JVM/.NET, permanent DB or indexer, IDE, anything always-on), **stop and warn first**, even if asked:

> Avertissement ressources: `<nom>` est lourd (<raison: RAM idle ~X Mo / CPU en tâche de fond / N dépendances / daemon permanent>).
> Alternative légère: `<alt>` (<gain>). Je continue avec `<nom>` ou je prends `<alt>` ?

Load only what the task needs:

- `references/void.md`: runit enable/disable/logs, xbps extras, rolling-release rules.
- `references/resources.md`: light alternatives, measuring after install.
- `references/niri.md`: niri config, keybinds, menu, wallpaper, waybar.
- `references/troubleshooting.md`: network, audio, display, disk, boot.
