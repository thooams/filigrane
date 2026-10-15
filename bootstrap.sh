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
    if [ "$(id -u)" -eq 0 ]; then chown -h "$TARGET_USER:" "$dst" "$(dirname "$dst")"; fi
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
}

[ "$DO_SYSTEM" -eq 1 ] && setup_system
[ "$DO_DOTFILES" -eq 1 ] && setup_dotfiles
[ "$DO_SYSTEM" -eq 1 ] && setup_claude
log "Terminé"
