# Arena Visual Pipeline Repair — baseline 1.3.0

Baseline relevée avant écriture le 6 août 2026 dans `C:\Users\paolo\Documents\dungeon-draft-v-2`.

## Sécurité du dépôt

- Branche : `main`.
- HEAD local et `origin/main` : `94fcdc700cf576a15ee4134d9f3dee680626827a` ; divergence `0/0`.
- Godot : `4.7.1.stable.official.a13da4feb`.
- GUT : `9.7.1`.
- Modifications concurrentes préexistantes, laissées intactes : `data/characters/elf/upgrades/eagle_eye.tres` et le fichier non suivi `data/characters/elf/modifiers/elf_archer_eagle_eye.tres`.
- Aucun fichier staged, aucun conflit, aucun diff Arena ou Skill Tree au départ.
- Skill Tree gelé : 52 fichiers, manifeste SHA-256 agrégé `a41e7a75d95882486c31e80a7061fc92e34e5f54410f12a55f6a16b258d0089b` ; le checkout Git constitue la référence avant.

## Reproduction

### Canvas dynamique

`ArenaDynamicEditingService.paint_terrain()` modifiait correctement `terrain_id` et synchronisait `cell_type`. En revanche, `ArenaStudioCanvas._draw_cells()` ne chargeait aucune texture de terrain : il dessinait seulement un polygone coloré selon `playable`, `border`, obstacle et `cell_type`. La grille colorée pouvait donc donner l'impression d'un changement sans montrer pierre, eau, glace ou lave.

### Rendu « murs uniquement »

`ArenaVisualAssembler` transmettait un dictionnaire `cell -> cell_type` à `ArenaFeatureRenderer`. Le sol hybride omettait les cellules normales et les bordures, tandis que les murs étaient instanciés par une boucle indépendante. Une scène pouvait donc créer les murs sans aucun sprite de sol. Le résultat `ok` ne prouvait pas la présence de dalles.

### Perte d'identité

Le choix visuel par `cell_type` fusionnait `stone` et `water` (`NORMAL`) ainsi que `lava` et un mur logique (`WALL`). Les données Arena restaient distinctes ; la perte avait lieu entre le document et le renderer.

### PAINTED

Le bouton Construction dynamique entrait silencieusement dans le mode sur la forêt PAINTED. Les modifications restaient logiques, sans contrat visible indiquant si la map était PAINTED, HYBRID ou convertie.

### Lab → Studio

Le round-trip `arena.tres` conservait déjà son snapshot, mais le manifeste ne prouvait ni les comptes par terrain, ni le profil modulaire, ni les spawns/objectifs. Le premier défaut utilisateur était l'import direct sans miniature, résumé, choix de working copy ou comparaison après import.

### Validation et cache

- La parité appelait deux signatures théoriques ; supprimer les nœuds de sol n'était pas détecté.
- La production validait la structure logique, pas les sprites réels.
- Le cache global de classes Godot a dû être rescanné après l'ajout des nouveaux `class_name`; ce point n'était pas la cause des dalles invisibles 1.3.0.

## Captures avant

La matrice 1.2.1 a produit 66 PNG (22 cas × 3 résolutions) sous `res://artifacts/studio_1_2_1/screenshots/after/` avant la réparation. Les fichiers les plus probants sont :

- `studio_v121_01_dynamic_integrated_1280x720.png` : background et grille logique, pas de vraie texture de dalle ;
- `studio_v121_19_gameplay_separate_1280x720.png` : preview PAINTED et marqueurs, sans preuve de sol modulaire ;
- les mêmes cas en 1920×1080 et 2560×1440.

## Tests baseline

- Arena Studio 1.2.1 : 10/10, 871 assertions ; 26 ObjectDB leaks et 1 ressource encore utilisée.
- Arena Studio 1.2 : 7/8 ; unique échec dû à l'UID invalide déjà présent dans `Guerrier.tres`, avec fallback vers `frappe_lourde.tres`.
- Dynamic Arena : les contrats fonctionnels passent ; la capture historique absente `wall_assets_normalized.png` fait échouer un test de présence d'artefact.
- Skill Tree Studio : la suite est inexécutable dès le baseline à cause de l'erreur de parsing préexistante ligne 45 de `test_skill_tree_studio.gd`, fichier gelé et identique à HEAD.

Conclusion baseline : données terrain correctes, rendu éditeur absent, rendu preview non prouvé, identité terrain perdue dans le renderer, transfert insuffisamment décrit, ergonomie ambiguë.
