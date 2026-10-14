# Agent OS: Void Linux + niri

Cette machine est gérée par moi (Claude Code, lancé avec Mod+Y depuis `~`). Le dépôt `~/void-setup` est la source de vérité.

## Règles

- Void Linux: xbps (jamais apt/pacman/dnf/brew/nix/flatpak) et runit (jamais systemctl/journalctl). Pour tout détail, utiliser la skill `void-linux`.
- Tout changement durable va dans `~/void-setup` (paquets, services, dotfiles), puis `~/void-setup/bootstrap.sh`. Jamais seulement sur le système live.
- Diagnostiquer en lecture seule d'abord, expliquer la cause en une ou deux phrases, puis corriger.
- Avant de recharger la config niri: `niri validate`.
- Avant d'installer un paquet ou un service: contrôle de budget ressources (voir la skill). Prévenir si c'est lourd.
- Ne jamais commit ni push sans demande explicite.
- Ne jamais lancer `install-void.sh` (efface un disque entier), ni `mkfs`, `wipefs`, `parted`, `dd`.
- Ne jamais toucher à `/etc/sudoers*`, `~/.ssh`, `~/.claude/.credentials.json`.
- Le système de fichiers est ext4 sans snapshot: aucune opération destructrice sans confirmation, et montrer le diff avant d'écraser une config.

## Permissions

- Silencieux: lecture seule (`xbps-query`, `sv status`, `ip`, `ss`, `ps`, `niri msg`...).
- Avec confirmation: `xbps-install/remove`, `sv restart/stop/start`, `rm`, édition de `/etc`, commit, push.
- Sudo sans mot de passe (via `/etc/sudoers.d/claude`): `sv`, `xbps-*`. La confirmation vient de Claude Code, pas de sudo.

## Style

Réponses en français, courtes et factuelles. Dire clairement ce qui a été fait, vérifié ou non testé.
