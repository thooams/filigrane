# Dell 1350cnw (imprimante laser couleur réseau)

Reprise de la configuration qui fonctionnait sous Omarchy (28/08/2026, impression vérifiée).

## Particularités

- L'imprimante n'expose que le socket brut JetDirect (port 9100): pas d'IPP, pas d'impression sans pilote.
- Elle parle **HBPL version 1**, pas la v2. Le pilote évident (`foo2hbpl2`, PPD `Dell-1355`) fait rejeter chaque
  travail avec `PDL Error ... 016-720`. Il faut `foo2hbpl1` (comme les Dell 1250c / C1660w).
- Le wrapper amont (fork mikerr/foo2zjs) utilisait `$SCREEN` sans l'affecter, ce qui casse toute impression
  couleur: le correctif (le bloc `case "$RES"`) est déjà dans `foo2hbpl1-wrapper`.
- Correctif local dans `foo2hbpl1.c`: la boucle sur `papers[]` avançait de 1 au lieu de 3 et lisait au-delà du tableau
  (avertissement `-Waggressive-loop-optimizations`, comportement indéfini). Le résultat est inchangé pour les formats listés (A4...).
- `foo2zjs-pstops` vient de foo2zjs (paquet Arch `foo2zjs-nightly` 20201127); il n'est pas packagé sous Void.
- Le PPD est `Dell-1250c.ppd` de foo2zjs, dont les noms de modèle sont réécrits en 1350cnw.

## Installation

```
./drivers/dell-1350cnw/install.sh        # compile dans /usr/local, installe le PPD (bootstrap.sh le fait aussi)
sudo sv up cupsd                         # le service est activé par bootstrap.sh
lpadmin -p Dell_1350cnw -E -v socket://IP_IMPRIMANTE:9100 -m Dell-1350cnw.ppd.gz -o PageSize=A4 -o printer-is-shared=false
lpoptions -d Dell_1350cnw
```

L'adresse IP de l'imprimante n'est volontairement pas dans le dépôt (public): voir l'interface web de l'imprimante
ou le routeur.

## Pièges

- Une taille de papier qui ne correspond pas bloque la file interne de l'imprimante, sans moyen de l'annuler: la
  couper puis la rallumer. Toujours imprimer en **A4**.
- Avertissements normaux et sans conséquence: `193-700` (toner non d'origine, niveaux `???`) et `colord`/DBus
  `CreateProfile failed`.
- Sans canal de retour, CUPS marque les travaux « terminés » même si l'imprimante les a rejetés. Pour diagnostiquer:
  envoyer un flux produit par le wrapper directement sur le port 9100, puis lire le journal des événements
  (`/status/events.htm`) et la file (`/job/queue.htm`) dans l'interface web de l'imprimante.
