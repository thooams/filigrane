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

L'OS doit se faire oublier: le navigateur, les agents et les conteneurs passent avant. Choisir la solution la plus légère (paquet Void natif, pas de daemon inutile, pas d'Electron/JVM/Node résident, pas d'effets niri hors du flou derrière le menu). Si un paquet ou service est lourd, **avertir avant d'installer** (format dans la skill). Mesurer après toute installation durable. Pour un outil maison, préférer un binaire natif léger et rapide (Rust, dans `apps/`, compilé par `bootstrap.sh`) à un script qui charge un runtime lourd (Python/GTK, Node), quitte à compiler.

## Git

- Dépôt **public**: avant chaque commit, scanner le diff stagé (tokens, mots de passe, clés, e-mails, IP) et montrer le résultat.
- Commit autorisé sans demander après un changement terminé et vérifié (scan ci-dessus obligatoire, jamais d'attribution Claude). Push autorisé sans demander sur toute branche autre que `main`; jamais de push sur `main` (ni force-push) sans demande explicite.

## Interdits

`install-void.sh` (efface un disque entier), `mkfs`, `wipefs`, `parted`, `dd` sur un disque, et toute modification de `/etc/sudoers*`, `~/.ssh`, `~/.claude/.credentials.json`.
Sans confirmation: installer un paquet (`xbps-install <pkg>`, avertissement ressources si lourd), `xbps-remove` simple d'un paquet non critique (le hook `guard-destructive.sh` redemande pour `base-system`, noyau, glibc, xbps, runit, sudo, niri, `-R`/`-f`), `rm` dans le scratchpad ou le dépôt, commit après un changement vérifié (voir Git).
Demander avant: mises à jour système (`xbps-install -u/-Su`), `sv restart/stop` (services système), `rm` ailleurs, édition de `/etc`, bootloader, reboot, push sur `main`. `sv` et `xbps-*` passent sans mot de passe sudo: la confirmation vient de Claude Code.
Choix de conception (valeur, réglage, outil): prendre le défaut raisonnable, le dire en une ligne, ne pas poser de question. Après un remplacement validé par l'usage, nettoyer l'ancien (paquet, config) sans redemander.

## Style

Réponses en français, courtes et factuelles. Dire ce qui a été fait, vérifié ou non testé.
