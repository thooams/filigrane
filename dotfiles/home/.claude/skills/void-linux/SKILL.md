---
name: void-linux
description: Administer this Void Linux machine (xbps packages, runit services, niri desktop, boot/network/audio troubleshooting). Use when the user asks to install or remove a package, enable or debug a service, update the system, fix networking, audio, display or boot issues, or change the niri/waybar setup. This is Void, not Debian/Arch/systemd.
---

# Void Linux

Machine is built from the repo `~/void-setup` (https://github.com/thooams/void-setup). Dotfiles in `~/.config` and `~/` are symlinks into that repo.

## Hard rules

- Package manager is **xbps**. Never use apt, pacman, dnf, brew, nix or flatpak.
- Init is **runit**, not systemd. Never use `systemctl` or `journalctl`.
- Use the real tools: see `references/xbps.md` and `references/runit.md`.
- Root commands go through `sudo`. Reading state (xbps-query, `sv status`, `lsblk`, `ip`) needs no root.

## Declarative rule (most important)

Every durable change must land in `~/void-setup`, not only on the live system:

| Change | Edit |
|---|---|
| New package | the right file in `packages/` (`base`, `desktop`, `vm`, `baremetal`) |
| New service | `services/common.txt` (or `vm.txt`) |
| Keyboard, timezone, locale, groups | `config.env` |
| Config file (niri, waybar, bash...) | `dotfiles/home/...` or `dotfiles/config/...` |

Then apply with `~/void-setup/bootstrap.sh` (idempotent), show `git -C ~/void-setup diff`, and **ask before committing or pushing**.
If the user only wants a throwaway test, say it will not survive a reinstall.

## Ask before running

`xbps-install -u` / `-Syu`, `xbps-remove`, `rm`, any edit in `/etc`, bootloader (`grub-*`), partitioning, `reboot`.
Read-only commands: just run them.

## Never run

`install-void.sh` (it wipes a whole disk, meant for the live ISO only), `mkfs.*`, `wipefs`, `parted`, `dd` on a disk.

## Workflow

1. Diagnose with read-only commands first (`sv status`, `xbps-query`, `dmesg`, logs under `/var/log`).
2. Explain the cause in one or two sentences.
3. Propose the fix, apply it, then record it in the repo.

## References

- `references/xbps.md`: install, search, update, files, repos, nonfree.
- `references/runit.md`: enable/disable/restart services, logs, user services.
- `references/niri.md`: config location, reload, keybinds, waybar.
- `references/troubleshooting.md`: network, audio, display, boot, disk space.
