#!/bin/sh
# Fait attendre le getty de tty1 que le service runit elogind soit prêt (nécessaire avec l'autologin).
#
#   sudo ./tty1-wait-elogind.sh [on|off]      (défaut: on)
#
# Sans cela, la connexion automatique est le premier client D-Bus au démarrage: D-Bus active elogind
# lui-même (login1), puis le wrapper du service runit monte un tmpfs sur /run/user et masque
# /run/user/<uid>. Résultat: pas de XDG_RUNTIME_DIR, niri échoue ("Failed to open session").
# L'attente est bornée à 20 s: si elogind est cassé, tty1 démarre quand même (tty2 à tty6 restent libres).
set -eu
conf=/etc/sv/agetty-tty1/conf
begin='# >>> void-setup: attendre elogind'
end='# <<< void-setup'
[ "$(id -u)" -eq 0 ] || exec sudo "$0" "$@"
[ -f "$conf" ] || { echo "Introuvable: $conf" >&2; exit 1; }

# retire un éventuel bloc existant (idempotent)
sed -i "\|^$begin|,\|^$end|d" "$conf"

if [ "${1:-on}" = on ]; then
    {
        printf '%s\n' "$begin"
        printf '%s\n' 'n=0; until sv check /var/service/elogind >/dev/null 2>&1 || [ "$n" -ge 20 ]; do sleep 1; n=$((n+1)); done'
        printf '%s\n' "$end"
    } >> "$conf"
fi
tail -4 "$conf"
