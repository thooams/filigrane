#!/bin/bash
# Resynchronise les dotfiles du dépôt depuis la VM de référence (hôte ssh "void").
# La VM reste la source de vérité: on modifie là-bas, on rapatrie ici, on commit.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
HOST="${1:-void}"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

for f in .bashrc .bash_profile .inputrc; do
    scp -q "$HOST:$f" "dotfiles/home/$f"
done
for d in niri htop; do
    rm -rf "dotfiles/config/$d"
    scp -qr "$HOST:.config/$d" dotfiles/config/
done

echo "Paquets installés manuellement sur $HOST mais absents des listes:"
ssh "$HOST" 'xbps-query -m' | sed -E 's/-[^-]+$//' | sort > "$TMP/vm.txt"
cat packages/*.txt | sed -e 's/#.*//' | grep -v '^$' | sort -u > "$TMP/repo.txt"
comm -23 "$TMP/vm.txt" "$TMP/repo.txt" || true

git status --short
