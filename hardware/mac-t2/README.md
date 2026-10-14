# Mac Intel à puce T2

MacBook Pro/Air 2018-2020, Mac mini 2018, iMac 2020, iMac Pro, Mac Pro 2019. Détection automatique par `lspci` (`106b:1801` / `106b:1802`), comme Omarchy.

## Approche

Omarchy utilise un noyau `linux-t2` patché (Arch). Void n'en a pas : on garde le noyau Void et on compile les pilotes manquants en **DKMS**, reconstruits à chaque mise à jour du noyau.

| Fonction | Source |
|---|---|
| Clavier, trackpad (USB virtuel), audio | DKMS `t2bce` (`t2bce_core/dma/vhci/audio`, dépôt AdityaGarg8/t2bce, révision épinglée) |
| Wi-Fi Broadcom, Bluetooth BCM4377, SMC, NVMe, `hid-apple` | noyau Void 6.18 (déjà activés) |
| Wi-Fi: firmware | script officiel t2linux, à lancer à la main (`t2-wifi-firmware`) |
| Ventilateurs | `t2fanrd` (Rust, compilé avec cargo) + service runit, valeurs Omarchy |
| Audio: haut-parleurs / casque | profils ALSA UCM du dépôt t2bce |
| **Touch Bar** | **non supporté** : la config du noyau Void n'active pas `HID_APPLETB_*` ni `DRM_APPLETBDRM` |

Réglages appliqués : paramètres noyau `intel_iommu=on iommu=pt pm_async=off mem_sleep_default=deep` (suspension stable), `brcmfmac.feature_disable=0x82000` (wpa_supplicant 2.11+ casse le Wi-Fi Broadcom), modules chargés au démarrage (`/etc/modules-load.d/t2.conf`) et ajoutés à l'initramfs dracut.

## Avant d'installer (sur macOS)

1. Recovery (Cmd+R au démarrage) > Utilitaire de sécurité de démarrage : sécurité **Aucune sécurité**, **autoriser le démarrage depuis un support externe**.
2. Un **clavier et une souris USB** et un **adaptateur Ethernet USB** : sans `t2bce`, clavier, trackpad et Wi-Fi internes ne marchent pas pendant l'installation.
3. Démarrer l'ISO Void avec la touche **Option** (choisir "EFI Boot").

## Installer

```
./install-void.sh --disk /dev/nvme0n1 --user thomas --profile baremetal
```

Attention : `install-void.sh` utilise **tout le disque** et **efface macOS**. Pas de double démarrage pour l'instant. Pour garder macOS, installer sur un SSD externe (`--disk /dev/sdX`).

Le bootstrap détecte la puce T2, installe les en-têtes et DKMS, compile `t2bce`, configure le démarrage, les ventilateurs et l'audio.

## Après le premier démarrage

1. Wi-Fi/Bluetooth : `t2-wifi-firmware`, méthode 5 (sans macOS, télécharge l'image de récupération Apple ; choisir macOS Monterey à Sonoma), puis redémarrer.
2. Vérifier : `lsmod | grep -E 't2bce|hci_bcm4377|brcmfmac'` et `dmesg | grep -iE 'brcmfmac|t2bce'`.
3. Ventilateurs : `sudo sv status /var/service/t2fanrd`.

## Statut

Aucune de ces étapes n'a été testée sur un vrai Mac T2 (la VM n'a pas de puce T2). Testé seulement : la syntaxe des scripts et la compilation des modules contre le noyau Void 6.18.

Réutilisation : `./hardware/mac-t2/setup.sh --only dkms|boot|audio|fan|tools` (`T2_FORCE=1` pour forcer sans puce détectée).

Sources : [t2linux](https://wiki.t2linux.org/), [t2bce](https://github.com/AdityaGarg8/t2bce), [Omarchy fix-t2.sh](https://github.com/omacom/omarchy/blob/quattro/install/hardware/apple/fix-t2.sh).
