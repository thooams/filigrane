# void-setup: Void Linux + niri

Ce dépôt décrit la machine (paquets, services, dotfiles) et c'est depuis lui que Claude Code est lancé (Mod+Y). Les conversations portent sur cette machine: config, paquets, services, niri, dépannage. Les dotfiles de `~` et `~/.config` sont des liens vers `dotfiles/` (`bootstrap.sh`).

La skill `void-linux` contient le détail (références xbps, runit, niri, ressources, dépannage). Ce fichier ne garde que les règles toujours actives.

## Règles dures

- Gestionnaire de paquets: **xbps** (jamais apt, pacman, dnf, brew, nix, flatpak). Init: **runit** (jamais systemctl ni journalctl). Root via `sudo`.
- Lecture seule d'abord pour diagnostiquer, cause en une ou deux phrases, puis correction.
- Avant de recharger la config niri: `niri validate`.

## Déclaratif

Tout changement durable va dans ce dépôt, pas seulement sur le système live:
- paquets: `packages/`, services: `services/`, clavier/locale/groupes: `config.env`, configs: `dotfiles/`.
- Puis `./bootstrap.sh` (idempotent) et montrer `git diff`.

## Ressources

L'OS doit se faire oublier: le navigateur, les agents et les conteneurs passent avant. Choisir la solution la plus légère (paquet Void natif, pas de daemon inutile, pas d'Electron/JVM/Node résident, pas d'effets niri). Si un paquet ou service est lourd, **avertir avant d'installer** (format dans la skill). Mesurer après toute installation durable.

## Git

- Dépôt **public**: avant chaque commit, scanner le diff stagé (tokens, mots de passe, clés, e-mails, IP) et montrer le résultat.
- Commit autorisé sans demander après un changement terminé et vérifié (scan ci-dessus obligatoire, jamais d'attribution Claude). Ne jamais push sans demande explicite.

## Interdits

`install-void.sh` (efface un disque entier), `mkfs`, `wipefs`, `parted`, `dd` sur un disque, et toute modification de `/etc/sudoers*`, `~/.ssh`, `~/.claude/.credentials.json`.
Installer un paquet (`xbps-install <pkg>`) ne demande pas de confirmation (avertissement ressources si lourd, voir ci-dessus). Demander avant: mises à jour système (`xbps-install -u/-Su`), `xbps-remove`, `sv restart/stop`, `rm`, édition de `/etc`, bootloader, reboot. `sv` et `xbps-*` passent sans mot de passe sudo: la confirmation vient de Claude Code.

## Style

Réponses en français, courtes et factuelles. Dire ce qui a été fait, vérifié ou non testé.
