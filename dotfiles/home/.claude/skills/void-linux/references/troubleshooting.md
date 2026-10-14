# Troubleshooting

Always start read-only.

## Network
- `ip a`, `ip r`, `ping -c1 1.1.1.1`, `ping -c1 voidlinux.org`.
- Wired: service `dhcpcd` (`sudo sv status dhcpcd`).
- Wi-Fi: `wpa_supplicant` + `dhcpcd`; config `/etc/wpa_supplicant/wpa_supplicant.conf`; `wpa_cli` to scan/connect.
- DNS: `/etc/resolv.conf` (written by dhcpcd).

## Audio
- Needs `pipewire` and `wireplumber` running in the session (started by niri `spawn-at-startup`).
- `wpctl status`, volume `wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.5`.
- No device: check user is in group `audio`, check `pipewire` process.

## Display / GPU
- `mesa-dri` is required. Intel adds `mesa-vulkan-intel`, `intel-video-accel`.
- In a VM: `open-vm-tools` + service `vmtoolsd`.
- Missing session or seat errors: `elogind` and `dbus` services must be running; log in from a real tty, not through `su`.

## Disk space
- `df -h /`, `sudo xbps-remove -O` (cache), `sudo xbps-remove -o` (orphans), `sudo vkpurge rm all` (old kernels).

## Boot
- Kernel params: `/etc/default/grub`, then `sudo grub-mkconfig -o /boot/grub/grub.cfg` (ask first).
- Rebuild initramfs: `sudo xbps-reconfigure -f linux<version>`.
- Fstab: `/etc/fstab`; never edit without a backup.

## Logs
- `dmesg`, `/var/log/*`, service logs (see runit.md).
