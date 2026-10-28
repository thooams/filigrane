# shellcheck shell=bash
# Couche personnelle de thomas, lue par bootstrap.sh (source): ce qui n'a pas sa place dans la distribution.
# bootstrap.sh appelle layer_system (étape système, droits root) et layer_dotfiles (après les liens).
# Variables et fonctions disponibles: ROOT, LAYER_DIR, TARGET_USER, TARGET_HOME, TARGET_ARCH, PROFILE, MACHINE,
# SUDO, log, warn, read_list, install_list, run_as_user.

layer_system() {
    if [ "$PROFILE" = baremetal ]; then
        log "Pilote de l'imprimante Dell 1350cnw (HBPL v1, compilé dans /usr/local)"
        [ -x /usr/local/bin/foo2hbpl1 ] || "$LAYER_DIR/drivers/dell-1350cnw/install.sh" || warn "pilote Dell non installé"
    fi
    setup_proton_drive
    setup_whatsapp_unreadd
}

layer_dotfiles() {
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
        command -v go >/dev/null || { warn "go absent (users/thomas/packages/personal.txt): whatsapp-unreadd non compilé"; return 0; }
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
