# Validation du spectre en combat

`SpectreCourtyardValidation.tscn` ouvre la vraie Cour des Sources, déploie Achille dans une case autorisée, le fait approcher légalement avec ses PM via GridView si nécessaire, puis utilise le bouton Fin de tour ainsi que sa confirmation habituelle. L’IA de la rencontre décide tous les déplacements et lance `spectre_heavy_cleave`. Achille conserve au moins deux cases de distance pour laisser au spectre une approche réelle. Le probe ne téléporte aucune unité, ne modifie pas les PV/PA/PM et ne remplace jamais le personnage par une démonstration.

Il passe au maximum quatre tours joueur pour laisser l’ennemi approcher. Les dégâts sont filtrés par l’identité réelle de l’attaquant spectre ; le squelette de la rencontre joue également normalement. La validation exige au moins une activation contenant déplacement puis sort, un seul impact et une seule fin par attaque, une consommation de 2 PA, les PV intacts jusqu’au marqueur de release, et le retour à une pose immobile.

## Lancer

Importer les ressources avec l’éditeur une fois avant le premier lancement. Ne pas exécuter import et jeu simultanément.

```powershell
$godotSpectre = 'C:/Godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe'
$projectSpectre = 'C:/Users/paolo/Documents/dungeon-draft-v-2'
& $godotSpectre --path $projectSpectre --resolution 1200x800 res://tools/spectre_sprite_validation/SpectreCourtyardValidation.tscn -- --artifact-dir=res://artifacts/spectre_sprite_validation_v1/gameplay_clip --capture-clip
```

La capture contient les images du viewport réel, recadrées dans un rectangle fixe englobant les deux combattants et le chemin. Le buffer est compressé après les actions. Les lectures GPU peuvent ralentir la passe visuelle ; pour mesurer le temps, lancer une seconde passe graphique sans aucune capture :

```powershell
& $godotSpectre --path $projectSpectre --resolution 1200x800 res://tools/spectre_sprite_validation/SpectreCourtyardValidation.tscn -- --artifact-dir=res://artifacts/spectre_sprite_validation_v1/timing --no-screenshots
```

`runtime_validation.json` fournit le résultat, les erreurs, les poses observées, les déplacements réellement payés en PM, les horodatages de début/release/dégâts/fin, les PV/PA, les ancres et les chemins des captures. Les durées sans capture sont comparées à l’attaque de 0,8 s et au release de 0,3 s, avec une tolérance de rendu explicitement bornée. Une passe visuelle ne sert pas à conclure sur ces durées.

Pour encoder le GIF à partir des PNG et de leurs véritables horodatages :

```powershell
node tools/spectre_sprite_validation/assemble_clip.cjs artifacts/spectre_sprite_validation_v1/gameplay_clip/clip/clip_manifest.json
```

Le résultat `spectre_gameplay.gif` est un agrandissement 2× du recadrage du jeu. Aucun dessin supplémentaire ni image intermédiaire n’est reconstruit. `encode_report.json` compare la durée source et celle du GIF, arrondie aux centisecondes.

## Catabase II : rencontre de production

L'option `--room-path` charge la salle demandée par le pont public `GameManager.start_direct_encounter_test`, après projection `ArenaRuntimeBridge` d'une copie en mémoire et résolution du héros canonique `RunHeroResolver`. La scène de combat, le terrain, le roster et les sorts restent ceux de cette salle. Aucun fichier de production n'est réécrit. Sans option, la Cour des Sources utilise son lancement habituel.

```powershell
& $godotSpectre --path $projectSpectre --resolution 1200x800 res://tools/spectre_sprite_validation/SpectreCourtyardValidation.tscn -- --room-path=res://data/rooms/odyssey/room_02.tres --artifact-dir=res://artifacts/spectre_sprite_validation_v1/catabase_ii_timing --no-screenshots
```

Pour une capture de la même rencontre, remplacer `--no-screenshots` par `--capture-clip` et choisir un autre `--artifact-dir`, par exemple `res://artifacts/spectre_sprite_validation_v1/catabase_ii_clip`. C'est un test direct de la rencontre Catabase II, pas une traversée de la campagne depuis sa première salle. Le rapport ajoute `requested_room_path`, `actual_room_name`, `actual_encounter_id` et `actual_terrain_plan` pour vérifier la scène réellement jouée. Il applique les mêmes exigences au tour IA et aux dégâts.
## Tests GUT

- `test/unit/test_spectre_sprite_assets.gd` : liaison canonique et portrait, quatre directions, tailles, transparence, marges, poses utiles distinctes. La même pose de garde aux deux extrémités de l’attaque est volontaire.
- `test/unit/test_spectre_sprite_runtime.gd` : un seul sprite sans nœud 3D, ancre commune, repos stable, phase de lévitation continue entre cases et changements de direction, release/fin uniques, gros delta, annulation, mort, pause sans rattrapage brutal.
- `test/unit/test_spectre_gameplay.gd` : données, IA, coûts et sort. Ce fichier est maintenu avec l’intégration gameplay.

L’horloge déterministe des tests runtime ne remplace pas la passe graphique de timing : elle vérifie les frontières et les annulations, tandis que le harness vérifie les vrais acteurs et contrôleurs dans la carte.
