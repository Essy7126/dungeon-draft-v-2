# Contrat runtime du pipeline Arena 1.3.1

## Autorités

`ArenaDefinition` demeure le document canonique. `ArenaCellDefinition.terrain_id` est l'autorité de l'identité, de la texture, de la couleur d'édition et des effets propres au terrain. `cell_type` est l'autorité dérivée de GridData, praticabilité, pathfinding et comportement spatial. Un renderer modulaire ne choisit jamais sa texture principale depuis `cell_type`.

Exemples : stone et water sont tous deux `GridData.NORMAL` mais ont deux textures ; lava reste `terrain_id=lava` avec le contrat spatial historique `GridData.WALL` et utilise `lava.png`, jamais un visuel de mur.

## Chaîne unique

`ArenaDefinition → ArenaTerrainRenderPlanService → ArenaTerrainVisualRenderer → ArenaVisualAssemblyReport` est utilisée par le canvas, les previews Art/Jeu, le Lab, l'assemblage runtime, la validation et la production. `ArenaTileProjectionService` porte les mathématiques affines communes.

## Réponses à l'audit

1. Oui. `paint_terrain` appelle `ArenaTerrainRegistry.configure_cell`, écrit réellement `terrain_id`, puis dérive `cell_type` et synchronise les ressources runtime.
2. Avant 1.3.1, le canvas lisait surtout `playable`, `border` et `cell_type`. Il lit maintenant les entrées du render plan indexées par cellule et dessine la texture issue de `terrain_id`.
3. `ArenaTerrainVisualRenderer` crée les racines `ArenaTerrain_x_y` et leur `Sprite2D/Visual` dans les previews.
4. Water et stone sont distincts parce que leurs entrées du registry pointent respectivement vers `water.png` et `stone.png`, indépendamment de leur `CellType.NORMAL` commun.
5. Lava conserve `CellType.WALL` pour le déplacement mais le plan choisit `lava.png` via `terrain_id=lava`; elle n'emprunte pas `WallConfig`.
6. Les murs apparaissaient parce qu'ils étaient instanciés dans une boucle séparée, même lorsque l'ancienne liste de sol était vide. Le nouveau rapport compare désormais les deux couches.
7. Sur PAINTED, Construction dynamique ouvre obligatoirement un dialogue : working copy HYBRID, copie MODULAR, logique seule avec avertissement permanent, ou annulation.
8. HYBRID suit le champ explicite `hybrid_floor_policy`: NONE, NON_BASE_TERRAINS ou ALL_DEFINED, avec `base_terrain_id`.
9. La parité compare l'expected plan aux métadonnées, textures, transformations, visibilité, murs et décorations des vrais nœuds. Supprimer une dalle rend la parité fausse.
10. Oui. `ArenaProductionService.plan` et `produce` utilisent `ArenaVisualAssembler.inspect`; un compte réel incomplet bloque la production.
11. Oui. Le transfert sauvegarde la ressource du profil et son fingerprint dans le manifeste, puis le vérifie au chargement.
12. Oui. Production et transfert rechargent avec `CACHE_MODE_IGNORE`; les tests comparent fingerprints, chemins de textures et nouveau render plan.

## Compatibilité

`ArenaModularVisualProfile` ajoute deux champs optionnels : `hybrid_floor_policy` (défaut NON_BASE_TERRAINS) et `base_terrain_id` (défaut stone). Ils sont inclus dans `to_dict/from_dict`; les anciennes ressources restent chargeables. La production reconnaît les manifestes Studio 1.2, 1.2.1 et 1.3.0 comme productions antérieures, sans assimiler un fichier manuel à un fichier possédé.
