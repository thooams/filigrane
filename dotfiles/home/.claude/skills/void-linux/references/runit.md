# runit

Service definitions: `/etc/sv/<nom>`. Enabled services: symlinks in `/var/service/`, which resolves to `/etc/runit/runsvdir/default/` (same directory, persistent across reboots).

| Goal | Command |
|---|---|
| List states | `sudo sv status /var/service/*` |
| Enable | `sudo ln -s /etc/sv/<nom> /var/service/` (starts within seconds) |
| Disable | `sudo sv down <nom>` then `sudo rm /var/service/<nom>` |
| Start/stop/restart | `sudo sv start|stop|restart <nom>` |
| Reload config | `sudo sv reload <nom>` |
| Stop without disabling | `sudo touch /etc/sv/<nom>/down` |

Logs: services with a `log` run script write to `/var/log/<nom>/current` (`sudo svlogtail <nom>` if available, else `sudo tail -f`). Otherwise use `dmesg` and `/var/log/socklog/*` when socklog is installed.

No systemd-style units, timers or targets. Use `cron` (`cronie` or `snooze` service) for scheduled jobs.

Services in this repo: `services/common.txt`, `services/vm.txt`. Keep them in sync (declarative rule).
