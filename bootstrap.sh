#!/bin/bash
# Rejoue la configuration Void sur un système fraîchement installé. Idempotent.
#
#   ./bootstrap.sh [--profile auto|vm|baremetal] [--machine auto|generic|mac-t2]
#                  [--cpu auto|intel|amd|other] [--gpu auto|none|intel,amd,nvidia]
#                  [--arch auto|x86_64|aarch64|riscv64] [--system-only | --dotfiles-only | --plan]
#
# --plan: affiche les listes retenues pour la configuration et quitte, sans rien modifier (CI).
# --profile: environnement (VM ou machine physique). --machine: matériel, pour tout ce qui est
# spécifique à un modèle (hardware/<machine>/). --cpu/--gpu: firmware et pilotes (packages/cpu-*.txt,
# gpu-*.txt, machine physique seulement). --arch: architecture (binaires x86_64 seulement ignorés ailleurs).
# auto détecte; forcer permet de tester ailleurs (variables PROFILE, MACHINE, CPU_VENDOR,
# GPU_VENDORS, TARGET_ARCH équivalentes).
#
# Lancé en utilisateur normal (sudo requis) ou en root avec TARGET_USER=<nom>
# (cas du chroot de install-void.sh).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config.env
source "$ROOT/config.env"

PROFILE="${PROFILE:-auto}"
MACHINE="${MACHINE:-auto}"
CPU_VENDOR="${CPU_VENDOR:-auto}"
GPU_VENDORS="${GPU_VENDORS:-auto}"
TARGET_ARCH="${TARGET_ARCH:-auto}"
[ -z "${T2_FORCE:-}" ] || MACHINE=mac-t2  # ancien nom
DO_SYSTEM=1
DO_DOTFILES=1
PLAN=0
while [ $# -gt 0 ]; do
    case "$1" in
        --profile) PROFILE="${2:?profil manquant}"; shift 2 ;;
        --machine) MACHINE="${2:?machine manquante}"; shift 2 ;;
        --cpu) CPU_VENDOR="${2:?cpu manquant}"; shift 2 ;;
        --gpu) GPU_VENDORS="${2:?gpu manquant}"; shift 2 ;;
        --arch) TARGET_ARCH="${2:?architecture manquante}"; shift 2 ;;
        --plan) PLAN=1; shift ;;
        --system-only) DO_DOTFILES=0; shift ;;
        --dotfiles-only) DO_SYSTEM=0; shift ;;
        -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
        *) echo "Option inconnue: $1" >&2; exit 1 ;;
    esac
done

if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
    TARGET_USER="${TARGET_USER:?en root, définir TARGET_USER=<nom>}"
else
    SUDO="sudo"
    TARGET_USER="${TARGET_USER:-$USER}"
fi
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
[ -n "$TARGET_HOME" ] || { echo "Utilisateur introuvable: $TARGET_USER" >&2; exit 1; }

log() { printf '\n==> %s\n' "$*"; }
warn() { printf 'AVERTISSEMENT: %s\n' "$*" >&2; }

detect_profile() {
    if grep -q hypervisor /proc/cpuinfo; then echo vm; else echo baremetal; fi
}
[ "$PROFILE" = auto ] && PROFILE="$(detect_profile)"
case "$PROFILE" in vm|baremetal) ;; *) echo "Profil invalide: $PROFILE" >&2; exit 1 ;; esac

