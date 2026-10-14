#!/bin/bash
# Support des Mac Intel à puce T2 (MacBook Pro/Air 2018-2020, Mac mini 2018, iMac 2020, iMac Pro, Mac Pro 2019).
# Approche inspirée d'Omarchy (install/hardware/apple/fix-t2.sh), adaptée à Void:
# xbps + DKMS (pas de noyau linux-t2), dracut, GRUB, runit.
#
#   ./setup.sh [--check] [--only dkms|boot|audio|fan|tools]
#
# --check: affiche si une puce T2 est détectée (code 0 = oui) puis quitte.
# Appelé automatiquement par bootstrap.sh quand une puce T2 est détectée.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"

# Pilotes t2bce (clavier, trackpad, audio): successeur d'apple-bce, épinglé pour la reproductibilité
T2BCE_REPO="https://github.com/AdityaGarg8/t2bce"
T2BCE_REF="d493b0696b133ef2a3e2192790758180d62886b0"
T2BCE_VER="0.0+git${T2BCE_REF:0:7}"
# Démon de ventilateurs (GPL-3.0), compilé avec cargo
FAN_REPO="https://github.com/GnomedDev/T2FanRD"
FAN_REF="48baf962697ec3d4d969c74cf601ee8e15b7aeaa"
# Script officiel t2linux (licence MIT) pour récupérer le firmware Wi-Fi/Bluetooth
FIRMWARE_URL="https://wiki.t2linux.org/tools/firmware.sh"

# Paramètres noyau (Omarchy): IOMMU, veille profonde stable avec t2bce
KERNEL_PARAMS=(intel_iommu=on iommu=pt pm_async=off mem_sleep_default=deep)
# wpa_supplicant >= 2.11 casse le Wi-Fi Broadcom (t2linux): contournement côté pilote
WIFI_PARAM="brcmfmac.feature_disable=0x82000"

log() { printf '\n[t2] %s\n' "$*"; }
warn() { printf '[t2] AVERTISSEMENT: %s\n' "$*" >&2; }

# Pas de `grep -q` dans un pipe: avec pipefail, SIGPIPE ferait croire à "pas de T2" (cf. Omarchy #6608)
is_t2() { lspci -nn 2>/dev/null | grep -E '106b:180[12]' >/dev/null; }

ONLY=""
while [ $# -gt 0 ]; do
    case "$1" in
        --check)
            if is_t2; then echo "Puce T2 détectée"; exit 0; else echo "Pas de puce T2"; exit 1; fi ;;
        --only) ONLY="${2:?}"; shift 2 ;;
        -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
        *) echo "Option inconnue: $1" >&2; exit 1 ;;
    esac
done

[ "$(id -u)" -eq 0 ] || exec sudo "$0" "$@"
want() { [ -z "$ONLY" ] || [ "$ONLY" = "$1" ]; }

read_list() { sed -e 's/#.*//' -e 's/[[:space:]]*$//' "$1" | grep -v '^$' || true; }

# Récupère une révision précise sans l'historique complet
fetch_ref() { # fetch_ref DEPOT REF DESTINATION
    local repo="$1" ref="$2" dest="$3" tmp
    tmp="$(mktemp -d)"
    git -C "$tmp" init -q
    git -C "$tmp" remote add origin "$repo"
    git -C "$tmp" fetch -q --depth 1 origin "$ref"
    git -C "$tmp" checkout -q FETCH_HEAD
    rm -rf "$tmp/.git"
    mkdir -p "$(dirname "$dest")"
    rm -rf "$dest"
    mv "$tmp" "$dest"
}

setup_packages() {
    log "Paquets (dkms, en-têtes noyau, alsa-ucm-conf, outils firmware)"
    xbps-install -y $(read_list "$ROOT/packages/mac-t2.txt")
}

