#!/bin/bash
# Pilote CUPS de la Dell 1350cnw (HBPL v1, imprimante réseau en socket 9100, sans IPP): foo2hbpl1 + PPD.
# Compilé et installé dans /usr/local (non géré par xbps). Voir README.md. Idempotent; nécessite sudo.
# Prérequis (packages/baremetal.txt): cups, cups-filters (foomatic-rip), gcc, ghostscript, psutils.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
[ -f foo2zjs-pstops ] || { echo "foo2zjs-pstops manquant (script du wrapper, voir README.md)" >&2; exit 1; }
P=/usr/local
S="sudo"; [ "$(id -u)" -eq 0 ] && S=""
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

gcc ${CFLAGS:--O2} -o "$tmp/foo2hbpl1" foo2hbpl1.c -lm
# Le wrapper tourne sous CUPS: PATH sans /usr/local, préfixe /usr par défaut
sed -e "s|^PREFIX=.*|PREFIX=\${FOO2PREFIX:-$P}|" -e "s|^PATH=\$PATH:|PATH=$P/bin:\$PATH:|" foo2hbpl1-wrapper >"$tmp/foo2hbpl1-wrapper"
gzip -9 -c Dell-1350cnw.ppd >"$tmp/Dell-1350cnw.ppd.gz"

$S install -Dm755 "$tmp/foo2hbpl1" "$tmp/foo2hbpl1-wrapper" foo2zjs-pstops -t $P/bin
$S install -d $P/share/foo2hbpl/crd
$S install -m644 crd/* $P/share/foo2hbpl/crd/
$S install -Dm644 "$tmp/Dell-1350cnw.ppd.gz" /usr/share/cups/model/Dell-1350cnw.ppd.gz
echo "Pilote installé. Ajouter la file: lpadmin -p Dell_1350cnw -E -v socket://IP:9100 -m Dell-1350cnw.ppd.gz -o PageSize=A4"
