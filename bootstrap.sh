#!/bin/bash
# Rejoue la configuration Void sur un système fraîchement installé. Idempotent.
#
#   ./bootstrap.sh [--profile auto|vm|baremetal] [--system-only | --dotfiles-only]
#
# Lancé en utilisateur normal (sudo requis) ou en root avec TARGET_USER=<nom>
# (cas du chroot de install-void.sh).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config.env
source "$ROOT/config.env"

PROFILE="auto"
DO_SYSTEM=1
DO_DOTFILES=1
while [ $# -gt 0 ]; do
    case "$1" in
        --profile) PROFILE="${2:?profil manquant}"; shift 2 ;;
        --system-only) DO_DOTFILES=0; shift ;;
        --dotfiles-only) DO_SYSTEM=0; shift ;;
        -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
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
log "Profil: $PROFILE, utilisateur: $TARGET_USER"

# Liste sans commentaires ni lignes vides
read_list() { sed -e 's/#.*//' -e 's/[[:space:]]*$//' "$1" | grep -v '^$' || true; }

install_list() {
    local file="$1" pkg
    local -a ok=()
    for pkg in $(read_list "$file"); do
        if xbps-query -R "$pkg" >/dev/null 2>&1; then ok+=("$pkg"); else warn "paquet introuvable: $pkg"; fi
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
    install_list "$ROOT/packages/base.txt"
    install_list "$ROOT/packages/desktop.txt"
    install_list "$ROOT/packages/dev.txt"
    install_list "$ROOT/packages/$PROFILE.txt"
    if [ "$PROFILE" = baremetal ]; then
        $SUDO xbps-install -y void-repo-nonfree
        $SUDO xbps-install -S
        install_list "$ROOT/packages/nonfree-baremetal.txt"
    fi

    log "Nettoyage du cache xbps (disque réduit)"
    $SUDO xbps-remove -yO >/dev/null || true

    log "Services runit"
    local svc list
    for list in "$ROOT/services/common.txt" "$ROOT/services/$PROFILE.txt"; do
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
    # et handler.sh mettait en veille capot fermé même avec des écrans externes)
    for svc in acpid; do
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

    log "Réglages noyau (sysctl) et earlyoom"
    $SUDO install -d /etc/sysctl.d
    $SUDO install -m 644 "$ROOT/system/sysctl/90-hardening.conf" /etc/sysctl.d/
    $SUDO sysctl -q --system || warn "sysctl --system a échoué"
    [ -d /etc/sv/earlyoom ] && $SUDO install -m 644 "$ROOT/system/earlyoom.conf" /etc/sv/earlyoom/conf

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

    # Double démarrage LUKS + btrfs + Limine (fichier créé par hardware/mac-t2/dualboot.sh)
    if [ -f /etc/kernel/cmdline ]; then
        log "Double démarrage (dualboot.sh)"
        $SUDO "$ROOT/hardware/mac-t2/dualboot.sh"
    fi

    if [ "$PROFILE" = baremetal ] || [ -n "${T2_FORCE:-}" ]; then
        if "$ROOT/hardware/mac-t2/setup.sh" --check >/dev/null 2>&1 || [ -n "${T2_FORCE:-}" ]; then
            log "Mac à puce T2 détecté"
            $SUDO env T2_FORCE="${T2_FORCE:-}" "$ROOT/hardware/mac-t2/setup.sh"
        fi
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

setup_dotfiles() {
    log "Dotfiles (liens symboliques vers $ROOT/dotfiles)"
    local f rel
    while IFS= read -r -d '' f; do
        rel="${f#"$ROOT/dotfiles/home/"}"
        link_one "$f" "$TARGET_HOME/$rel"
    done < <(find "$ROOT/dotfiles/home" -type f -print0)
    while IFS= read -r -d '' f; do
        rel="${f#"$ROOT/dotfiles/config/"}"
        link_one "$f" "$TARGET_HOME/.config/$rel"
    done < <(find "$ROOT/dotfiles/config" -type f -print0)
    # .desktop des applications web (liste ~/.config/webapps/list)
    HOME="$TARGET_HOME" sh "$ROOT/dotfiles/home/.local/bin/webapp-sync"
    # Thème sombre par défaut (portail xdg: Chromium, GTK4, libadwaita); sans effet hors session D-Bus
    gsettings set org.gnome.desktop.interface color-scheme prefer-dark 2>/dev/null || warn "gsettings: color-scheme non appliqué (pas de session D-Bus)"
}

[ "$DO_SYSTEM" -eq 1 ] && setup_system
[ "$DO_DOTFILES" -eq 1 ] && setup_dotfiles
[ "$DO_SYSTEM" -eq 1 ] && setup_claude
[ "$DO_SYSTEM" -eq 1 ] && setup_proton_drive
log "Terminé"