installed_kernels() { # versions dont les en-têtes sont présents
    local d
    for d in /lib/modules/*/build; do
        [ -e "$d" ] && basename "$(dirname "$d")"
    done
}

setup_dkms() {
    log "Pilotes t2bce via DKMS ($T2BCE_VER)"
    local src="/usr/src/t2bce-$T2BCE_VER" k
    [ -d "$src" ] || fetch_ref "$T2BCE_REPO" "$T2BCE_REF" "$src"

    # Le dépôt amont n'a pas de dkms.conf: on construit les 4 modules dans l'ordre des dépendances
    cat > "$src/dkms.conf" <<EOF
PACKAGE_NAME="t2bce"
PACKAGE_VERSION="$T2BCE_VER"
AUTOINSTALL="yes"
MAKE[0]="make -C t2bce_dma KVERSION=\${kernelver} && make -C t2bce_core KVERSION=\${kernelver} T2BCE_DMA_SRC=../t2bce_dma && make -C t2bce_vhci KVERSION=\${kernelver} T2BCE_CORE_SRC=../t2bce_core && make -C t2bce_audio KVERSION=\${kernelver} T2BCE_CORE_SRC=../t2bce_core"
CLEAN="make -C t2bce_audio clean; make -C t2bce_vhci clean; make -C t2bce_core clean; make -C t2bce_dma clean"
BUILT_MODULE_NAME[0]="t2bce_dma"
BUILT_MODULE_LOCATION[0]="t2bce_dma/"
DEST_MODULE_LOCATION[0]="/extra/t2bce"
BUILT_MODULE_NAME[1]="t2bce_core"
BUILT_MODULE_LOCATION[1]="t2bce_core/"
DEST_MODULE_LOCATION[1]="/extra/t2bce"
BUILT_MODULE_NAME[2]="t2bce_vhci"
BUILT_MODULE_LOCATION[2]="t2bce_vhci/"
DEST_MODULE_LOCATION[2]="/extra/t2bce"
BUILT_MODULE_NAME[3]="t2bce_audio"
BUILT_MODULE_LOCATION[3]="t2bce_audio/"
DEST_MODULE_LOCATION[3]="/extra/t2bce"
EOF

    dkms status -m t2bce -v "$T2BCE_VER" 2>/dev/null | grep -E 'added|built|installed' >/dev/null \
        || dkms add -m t2bce -v "$T2BCE_VER"
    local found=0
    for k in $(installed_kernels); do
        found=1
        if dkms status -m t2bce -v "$T2BCE_VER" -k "$k" 2>/dev/null | grep -E 'installed' >/dev/null; then
            echo "t2bce déjà installé pour $k"
        else
            dkms install -m t2bce -v "$T2BCE_VER" -k "$k"
        fi
    done
    [ "$found" -eq 1 ] || warn "aucun noyau avec en-têtes trouvé (paquet linux-headers ?)"
}

cmdline_add() { # cmdline_add PARAM : ajoute à GRUB_CMDLINE_LINUX_DEFAULT s'il manque
    local p="$1" key="${1%%=*}"
    grep -E "^GRUB_CMDLINE_LINUX_DEFAULT=.*[\" ]${key}([= \"])" /etc/default/grub >/dev/null && return 0
    sed -i -E "s|^(GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*)\"|\1 ${p}\"|" /etc/default/grub
}

setup_boot() {
    log "Chargement des modules, initramfs et paramètres noyau"
    mkdir -p /etc/modules-load.d /etc/dracut.conf.d
    cat > /etc/modules-load.d/t2.conf <<'EOF'
# Clavier/trackpad internes (USB virtuel via t2bce), audio, Bluetooth, capteurs
t2bce_vhci
t2bce_audio
hci_bcm4377
applesmc
EOF
    # Clavier disponible dès l'initramfs (add_drivers: ignoré proprement si un module manque)
    cat > /etc/dracut.conf.d/t2.conf <<'EOF'
add_drivers+=" t2bce_dma t2bce_core t2bce_vhci usbhid hid_apple hid_generic xhci_pci xhci_hcd "
EOF

    if [ -f /etc/default/grub ]; then
        local p
        for p in "${KERNEL_PARAMS[@]}"; do cmdline_add "$p"; done
        if xbps-query wpa_supplicant >/dev/null 2>&1; then cmdline_add "$WIFI_PARAM"; fi
        grep GRUB_CMDLINE_LINUX_DEFAULT /etc/default/grub
        if [ -d /boot/grub ] && command -v grub-mkconfig >/dev/null; then
            grub-mkconfig -o /boot/grub/grub.cfg 2>&1 | tail -1
        fi
    else
        warn "/etc/default/grub introuvable: ajouter à la main ${KERNEL_PARAMS[*]}"
    fi

    command -v dracut >/dev/null && dracut --force --regenerate-all 2>&1 | tail -2 || true
}

setup_audio() {
    log "Profils ALSA UCM (haut-parleurs / casque)"
    local src="/usr/src/t2bce-$T2BCE_VER"
    [ -d "$src" ] || fetch_ref "$T2BCE_REPO" "$T2BCE_REF" "$src"
    mkdir -p /usr/share/alsa/ucm2
    cp -a "$src/t2bce_audio-alsa-ucm-conf/ucm2/." /usr/share/alsa/ucm2/
}

setup_fan() {
    log "Ventilateurs (t2fanrd)"
    if ! command -v t2fanrd >/dev/null; then
        command -v cargo >/dev/null || { warn "cargo absent, ventilateurs non configurés"; return 0; }
        local tmp
        tmp="$(mktemp -d)"
        fetch_ref "$FAN_REPO" "$FAN_REF" "$tmp/src"
        (cd "$tmp/src" && cargo build --release --locked)
        install -m 0755 "$tmp/src/target/release/t2fanrd" /usr/local/bin/t2fanrd
        rm -rf "$tmp"
    fi
    # Une section par ventilateur détecté ; les sections en trop sont ignorées (valeurs Omarchy)
    if [ ! -f /etc/t2fand.conf ]; then
        cat > /etc/t2fand.conf <<'EOF'
[Fan1]
low_temp=55
high_temp=75
speed_curve=linear
always_full_speed=false

[Fan2]
low_temp=55
high_temp=75
speed_curve=linear
always_full_speed=false
EOF
    fi
    mkdir -p /etc/sv/t2fanrd
    cat > /etc/sv/t2fanrd/run <<'EOF'
#!/bin/sh
exec 2>&1
exec /usr/local/bin/t2fanrd
EOF
    chmod 755 /etc/sv/t2fanrd/run
    ln -sfn /etc/sv/t2fanrd /etc/runit/runsvdir/default/t2fanrd
}

setup_tools() {
    log "Outil firmware Wi-Fi/Bluetooth (t2-wifi-firmware)"
    cat > /usr/local/bin/t2-wifi-firmware <<EOF
#!/bin/sh
# Télécharge et lance le script officiel t2linux (MIT) qui récupère le firmware Broadcom.
# Méthode 5 = sans macOS (télécharge l'image de récupération Apple). Dépendances: curl, dmg2img, python3.
set -e
tmp=\$(mktemp)
trap 'rm -f "\$tmp"' EXIT
curl -fsSL "$FIRMWARE_URL" -o "\$tmp"
echo "Script récupéré: $FIRMWARE_URL"
exec bash "\$tmp"
EOF
    chmod 755 /usr/local/bin/t2-wifi-firmware
}

if ! is_t2 && [ -z "${T2_FORCE:-}" ]; then
    echo "Pas de puce T2 détectée (T2_FORCE=1 pour forcer)."
    exit 0
fi

[ -z "$ONLY" ] && setup_packages  # avec --only: dkms et linux-headers doivent déjà être installés
want dkms && setup_dkms
want audio && setup_audio
want boot && setup_boot
want fan && setup_fan
want tools && setup_tools
log "Terminé. Redémarrer, puis lancer t2-wifi-firmware pour le Wi-Fi/Bluetooth."
