# Troubleshooting

## Network
- `ip a`, `ip r`, `ping -c1 1.1.1.1`, `ping -c1 voidlinux.org`.
- Wi-Fi: `iwd` connects AND configures IP (DHCPv4, RA/DHCPv6, DNS via resolvconf; `/etc/iwd/main.conf` from `system/iwd/`). `iwctl station wlp229s0 show`, `impala` (TUI). Logs: `grep iwd /var/log/socklog/daemon/current`.
- Wired: `dhcpcd` (service), `denyinterfaces wl*` in `/etc/dhcpcd.conf`. Never `dhcpcd -n` on the Wi-Fi.
- IPv4 dead but IPv6 ok on Wi-Fi: `iwctl station wlp229s0 disconnect` then `iwctl station wlp229s0 connect <ssid>` (or `captive-portal`).

## Audio
- `pipewire` and `wireplumber` must run in the session (niri `spawn-at-startup`). `wpctl status`.
- No device: user in group `audio`? `pipewire` process alive?

## Display / GPU
- `mesa-dri` required; Intel adds `mesa-vulkan-intel`, `intel-video-accel`. VM: `open-vm-tools` + service `vmtoolsd`.
- Session or seat errors: `elogind` and `dbus` services must run; log in from a real tty, not `su`.

## Disk space
- `sudo xbps-remove -O` (cache), `sudo xbps-remove -o` (orphans), `sudo vkpurge rm all` (old kernels).

## Boot
- Kernel params: `/etc/default/grub`, then `sudo grub-mkconfig -o /boot/grub/grub.cfg`.
- Initramfs: `sudo xbps-reconfigure -f linux<version>`. Back up `/etc/fstab` before any edit.
