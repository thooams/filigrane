#!/bin/bash
# Installe Void Linux (glibc, x86_64, UEFI) sur un disque, puis rejoue bootstrap.sh.
# À lancer en root depuis l'ISO live Void, réseau actif, dépôt cloné/copié sur le live.
#
#   ./install-void.sh --disk /dev/sda [--user thomas] [--hostname void] [--profile auto|vm|baremetal]
#
# ATTENTION: efface TOUT le disque cible.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DISK=""
USERNAME="thomas"
HOSTNAME_="void"
PROFILE="auto"
REPO="${REPO:-https://repo-default.voidlinux.org/current}"

while [ $# -gt 0 ]; do
    case "$1" in
        --disk) DISK="${2:?}"; shift 2 ;;
        --user) USERNAME="${2:?}"; shift 2 ;;
        --hostname) HOSTNAME_="${2:?}"; shift 2 ;;
        --profile) PROFILE="${2:?}"; shift 2 ;;
        -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
        *) echo "Option inconnue: $1" >&2; exit 1 ;;
    esac
done

[ "$(id -u)" -eq 0 ] || { echo "Lancer en root" >&2; exit 1; }
[ -b "$DISK" ] || { echo "--disk <périphérique bloc> requis (ex: /dev/sda, /dev/nvme0n1)" >&2; exit 1; }
[ -d /sys/firmware/efi ] || { echo "Démarrage non UEFI: non supporté" >&2; exit 1; }
[ "$(uname -m)" = x86_64 ] || { echo "Architecture non x86_64" >&2; exit 1; }

# nvme0n1 -> nvme0n1p1, sda -> sda1
case "$DISK" in *[0-9]) P="${DISK}p" ;; *) P="$DISK" ;; esac

lsblk "$DISK"
echo
echo "Tout le contenu de $DISK sera EFFACÉ."
read -r -p "Retaper le chemin du disque pour confirmer: " confirm
[ "$confirm" = "$DISK" ] || { echo "Annulé."; exit 1; }

echo "==> Partitionnement"
wipefs -af "$DISK"
parted -s "$DISK" mklabel gpt \
    mkpart ESP fat32 1MiB 513MiB set 1 esp on \
    mkpart root ext4 513MiB 100%
partprobe "$DISK"; sleep 1
mkfs.vfat -F32 -n ESP "${P}1"
mkfs.ext4 -F -L void "${P}2"

echo "==> Montage"
mount "${P}2" /mnt
mkdir -p /mnt/boot/efi
mount "${P}1" /mnt/boot/efi

echo "==> Système de base"
mkdir -p /mnt/var/db/xbps/keys
cp /var/db/xbps/keys/* /mnt/var/db/xbps/keys/
XBPS_ARCH=x86_64 xbps-install -Sy -R "$REPO" -r /mnt base-system grub-x86_64-efi sudo git curl

echo "==> Chroot"
for d in dev proc sys; do
    mount --rbind "/$d" "/mnt/$d"
    mount --make-rslave "/mnt/$d"
done
cp /etc/resolv.conf /mnt/etc/resolv.conf

ROOT_UUID="$(blkid -s UUID -o value "${P}2")"
ESP_UUID="$(blkid -s UUID -o value "${P}1")"
cat > /mnt/etc/fstab <<EOF
UUID=$ROOT_UUID / ext4 defaults 0 1
UUID=$ESP_UUID /boot/efi vfat defaults 0 2
tmpfs /tmp tmpfs defaults,nosuid,nodev 0 0
EOF
echo "$HOSTNAME_" > /mnt/etc/hostname

chroot /mnt useradd -m -G wheel,audio,video -s /bin/bash "$USERNAME"
echo "Mot de passe root:"; chroot /mnt passwd root
echo "Mot de passe de $USERNAME:"; chroot /mnt passwd "$USERNAME"

echo "==> Bootstrap (paquets, services, dotfiles)"
cp -a "$ROOT" "/mnt/home/$USERNAME/void-setup"
chroot /mnt chown -R "$USERNAME:" "/home/$USERNAME/void-setup"
chroot /mnt env TARGET_USER="$USERNAME" "/home/$USERNAME/void-setup/bootstrap.sh" --profile "$PROFILE"

echo "==> Chargeur de démarrage"
# --removable: fonctionne sur tout PC/Mac Intel sans entrée NVRAM dédiée
chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=void --removable
chroot /mnt xbps-reconfigure -fa

umount -R /mnt
echo "Installation terminée. Retirer le média et redémarrer."
