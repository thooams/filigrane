# Void specifics

- Enable a service: `sudo ln -s /etc/sv/<nom> /var/service/`. Disable: `sudo sv down <nom>` then `sudo rm /var/service/<nom>`. Declare it in `services/`.
- Service logs: `/var/log/<nom>/current` when the service has a `log` script, else `dmesg` and `/var/log/socklog/*`. Scheduled jobs: `cronie` or `snooze`, no timers.
- Rolling release: never upgrade partially. Old kernels: `sudo vkpurge rm all`. Nonfree: `void-repo-nonfree`. Hold a version: `sudo xbps-pkgdb -m hold <pkg>`.
- `niri-session` does not exist (systemd only): start with `dbus-run-session niri`.
