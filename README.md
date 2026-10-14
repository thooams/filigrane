# void-setup

Environnement Void Linux (niri) rejouable sur VM, PC ou Mac Intel (x86_64, UEFI, glibc).

## Structure

| Chemin | Rôle |
|---|---|
| `install-void.sh` | Depuis l'ISO live : partitionne, installe la base, appelle `bootstrap.sh`, installe GRUB |
| `bootstrap.sh` | Sur un Void existant : paquets, services runit, clavier/fuseau, groupes, dotfiles. Idempotent |
| `config.env` | Clavier (`fr-bepo`), fuseau, locale, groupes |
| `packages/*.txt` | Listes xbps : `base`, `desktop`, `vm`, `baremetal`, `nonfree-baremetal` |
| `services/*.txt` | Services runit : `common`, `vm` |
| `dotfiles/home`, `dotfiles/config` | Fichiers liés par symlink dans `~` et `~/.config` |
| `scripts/pull-from-vm.sh` | Rapatrie les dotfiles depuis la VM de référence et liste les paquets non suivis |

Le profil (`vm` ou `baremetal`) est détecté via le flag `hypervisor` de `/proc/cpuinfo`, ou forcé avec `--profile`.

## Réinstaller un système complet

1. Démarrer sur l'ISO live Void (glibc x86_64), configurer le réseau, root/`voidlinux`.
2. Récupérer le dépôt : `xbps-install -Sy git && git clone <url> void-setup && cd void-setup`
3. `./install-void.sh --disk /dev/sda --user thomas --hostname void` (NVMe : `/dev/nvme0n1`)
4. Taper le chemin du disque pour confirmer, saisir les mots de passe, redémarrer.

GRUB est installé en `--removable` : pas d'entrée NVRAM, donc démarrage fiable sur PC comme sur Mac Intel.

## Rejouer sur un Void déjà installé

```
git clone <url> ~/void-setup && cd ~/void-setup
./bootstrap.sh                 # tout
./bootstrap.sh --dotfiles-only # liens seulement
```

Les dotfiles existants sont déplacés en `*.bak.<date>`. Le dépôt doit rester à son emplacement (les liens pointent dedans).

Sans remote git, copier le dépôt depuis un autre poste (pas de `rsync` sur Void de base) :
`tar --exclude=.git -C ~/Projects/void-setup -cf - . | ssh void 'mkdir -p ~/void-setup && tar -xf - -C ~/void-setup'`
puis `ssh -t void 'cd ~/void-setup && ./bootstrap.sh'` (`-t` pour la saisie du mot de passe sudo).
Sur l'ISO live : `scp -r void-setup root@<ip-du-live>:`.

Après la première connexion, lancer le bureau avec `dbus-run-session niri` (`niri-session` est un script systemd, absent de Void) (pas de démarrage automatique configuré).

## Claude Code et skill `void-linux`

`bootstrap.sh` installe Claude Code (`~/.local/bin/claude`, installeur officiel, sans root). Premier lancement : `claude` puis `/login` (aucun credential dans le dépôt). Raccourci niri : `Mod+Y`.

Le skill `dotfiles/home/.claude/skills/void-linux/` apprend à Claude les règles de cette machine (xbps, runit, niri) et l'oblige à reporter tout changement durable dans ce dépôt. `dotfiles/home/.claude/settings.json` pré-autorise les commandes en lecture seule et refuse `install-void.sh`, `mkfs`, `wipefs`, `dd`.

## Workflow

La VM reste le terrain d'essai : on règle niri/waybar/etc. dessus, puis `scripts/pull-from-vm.sh`, relire le diff, commit.
Nouveau paquet : l'ajouter dans le bon fichier `packages/*.txt`.

## Limites connues

- UEFI uniquement, pas de LUKS/LVM, pas de BIOS legacy.
- Macs T2 (2018+) : besoin d'un noyau spécifique, non géré.
- Wi-Fi Broadcom des vieux Macs : pilote propriétaire (`broadcom-wl-dkms`, nonfree) non inclus.
- `install-void.sh` et le profil `baremetal` n'ont pas été testés de bout en bout (la VM actuelle n'est pas réinstallable sans l'effacer).
- Le fuseau n'était pas défini sur la VM ; `config.env` met `Europe/Paris`.
