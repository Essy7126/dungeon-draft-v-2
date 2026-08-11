# Arena Extended Tile Catalog — rapport de vérité

Mission exécutée localement le 11 août 2026 sur `main`, au HEAD
`29bf19719be6988898bdbef4c16f5d5b44d7b2d6`, identique à `origin/main`
(avance/retard `0/0`). Aucun fichier n'a été stage, commit ou poussé.

## Résultat

| Rôle | Classification | Source canonique observée | Studio | Runtime | Production |
| --- | --- | --- | --- | --- | --- |
| `neutral` | sol permanent | `ArenaTerrainDefinition` + `neutre.png` | base et peinture | oui, `CellType.NORMAL` | oui |
| `steam` | surface temporaire | `data/terrain/vapeur.tres` | catalogue visuel seulement | oui, durée 2, dégâts 0, vision bloquée | non plaçable |
| `poison` | surface temporaire non certifiée | aucune `TerrainEffectData` poison | non plaçable | non | non |
| `electrified_water` | réaction visuelle instantanée | réaction `shock` du service runtime | non plaçable | renderer câblé, producteur lightning absent | non |
| `vortex` | interactif spatial | contrat d'authoring Arena | paire A/B en deux clics | non certifié | bloquée |

L'inventaire exhaustif, les SHA-256, dimensions, bounds alpha, imports, UID et
usages sont dans `res://artifacts/extended_terrain_catalog/asset_inventory.json`.
Le mapping des cinq rôles annoncés est non ambigu et aucun asset utilisateur n'a
été renommé. `ombre.png`, également découvert, reste explicitement non affecté.

## OBSERVÉ

- Les dix images inventoriées font 1024 × 1024, ont un canal alpha, sont
  rechargeables comme `Texture2D` et possèdent un import Godot.
- La vapeur possède déjà une ressource gameplay canonique : durée 2, dégâts 0,
  déclenchement passif et blocage de vision. Son `visual_terrain_id` est désormais
  `steam`, sans modification de ses valeurs gameplay.
- La matrice runtime contient une réaction `lightning|water -> shock`. Elle
  inflige les 20 dégâts définis par `TerrainSurfaceRuntimeService.REACTION_DAMAGE`,
  affecte la croix orthogonale et retire l'eau de la cellule centrale.
- Le sort électrique inspecté ne porte toutefois aucune `TerrainEffectData`
  `lightning`. Le renderer de l'événement est vérifié, mais aucun chemin de
  production canonique n'atteint aujourd'hui cette réaction.
- Le seul poison de gameplay découvert est un groupe de statut de l'assassin
  elfe. Ce n'est pas une surface de grille et aucune `TerrainEffectData` poison
  n'existe.
- Aucun consommateur de portail/vortex n'existe dans `GridData`, `Pathfinder` ou
  l'IA.
- Eau, glace et lave conservent leurs valeurs existantes. Une divergence
  historique reste visible pour la lave : le terrain permanent est un mur non
  praticable (`CellType.WALL`), alors que la surface temporaire emploie
  `CellType.LAVA`. Elle est rapportée, pas normalisée.

## DÉCISION VALIDÉE

- `neutral` est une dalle permanente sélectionnable comme sol de base modulaire
  ou hybride et comme dalle peinte.
- Vapeur, poison et eau électrifiée restent hors `ArenaDefinition` : elles
  appartiennent au runtime de combat ou à son rendu événementiel.
- L'eau électrifiée s'affiche pendant une frame rendue complète, puis le rendu
  revient à l'état canonique. Aucune durée gameplay n'a été inventée.
- Le vortex possède une Resource dédiée, un `pair_id` déterministe, deux cellules,
  un contrat de traversée et un rendu A/B relié. La création, le snapshot, la
  restauration, la suppression et le redimensionnement sont couverts.
- Toute Arena contenant une paire de vortex reçoit l'erreur bloquante
  `vortex_runtime_uncertified`. Le test direct et la production ne peuvent donc
  pas prétendre à une parité inexistante.

## DIVERGENCES ET INCONNUS

- `electrified_water` : logique de réaction et événement visuel présents, mais
  producteur canonique `lightning` absent. `runtime_supported=false` pour le
  chemin complet.
- `poison` : asset présent, gameplay de surface absent. Aucun dégât, statut ou
  durée n'a été inféré.
- `vortex` : authoring et validation présents, téléportation/pathfinding/IA
  absents. `production_placeable=false`.
- Le prompt source reçu s'arrête après le champ `production_placeable` de la
  matrice. Toute exigence située après cette coupure est donc INCONNUE ; les
  objectifs et contraintes disponibles ont été traités sans extrapolation.

## Parité vérifiée

- Studio : catalogue, sélection de la dalle neutre, peinture et authoring A/B.
- Preview/rendu : résolution unifiée des terrains permanents et surfaces ; vapeur
  et réaction électrique testées sans dalle dupliquée ni résidu.
- Test direct : la copie `user://` et les empreintes existantes restent l'autorité
  pour les Arenas certifiées ; une Arena avec vortex est refusée avant lancement.
- Run/GridData/Pathfinder/IA : valeurs eau/glace/lave/neutre conservées ; aucune
  téléportation vortex activée tant que ces trois consommateurs ne sont pas
  certifiés.

## Validation

- GUT ciblé et régressions pertinentes : **45/45 tests**, **840 assertions**
  (dont 10/10 et 168 assertions pour le catalogue étendu).
- Compatibilité de la façade visuelle Studio : **1/1 test**, **7 assertions**.
- Génération d'artefacts : **5/5 previews**, aucun échec.
- Scan/import Godot 4.7.1 : code 0, aucun parse error dans les fichiers de cette
  mission.
- Le scan signale deux éléments préexistants hors périmètre : l'UID invalide du
  bundle gelé `room_01_forest/arena_principal.tres`, et un doublon de classe dans
  `res://output/validation-feedback-candidate/`. Ils n'ont pas été modifiés.
- `git diff --check` : propre ; staging et conflits : aucun.

Les preuves machine sont dans
`res://artifacts/extended_terrain_catalog/gameplay_coverage.json`,
`preview_manifest.json` et `validation_report.json`.

## Bundle produit gelé

Le dossier `res://data/arenas/produced/room_01_forest/` n'a pas été utilisé pour
les tests ni modifié par la mission. Les quatre SHA-256 finaux sont strictement
identiques au prévol :

- `arena.tres`: `34af275b7ea8a4a5f2ca87cf807a188bb6f6c0570e977fab018bdf896f58607f`
- `arena_principal.tres`: `3d336937938d6d506c85b15ca20bacbf9c4daf07144dc7706e92c6f169d1b520`
- `modular_visual_profile.tres`: `18e27b8b0527ec0b1de489cf7eab4d2d4b986fc99f2d2c62bc0b0a647a7c60a9`
- `production_manifest.json`: `0bb0c700412a2136cfe08b8bfa32567ea65373ee31600a1e09b435981899409b`