# Mac Intel à puce T2 (Apple 106b:1801/1802), via sysfs: lspci n'est pas forcément installé
detect_machine() {
    local d
    for d in /sys/bus/pci/devices/*; do
        [ "$(cat "$d/vendor" 2>/dev/null)" = 0x106b ] || continue
        case "$(cat "$d/device" 2>/dev/null)" in 0x1801|0x1802) echo mac-t2; return ;; esac
    done
    echo generic
}
[ "$MACHINE" = auto ] && MACHINE="$(detect_machine)"
case "$MACHINE" in generic|mac-t2) ;; *) echo "Machine invalide: $MACHINE (generic|mac-t2)" >&2; exit 1 ;; esac
export MACHINE

# Fabricant du CPU (intel|amd|other: ARM et RISC-V n'ont pas de vendor_id)
detect_cpu() {
    case "$(grep -m1 '^vendor_id' /proc/cpuinfo 2>/dev/null)" in
        *GenuineIntel*) echo intel ;;
        *AuthenticAMD*) echo amd ;;
        *) echo other ;;
    esac
}
# GPU présents (intel amd nvidia), via sysfs; vide si aucun reconnu (virtio, vmware, SoC...)
detect_gpus() {
    local d v out=""
    for d in /sys/class/drm/card[0-9]*/device/vendor; do
        [ -e "$d" ] || continue
        case "$(cat "$d")" in
            0x8086) v=intel ;; 0x1002) v=amd ;; 0x10de) v=nvidia ;; *) continue ;;
        esac
        case " $out " in *" $v "*) ;; *) out="${out:+$out }$v" ;; esac
    done
    echo "$out"
}
[ "$CPU_VENDOR" = auto ] && CPU_VENDOR="$(detect_cpu)"
[ "$TARGET_ARCH" = auto ] && TARGET_ARCH="$(uname -m)"
if [ "$GPU_VENDORS" = auto ]; then GPU_VENDORS="$(detect_gpus)"; fi
[ "$GPU_VENDORS" = none ] && GPU_VENDORS=""
GPU_VENDORS="${GPU_VENDORS//,/ }"
case "$CPU_VENDOR" in intel|amd|other) ;; *) echo "CPU invalide: $CPU_VENDOR (intel|amd|other)" >&2; exit 1 ;; esac
case "$TARGET_ARCH" in x86_64|aarch64|riscv64) ;; *) warn "architecture non prévue: $TARGET_ARCH" ;; esac
for g in $GPU_VENDORS; do
    [ -f "$ROOT/packages/gpu-$g.txt" ] || { echo "GPU invalide: $g (intel|amd|nvidia|none)" >&2; exit 1; }
done
log "Profil: $PROFILE, machine: $MACHINE, arch: $TARGET_ARCH, cpu: $CPU_VENDOR, gpu: ${GPU_VENDORS:-aucun}, utilisateur: $TARGET_USER"

# Liste sans commentaires ni lignes vides
read_list() { sed -e 's/#.*//' -e 's/[[:space:]]*$//' "$1" | grep -v '^$' || true; }

# Listes retenues pour la configuration (profil, CPU, GPU, machine), dans l'ordre d'installation
package_lists() {
    echo "$ROOT/packages/base.txt" "$ROOT/packages/desktop.txt" "$ROOT/packages/dev.txt" "$ROOT/packages/$PROFILE.txt"
}
hardware_package_lists() { # dépôt nonfree requis (microcode), machine physique seulement
    local g
    echo "$ROOT/packages/cpu-$CPU_VENDOR.txt"
    for g in $GPU_VENDORS; do echo "$ROOT/packages/gpu-$g.txt"; done
}
service_lists() { echo "$ROOT/services/common.txt" "$ROOT/services/$PROFILE.txt"; }

# --plan: affiche la configuration résolue et vérifie que les listes existent, sans rien modifier
print_plan() {
    local f rc=0 pkgs=""
    pkgs="$(package_lists)"
    [ "$PROFILE" = baremetal ] && pkgs="$pkgs $(hardware_package_lists)"
    [ "$MACHINE" = mac-t2 ] && pkgs="$pkgs $ROOT/packages/mac-t2.txt"
    for f in $pkgs $(service_lists); do
        if [ -f "$f" ]; then echo "${f#"$ROOT/"}"; elif [[ "$f" == */cpu-other.txt ]]; then echo "${f#"$ROOT/"} (aucune liste)"; else
            echo "MANQUANT: ${f#"$ROOT/"}" >&2; rc=1
        fi
    done
    [ -d "$ROOT/hardware/$MACHINE" ] && echo "hardware/$MACHINE"
    return $rc
}

