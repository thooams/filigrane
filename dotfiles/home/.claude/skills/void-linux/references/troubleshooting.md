# Troubleshooting

## Network
- `ip a`, `ip r`, `ping -c1 1.1.1.1`, `ping -c1 voidlinux.org`.
- `dhcpcd` (service) + `wpa_supplicant`; config `/etc/wpa_supplicant/wpa_supplicant.conf`, `wpa_cli` to scan/connect. DNS in `/etc/resolv.conf` is written by dhcpcd.

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
