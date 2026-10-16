#!/bin/sh
# Compile hors arbre les pilotes Touch Bar (désactivés dans la config du noyau Void) pour un noyau donné.
# Appelé par DKMS:  ./build.sh <kernelver> <kernel_source_dir>
# Sources prises au tag stable v<version> du noyau sur git.kernel.org, vérifiées contre SHA256SUMS.
set -eu
kver="$1" ksrc="$2"
base="${kver%%_*}"                       # 6.18.57_1 -> 6.18.57
case "$base" in *.*.0) tag="v${base%.0}" ;; *) tag="v$base" ;; esac
url=https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain
cache="/var/cache/appletb/$tag"

mkdir -p "$cache"
for p in drivers/hid/hid-appletb-kbd.c drivers/hid/hid-appletb-bl.c drivers/gpu/drm/tiny/appletbdrm.c drivers/hid/hid-ids.h; do
    f="${p##*/}"
    if [ ! -s "$cache/$f" ]; then
        curl -fsSL "$url/$p?h=$tag" -o "$cache/$f.tmp"
        mv "$cache/$f.tmp" "$cache/$f"
    fi
    cp "$cache/$f" "./$f"
done

if ! sha256sum -c --quiet SHA256SUMS; then
    echo "appletb: les sources $tag diffèrent des sommes épinglées (SHA256SUMS)." >&2
    echo "appletb: relire le diff ($cache), mettre à jour hardware/mac-t2/appletb/SHA256SUMS et PACKAGE_VERSION." >&2
    exit 1
fi

make -C "$ksrc" M="$PWD" modules
