# Contrat de projection artistique affine

Statut : **WORKTREE_CANDIDATE**.

La géométrie artistique dérive exclusivement de `grid_origin`, `axis_x`, `axis_y`, `image_offset`, `image_scale` et du contrat de résolution natif. Centres, coins, murs, masques, coordonnées, profondeur et repères d’alignement utilisent la même projection affine que le runtime. Aucun fallback rectangulaire ne remplace silencieusement cette géométrie.

Les passes de référence sont propres et séparées : décor sans grille, grille, coordonnées, gameplay, murs, playable/void/wall masks, foreground, profondeur et marqueurs. La résolution exportée est exacte ; recadrage, changement de perspective et redimensionnement sont refusés au round-trip.

Le rapport de géométrie est mis en cache par fingerprint Arena et invalidé par toute modification sémantique. Les chemins d’assets restent visuels : la topologie, les spawns et les collisions demeurent sous l’autorité d’ArenaDefinition.
