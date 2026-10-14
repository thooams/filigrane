# xbps

| Goal | Command |
|---|---|
| Sync repos | `sudo xbps-install -S` |
| Search | `xbps-query -Rs <motif>` |
| Package info | `xbps-query -R <pkg>` (remote), `xbps-query <pkg>` (installed) |
| Install | `sudo xbps-install <pkg>` |
| Full update | `sudo xbps-install -Su` (update xbps itself first if asked: `sudo xbps-install -u xbps`) |
| Remove | `sudo xbps-remove <pkg>` ; with unused deps: `sudo xbps-remove -R <pkg>` |
| Orphans | `sudo xbps-remove -o` |
| Clean cache | `sudo xbps-remove -O` |
| Which package owns a file | `xbps-query -o <chemin>` (local), `xbps-query -Ro` needs xtools |
| Files of a package | `xbps-query -f <pkg>` |
| Manually installed | `xbps-query -m` |
| Reinstall configs | `sudo xbps-reconfigure -f <pkg>` ; all: `-fa` |
| Hold a version | `sudo xbps-pkgdb -m hold <pkg>` |

Repos live in `/etc/xbps.d/*.conf` and `/usr/share/xbps.d/`. Nonfree: `sudo xbps-install void-repo-nonfree` then `xbps-install -S`.

Rolling release: always update everything together, never partially upgrade.
Kernel: package `linux`; old kernels are removed with `sudo vkpurge rm all`.

Remember the declarative rule: add the package to `~/void-setup/packages/*.txt`.
