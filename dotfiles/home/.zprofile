# Démarre niri automatiquement sur tty1 (pas de gestionnaire de connexion, 0 Mo en plus).
# Pas de `exec`: si niri se ferme ou plante, on retombe sur un shell au lieu de boucler.
# Désactiver: touch ~/.no-niri (ou se connecter sur tty2 à tty6 pour dépanner).
if [[ -z "$WAYLAND_DISPLAY" && -z "$SSH_CONNECTION" && "$(tty)" == /dev/tty1 && ! -e ~/.no-niri ]]; then
    mkdir -p ~/.local/state
    dbus-run-session niri >~/.local/state/niri.log 2>&1
    # Ce que niri a lancé (pipewire, wa-daemon...) lui survit sans systemd: on l'arrête ici, avant toute nouvelle session
    # (à l'ouverture, l'arrêt d'un ancien pipewire effacerait la socket du nouveau)
    ~/.local/bin/session-reap
fi
