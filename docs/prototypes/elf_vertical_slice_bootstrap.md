# Bootstrap du vertical slice Elfe

## Point d'entrée

L'écran titre expose deux chemins explicites :

- **Prototype Elfe** lance directement `elf_prototype_run.tres` avec le seul `UnitData` de l'Elfe ;
- **Ancien prototype / Draft historique** conserve le trajet `start_run` → écran de draft → `confirm_run_draft`.

Le chemin Elfe ne choisit aucune école d'énergie et n'injecte aucun trait de draft. Il construit l'unité avec `Unit.from_data`, afin que toute énergie ou tout trait éventuellement porté plus tard par son `UnitData` reste néanmoins respecté.

## Contenu activé

Le prototype parcourt, dans cet ordre, les trois premières salles valides du run principal :

1. `le_gue.tres`
2. `la_forge.tres`
3. `elite_brute.tres`

Son pool de récompenses et tous les pools étendus sont vides. Une victoire de salle enchaîne donc directement sur la suivante. La victoire de la troisième salle et toute défaite ouvrent l'écran terminal commun, qui affiche le résultat, le nom du run et un retour à l'écran titre.

## Neutralisation d'interface

Une unité sans `energy_type` garde les PA, PM, déplacement, attaque, sorts et fin de tour. Le libellé et la barre de Ferveur, l'Éveil, la Garde, leurs séparateurs et les variantes Empreinte des sorts sont masqués. Ces contrôles réapparaissent automatiquement pour le trajet historique et ses unités avec énergie.

## Limites volontaires

- Le lot suivant définit désormais quatre sorts actifs data-driven ; voir `character_progression_foundation.md`.
- Les cartes, ennemis et règles de combat restent ceux du prototype historique.
- Ce bootstrap historique n'introduisait aucune progression ; les lots suivants ajoutent le loadout puis le rang 2 Mage, documenté dans `elf_mage_progression_slice.md`.
- La première salle conserve son rendu isométrique existant ; les salles suivantes gardent leur présentation actuelle.