install_list() {
    local file="$1" pkg
    local -a ok=()
    [ -f "$file" ] || return 0  # ex. cpu-other.txt: rien à installer
    for pkg in $(read_list "$file"); do
        if xbps-query "$pkg" >/dev/null 2>&1; then echo "SKIP: $pkg déjà installé"
        elif xbps-query -R "$pkg" >/dev/null 2>&1; then ok+=("$pkg")
        else warn "paquet introuvable: $pkg"; fi
    done
    [ ${#ok[@]} -gt 0 ] && $SUDO xbps-install -y "${ok[@]}"
    return 0
}

set_rc() { # set_rc CLE VALEUR dans /etc/rc.conf
    local key="$1" val="$2"
    if $SUDO grep -qE "^#?${key}=" /etc/rc.conf; then
        $SUDO sed -i -E "s|^#?${key}=.*|${key}=\"${val}\"|" /etc/rc.conf
    else
        echo "${key}=\"${val}\"" | $SUDO tee -a /etc/rc.conf >/dev/null
    fi
}

setup_system() {
    log "Dépôts et mise à jour"
    $SUDO xbps-install -Syu xbps
    $SUDO xbps-install -Syu

    log "Paquets"
    local list
    for list in $(package_lists); do install_list "$list"; done
    if [ "$PROFILE" = baremetal ]; then
        if xbps-query void-repo-nonfree >/dev/null 2>&1; then echo "SKIP: void-repo-nonfree déjà installé"
        else $SUDO xbps-install -y void-repo-nonfree; fi
        $SUDO xbps-install -S
        for list in $(hardware_package_lists); do install_list "$list"; done
    fi

    log "Nettoyage du cache xbps (disque réduit)"
    $SUDO xbps-remove -yO >/dev/null || true

    log "Services runit"
    local svc
    for list in $(service_lists); do
        [ -f "$list" ] || continue
        for svc in $(read_list "$list"); do
            if [ -d "/etc/sv/$svc" ]; then
                $SUDO ln -sfn "/etc/sv/$svc" "/etc/runit/runsvdir/default/$svc"
            else
                warn "service introuvable: $svc"
            fi
        done
    done

    # Services retirés des listes: désactivés s'ils l'étaient (acpid: elogind gère le capot,
    # et handler.sh mettait en veille capot fermé même avec des écrans externes; agetty-tty3 à 6:
    # deux consoles texte suffisent, tty1 pour la session et tty2 en secours)
    for svc in acpid agetty-tty3 agetty-tty4 agetty-tty5 agetty-tty6; do
        if [ -L "/etc/runit/runsvdir/default/$svc" ]; then
            $SUDO sv down "/var/service/$svc" 2>/dev/null || true
            $SUDO rm -f "/etc/runit/runsvdir/default/$svc"
        fi
    done

    log "Pare-feu (iptables/ip6tables: entrant refusé par défaut)"
    $SUDO install -d /etc/iptables
    $SUDO install -m 644 "$ROOT/system/iptables/iptables.rules" "$ROOT/system/iptables/ip6tables.rules" /etc/iptables/
    for svc in iptables ip6tables; do
        $SUDO ln -sfn "/etc/sv/$svc" "/etc/runit/runsvdir/default/$svc"
    done

    if [ "$PROFILE" != vm ]; then
        log "Profil CPU selon batterie/secteur (règle udev)"
        $SUDO install -m 644 "$ROOT/system/udev/90-power-profile.rules" /etc/udev/rules.d/
        $SUDO udevadm control --reload
        $SUDO udevadm trigger --subsystem-match=power_supply --action=change

        log "Pilote de l'imprimante Dell 1350cnw (HBPL v1, compilé dans /usr/local)"
        [ -x /usr/local/bin/foo2hbpl1 ] || "$ROOT/drivers/dell-1350cnw/install.sh" || warn "pilote Dell non installé"
    fi

    log "Réglages noyau (sysctl), earlyoom et zram"
    $SUDO install -d /etc/sysctl.d
    $SUDO install -m 644 "$ROOT/system/sysctl/90-hardening.conf" /etc/sysctl.d/
    $SUDO sysctl -q --system || warn "sysctl --system a échoué"
    [ -d /etc/sv/earlyoom ] && $SUDO install -m 644 "$ROOT/system/earlyoom.conf" /etc/sv/earlyoom/conf
    [ -d /etc/sv/zramen ] && $SUDO install -m 644 "$ROOT/system/zramen.conf" /etc/sv/zramen/conf

    log "Capot géré par niri (~/.local/bin/lid), pas par elogind"
    $SUDO install -d /etc/elogind/logind.conf.d
    $SUDO install -m 644 "$ROOT/system/elogind/10-lid.conf" /etc/elogind/logind.conf.d/

    log "Connexion automatique tty1"
    local conf=/etc/sv/agetty-tty1/conf autologin="$AUTOLOGIN"
    [ "$autologin" = auto ] && { [ "$PROFILE" = vm ] && autologin=1 || autologin=0; }
    if [ "$autologin" = 1 ]; then
        $SUDO sed -i -E "s|GETTY_ARGS=\"(--autologin [^ ]+ )?--noclear\"|GETTY_ARGS=\"--autologin $TARGET_USER --noclear\"|" "$conf"
        # l'autologin doit attendre elogind (sinon /run/user est masqué, cf. le script)
        $SUDO "$ROOT/scripts/tty1-wait-elogind.sh" on >/dev/null
    else
        $SUDO sed -i -E 's|GETTY_ARGS="--autologin [^ ]+ --noclear"|GETTY_ARGS="--noclear"|' "$conf"
        $SUDO "$ROOT/scripts/tty1-wait-elogind.sh" off >/dev/null
    fi
    grep -n GETTY_ARGS "$conf"

    log "PipeWire: wireplumber et pipewire-pulse lancés par pipewire (méthode Void)"
    $SUDO mkdir -p /etc/pipewire/pipewire.conf.d
    $SUDO ln -sfn /usr/share/examples/wireplumber/10-wireplumber.conf /etc/pipewire/pipewire.conf.d/10-wireplumber.conf
    $SUDO ln -sfn /usr/share/examples/pipewire/20-pipewire-pulse.conf /etc/pipewire/pipewire.conf.d/20-pipewire-pulse.conf

    log "DNS (resolv.conf géré par resolvconf/dhcpcd)"
    # Un resolv.conf copié d'ailleurs (ex. install depuis un autre système) bloque resolvconf
    # ("signature mismatch"). On ne le remplace que si dhcpcd a déjà fourni des serveurs DNS.
    if ! grep -q 'Generated by resolvconf' /etc/resolv.conf 2>/dev/null \
        && $SUDO resolvconf -l 2>/dev/null | grep -q '^nameserver'; then
        $SUDO mv /etc/resolv.conf /etc/resolv.conf.bak
        $SUDO resolvconf -u
    fi
    grep '^nameserver' /etc/resolv.conf || warn "pas de serveur DNS dans /etc/resolv.conf"

    log "Réglages système (clavier, fuseau, locale)"
    set_rc KEYMAP "$KEYMAP"
    set_rc TIMEZONE "$TIMEZONE"
    $SUDO ln -sfn "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
    echo "LANG=$LOCALE" | $SUDO tee /etc/locale.conf >/dev/null
    if [ "$LOCALE" != "C.UTF-8" ] && [ -f /etc/default/libc-locales ]; then
        $SUDO sed -i "s/^#\(${LOCALE//./\\.} \)/\1/" /etc/default/libc-locales
        $SUDO xbps-reconfigure -f glibc-locales
    fi

    log "Utilisateur $TARGET_USER"
    local g
    for g in $USER_GROUPS; do
        if getent group "$g" >/dev/null; then $SUDO usermod -aG "$g" "$TARGET_USER"; fi
    done
    if [ -x /bin/zsh ] && [ "$(getent passwd "$TARGET_USER" | cut -d: -f7)" != "/bin/zsh" ]; then
        $SUDO chsh -s /bin/zsh "$TARGET_USER"
    fi
    echo '%wheel ALL=(ALL:ALL) ALL' | $SUDO tee /etc/sudoers.d/wheel >/dev/null
    $SUDO chmod 440 /etc/sudoers.d/wheel
    $SUDO visudo -cf /etc/sudoers.d/wheel >/dev/null
    # Les fichiers NOPASSWD portent le préfixe zz- : sudoers applique la dernière règle qui correspond,
    # et wheel (mot de passe) doit donc être lu avant eux. Anciens noms nettoyés au passage.
    $SUDO rm -f /etc/sudoers.d/power /etc/sudoers.d/claude
    # Menu Système: éteindre, redémarrer, veille sans mot de passe (pas de polkit sur cette machine)
    echo '%wheel ALL=(root) NOPASSWD: /usr/bin/zzz, /usr/bin/reboot, /usr/bin/poweroff' | $SUDO tee /etc/sudoers.d/zz-power >/dev/null
    $SUDO chmod 440 /etc/sudoers.d/zz-power
    $SUDO visudo -cf /etc/sudoers.d/zz-power >/dev/null
    # Claude Code (agent OS): sv et xbps sans mot de passe; la confirmation reste côté Claude Code (permissions "ask")
    echo "$TARGET_USER ALL=(root) NOPASSWD: /usr/bin/sv, /usr/bin/xbps-install, /usr/bin/xbps-remove, /usr/bin/xbps-query, /usr/bin/xbps-reconfigure" | $SUDO tee /etc/sudoers.d/zz-claude >/dev/null
    $SUDO chmod 440 /etc/sudoers.d/zz-claude
    $SUDO visudo -cf /etc/sudoers.d/zz-claude >/dev/null

    # Matériel spécifique: hardware/<machine>/ (generic n'a rien)
    if [ "$MACHINE" = mac-t2 ]; then
        # Double démarrage LUKS + btrfs + Limine (fichier créé par hardware/mac-t2/dualboot.sh)
        if [ -f /etc/kernel/cmdline ]; then
            log "Double démarrage (dualboot.sh)"
            $SUDO "$ROOT/hardware/mac-t2/dualboot.sh"
        fi
        log "Mac à puce T2"
        $SUDO env T2_FORCE=1 "$ROOT/hardware/mac-t2/setup.sh"
    fi
}

run_as_user() {
    if [ "$(id -u)" -eq 0 ]; then
        runuser -u "$TARGET_USER" -- env HOME="$TARGET_HOME" "$@"
    else
        "$@"
    fi
}

# CLI officielle Proton Drive (pas dans les dépôts Void): binaire épinglé, vérifié par SHA-512
PROTON_DRIVE_VER="0.9.0"
PROTON_DRIVE_SHA512="3533025ba69ae112b64e3e01fbcc1ad0688136a4043f6cf6a72886967d85fdcd9ec235479c2e113171614be5225bfba93427509a05ca5aa6071d924fa7e91ca8"

setup_proton_drive() {
    log "Proton Drive CLI $PROTON_DRIVE_VER"
    [ "$TARGET_ARCH" = x86_64 ] || { warn "Proton Drive CLI: binaire x86_64 seulement, ignoré sur $TARGET_ARCH"; return 0; }
    local dir="$TARGET_HOME/.local/opt/proton-drive-$PROTON_DRIVE_VER"
    if [ ! -x "$dir/proton-drive" ]; then
        run_as_user mkdir -p "$dir"
        run_as_user curl -fsSL "https://proton.me/download/drive/cli/$PROTON_DRIVE_VER/linux-x64/proton-drive" -o "$dir/proton-drive.tmp" \
            || { warn "téléchargement de Proton Drive CLI échoué"; return 0; }
        if ! echo "$PROTON_DRIVE_SHA512  $dir/proton-drive.tmp" | sha512sum -c --quiet; then
            rm -f "$dir/proton-drive.tmp"; warn "somme SHA-512 de Proton Drive CLI incorrecte"; return 0
        fi
        run_as_user chmod 755 "$dir/proton-drive.tmp"
        run_as_user mv "$dir/proton-drive.tmp" "$dir/proton-drive"
    fi
    run_as_user mkdir -p "$TARGET_HOME/.local/bin"
    run_as_user ln -sfn "$dir/proton-drive" "$TARGET_HOME/.local/bin/proton-drive"
    echo "connexion: proton-drive auth login (trousseau requis, voir README)"
}

# whatsapp-unreadd (démon Go, ~23 Mo: compteur de non-lus WhatsApp + notifications, pas dans les dépôts Void):
# compilé depuis un commit épinglé (le hash fixe le contenu, go.sum celui des dépendances)
WA_UNREADD_COMMIT="44a1688cb55d93236e886d242cc008ff8c3cbfa9"

setup_whatsapp_unreadd() {
    log "whatsapp-unreadd ${WA_UNREADD_COMMIT:0:7}"
    local dir="$TARGET_HOME/.local/opt/whatsapp-unreadd-${WA_UNREADD_COMMIT:0:7}"
    if [ ! -x "$dir/whatsapp-unreadd" ]; then
        command -v go >/dev/null || { warn "go absent (packages/dev.txt): whatsapp-unreadd non compilé"; return 0; }
        local src; src="$(run_as_user mktemp -d)"
        if run_as_user git clone -q https://github.com/m-brl/whatsapp-unreadd "$src" \
            && run_as_user git -C "$src" checkout -q "$WA_UNREADD_COMMIT" \
            && run_as_user mkdir -p "$dir" \
            && (cd "$src" && run_as_user env CGO_ENABLED=0 GOFLAGS=-mod=readonly go build -trimpath -ldflags='-s -w' -o "$dir/whatsapp-unreadd" .); then
            :
        else
            warn "compilation de whatsapp-unreadd échouée"; run_as_user rm -rf "$src" "$dir"; return 0
        fi
        run_as_user rm -rf "$src"
    fi
    run_as_user mkdir -p "$TARGET_HOME/.local/bin"
    run_as_user ln -sfn "$dir/whatsapp-unreadd" "$TARGET_HOME/.local/bin/whatsapp-unreadd"
    [ -e "$TARGET_HOME/.config/whatsapp-unread/paired" ] || echo "appairage: wa-pair (QR code à scanner depuis WhatsApp > Appareils liés)"
}

# Outils maison (apps/<nom>, Rust): binaires natifs plutôt que scripts Python/GTK, pour que l'OS reste léger.
# Compilés en release dans ~/.local/opt/<nom>-<empreinte des sources>, liés dans ~/.local/bin; recompilés
# seulement quand les sources changent. Le dossier de compilation (target/) reste hors du dépôt, dans ~/.cache.
setup_apps() {
    local manifest app name sum dir
    for manifest in "$ROOT"/apps/*/Cargo.toml; do
        [ -e "$manifest" ] || return 0
        command -v cargo >/dev/null || { warn "cargo absent (packages/dev.txt): apps/ non compilées"; return 0; }
        app="$(dirname "$manifest")"; name="$(basename "$app")"
        sum="$(cd "$app" && find Cargo.toml Cargo.lock src -type f | sort | xargs cat | sha256sum | cut -c1-12)"
        dir="$TARGET_HOME/.local/opt/$name-$sum"
        if [ ! -x "$dir/$name" ]; then
            log "Compilation de $name ($sum)"
            if run_as_user env CARGO_TARGET_DIR="$TARGET_HOME/.cache/void-setup-apps" \
                    cargo build -q --release --locked --manifest-path "$manifest" \
                && run_as_user mkdir -p "$dir" \
                && run_as_user cp "$TARGET_HOME/.cache/void-setup-apps/release/$name" "$dir/$name"; then
                # anciennes versions
                find "$TARGET_HOME/.local/opt" -maxdepth 1 -name "$name-*" ! -name "$name-$sum" -exec rm -rf {} +
            else
                warn "compilation de $name échouée"; run_as_user rm -rf "$dir"; continue
            fi
        fi
        run_as_user mkdir -p "$TARGET_HOME/.local/bin"
        run_as_user ln -sfn "$dir/$name" "$TARGET_HOME/.local/bin/$name"
    done
}

# Paquets restricted (packages/restricted.txt): construits avec xbps-src dans un clone de void-packages.
# Mise à jour: git pull dans le clone, ./xbps-src pkg <paquet>, puis xbps-install -u -R <dépôt local> <paquet>
VOID_PACKAGES="${VOID_PACKAGES:-$TARGET_HOME/Projects/void-packages}"

setup_restricted() {
    local pkg
    local -a todo=() repos=()
    for pkg in $(read_list "$ROOT/packages/restricted.txt"); do
        if xbps-query "$pkg" >/dev/null 2>&1; then echo "SKIP: $pkg déjà installé"; else todo+=("$pkg"); fi
    done
    [ ${#todo[@]} -gt 0 ] || return 0
    log "Paquets restricted (xbps-src): ${todo[*]}"
    if [ ! -x "$VOID_PACKAGES/xbps-src" ]; then
        run_as_user git clone -q --depth 1 https://github.com/void-linux/void-packages "$VOID_PACKAGES" \
            || { warn "clone de void-packages échoué"; return 0; }
    fi
    grep -qx 'XBPS_ALLOW_RESTRICTED=yes' "$VOID_PACKAGES/etc/conf" 2>/dev/null \
        || echo 'XBPS_ALLOW_RESTRICTED=yes' | run_as_user tee -a "$VOID_PACKAGES/etc/conf" >/dev/null
    if ! compgen -G "$VOID_PACKAGES/masterdir*" >/dev/null; then
        (cd "$VOID_PACKAGES" && run_as_user ./xbps-src binary-bootstrap) || { warn "xbps-src binary-bootstrap échoué"; return 0; }
    fi
    for pkg in "${todo[@]}"; do
        (cd "$VOID_PACKAGES" && run_as_user ./xbps-src pkg "$pkg") || warn "construction de $pkg échouée"
    done
    # dépôts locaux produits par xbps-src (hostdir/binpkgs/<branche>/nonfree...)
    mapfile -t repos < <(find "$VOID_PACKAGES/hostdir/binpkgs" -name '*-repodata' -printf '%h\n' | sort -u)
    [ ${#repos[@]} -gt 0 ] || return 0
    $SUDO xbps-install -y "${repos[@]/#/--repository=}" "${todo[@]}" || warn "installation de ${todo[*]} échouée"
}

setup_claude() {
    log "Claude Code"
    if [ -x "$TARGET_HOME/.local/bin/claude" ]; then
        echo "déjà installé"
        return 0
    fi
    run_as_user bash -c 'curl -fsSL https://claude.ai/install.sh | bash' \
        || warn "installation de Claude Code échouée (réseau ?), relancer bootstrap.sh"
}

link_one() { # link_one SOURCE DESTINATION
    local src="$1" dst="$2"
    mkdir -p "$(dirname "$dst")"
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        mv "$dst" "$dst.bak.$(date +%Y%m%d%H%M%S)"
    fi
    ln -sfn "$src" "$dst"
    if [ "$(id -u)" -eq 0 ]; then
        # en root, les dossiers créés (~/.config, ~/.local/share...) doivent appartenir à l'utilisateur
        local d="$dst"
        while [ "$d" != "$TARGET_HOME" ] && [ "$d" != / ]; do
            chown -h "$TARGET_USER:" "$d"
            d="$(dirname "$d")"
        done
    fi
}

link_tree() { # link_tree DOSSIER : DOSSIER/home -> ~, DOSSIER/config -> ~/.config
    local f
    if [ -d "$1/home" ]; then
        while IFS= read -r -d '' f; do
            link_one "$f" "$TARGET_HOME/${f#"$1/home/"}"
        done < <(find "$1/home" -type f -print0)
    fi
    if [ -d "$1/config" ]; then
        while IFS= read -r -d '' f; do
            link_one "$f" "$TARGET_HOME/.config/${f#"$1/config/"}"
        done < <(find "$1/config" -type f -print0)
    fi
}

setup_dotfiles() {
    log "Dotfiles (liens symboliques vers $ROOT/dotfiles)"
    link_tree "$ROOT/dotfiles"
    # Dotfiles propres au matériel (hardware/<machine>/dotfiles/{home,config})
    if [ -d "$ROOT/hardware/$MACHINE/dotfiles" ]; then
        log "Dotfiles de la machine $MACHINE"
        link_tree "$ROOT/hardware/$MACHINE/dotfiles"
    fi
    # .desktop des applications web (liste ~/.config/webapps/list)
    HOME="$TARGET_HOME" sh "$ROOT/dotfiles/home/.local/bin/webapp-sync"
    # Thème sombre par défaut (portail xdg: Chromium, GTK4, libadwaita); sans effet hors session D-Bus
    gsettings set org.gnome.desktop.interface color-scheme prefer-dark 2>/dev/null || warn "gsettings: color-scheme non appliqué (pas de session D-Bus)"
    # Thunar: Espace lance l'aperçu rapide (action "quicklook" de uca.xml). Thunar réécrit accels.scm
    # en quittant (un lien serait remplacé, l'ajout perdu): on le ferme puis on ajoute la ligne.
    local acc="$TARGET_HOME/.config/Thunar/accels.scm"
    local ql='(gtk_accel_path "<Actions>/ThunarActions/uca-action-quicklook" "space")'
    if ! grep -qxF "$ql" "$acc" 2>/dev/null; then
        log "Thunar: Espace = aperçu rapide (quicklook)"
        run_as_user thunar -q 2>/dev/null || true
        while pgrep -u "$TARGET_USER" -x Thunar >/dev/null; do sleep 0.2; done
        run_as_user mkdir -p "${acc%/*}"
        run_as_user sh -c 'printf "%s\n" "$1" >> "$2"' _ "$ql" "$acc"
    fi
    # Documents et Images dans iCloud Drive (~/iCloud, monté par icloud-mount): liens symboliques.
    # Un dossier local non vide n'est pas touché: déplacer son contenu dans ~/iCloud puis relancer.
    local d
    for d in Documents Pictures; do
        [ -L "$TARGET_HOME/$d" ] && continue
        if [ -d "$TARGET_HOME/$d" ] && ! rmdir "$TARGET_HOME/$d" 2>/dev/null; then
            warn "~/$d non vide: déplacer son contenu dans ~/iCloud/$d puis relancer bootstrap.sh"
            continue
        fi
        log "~/$d -> ~/iCloud/$d"
        run_as_user ln -s "iCloud/$d" "$TARGET_HOME/$d"
    done
    # Mac T2 (MacBookPro16,2): la route ALSA "Speaker" est cachée par le DSP (hide-parent), donc plus
    # réglable, et un volume bas sur elle atténue tout le DSP. WirePlumber n'a pas de règle de volume
    # par route: on la fixe à 1.0 dans son état, le volume se règle sur le DSP.
    if [ "$MACHINE" = mac-t2 ] && [ "$(cat /sys/class/dmi/id/product_name 2>/dev/null)" = MacBookPro16,2 ]; then
        local st="$TARGET_HOME/.local/state/wireplumber/default-routes"
        local line='alsa_card.pci-0000_e6_00.3:output:\oOut\c\sSpeaker={"latencyOffsetNsec":0, "mute":false, "channelVolumes":[1.000000, 1.000000, 1.000000, 1.000000], "channelMap":["FL", "FR", "RL", "RR"]}'
        run_as_user mkdir -p "${st%/*}"
        [ -f "$st" ] || run_as_user sh -c 'printf "[default-routes]\n" > "$1"' _ "$st"
        if ! grep -qxF "$line" "$st"; then
            log "Mac T2: volume de la route Speaker à 1.0 (relancer wireplumber pour l'appliquer)"
            sed -i '/:output:\\oOut\\c\\sSpeaker=/d' "$st"
            printf '%s\n' "$line" >> "$st"
        fi
    fi
}

if [ "$PLAN" -eq 1 ]; then print_plan; exit; fi
[ "$DO_SYSTEM" -eq 1 ] && setup_system
[ "$DO_DOTFILES" -eq 1 ] && setup_dotfiles
[ "$DO_DOTFILES" -eq 1 ] && setup_apps
[ "$DO_SYSTEM" -eq 1 ] && setup_claude
[ "$DO_SYSTEM" -eq 1 ] && setup_proton_drive
[ "$DO_SYSTEM" -eq 1 ] && setup_whatsapp_unreadd
[ "$DO_SYSTEM" -eq 1 ] && setup_restricted
log "Terminé"
