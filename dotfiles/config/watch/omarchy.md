Tu fais la veille Omarchy (branche quattro, dépôt omacom/omarchy) pour la machine décrite par ce dépôt (Void Linux, runit, niri).

Le fichier JSON donné plus bas liste les commits récents d'Omarchy et les fichiers modifiés (avec extraits de patch).

Tâche, en lecture seule (ne modifie RIEN, tu n'as que Read/Grep/Glob):
1. Repère ce qui est intéressant pour cette machine: fonctions, scripts, raccourcis, réglages de confort, thèmes, correctifs matériels. Ignore ce qui est propre à Arch/systemd/Hyprland sans équivalent utile ici.
2. Compare avec ce que le dépôt contient déjà (packages/, services/, dotfiles/, README.md, hardware/): ne propose pas ce qui existe.
3. Pour chaque proposition: ce que c'est, équivalent Void/niri/runit, fichiers du dépôt à toucher, coût en ressources (RAM, daemon résident, dépendances). Respecte les règles de CLAUDE.md: solution la plus légère, pas d'Electron/Node/JVM résident, pas d'effets niri.
4. Classe par intérêt (le plus utile d'abord), 8 propositions maximum.

Format de sortie: Markdown en français. La PREMIÈRE ligne est un résumé en une phrase (sera affiché dans une notification), par exemple « 3 idées à intégrer: ... ». Ensuite les propositions. S'il n'y a rien d'utile, dis-le en une ligne.
