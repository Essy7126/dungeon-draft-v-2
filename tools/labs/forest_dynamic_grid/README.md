# Forest Dynamic Test

Prototype isole de la premiere salle peinte. Il charge directement son
`RoomData`, remplit une seule instance de `GridData`, reutilise le
`Pathfinder` commun et place toutes les vues avec `PaintedMapVisualData`.

La peinture forestiere reste la matiere principale. Chaque dalle neutre est un
polygone opaque qui reprend exactement les pixels de sa cellule dans la
peinture validee : pierre, mousse, ombres et lumiere restent donc continus avec
le decor. Les surfaces FEU, EAU et GLACE remplacent temporairement ce polygone
par une dalle elle aussi opaque, sans modifier le terrain de base. Aucun faux
asset `forest_neutral_tile.png` n'est cree.

Commandes : `F/W/I` ou `1/2/3` choisit une surface, clic gauche l'applique,
`C` efface, `T` avance un tour, `G` affiche la grille et `R` reinitialise le
laboratoire.

Les onze captures contractuelles sont generees par `ForestCaptureRunner.tscn`
dans `artifacts/labs/forest_dynamic_grid/`.
