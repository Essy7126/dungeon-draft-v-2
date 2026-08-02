# Validation finale — Centurion squelette des neiges

Date : 2026-08-02

Verdict : `SNOW_CENTURION_ROOM4_VALIDATION_COMPLETE_WITH_WARNINGS`

## Révision validée

- Dépôt : `C:\Users\paolo\Documents\dungeon-draft-v-2`
- Branche : `refactor/project-clean-slate`
- HEAD : `70afe82d575c64cd43170df18e99cf6afd775b21`
- Commit d'intégration : `70afe82`
- Aucun cherry-pick, commit ou push effectué pendant cette validation.
- `main` n'a reçu aucun fichier de l'intégration.

Les fichiers GLB, Visual3D, IsoUnitView, UnitData, tests et RoomData salle 4 sont présents. Le GLB intégré a le SHA-256 `3353E7EF8341E46B691BBB1DC315F519543D050AD8692E9E8C07A851D38E9761`.

## Validation runtime réelle

Le parcours réel de la Run V1 a été exécuté jusqu'au `RunResultScreen` avec les écrans après-combat. La transition salle 3 → salle 4 et la fin de la salle 4 passent sans crash.

Roster réel de la salle 4 :

- 3 `skeleton_chief` ;
- 2 `skeleton_snow_centurion` ;
- 1 `skeleton_ranged` ;
- total : 6 ennemis sur 6 cellules distinctes.

Contrôles exécutés dans la salle réelle : Walk, Attack, HeavyAttack, Hit natif, attaque distance et Death. Tous les démarrages ont été confirmés. Le signal `death_animation_finished` du Snow Centurion a été reçu avant le nettoyage du visuel.

Après la victoire de la salle 4 :

- ancienne Battle libérée ;
- ancien `EnemyTurnRunner` libéré ;
- 9 `UnitView` libérées ;
- 9 SubViewports libérés ;
- aucun projectile résiduel ;
- `VFXManager` délié de l'ancienne salle ;
- écran après-combat puis `RunResultScreen` atteints.

Le rapport machine complet est dans `C:\Blender_AI_Test\Output\snow_centurion_room4_cinematic_capture.json`.

## État final laissé ouvert

L'instance Godot finale reste ouverte en salle 4. Son rapport `C:\Blender_AI_Test\Output\snow_centurion_room4_open.json` confirme :

- Elfe, Mage et Guerrier vivants à 100 PV ;
- exactement 3 Centurions normaux, 2 Centurions des neiges et 1 Squelette distance ;
- six ennemis vivants et en Idle ;
- deux `SnowCenturionIsoUnitView` natifs ;
- 9 SubViewports de 768 × 512 ;
- zéro projectile ;
- zéro enfant VFX ;
- overlay debug masqué ;
- aucune erreur de validation.

Capture : `res://artifacts/skeleton_snow_centurion/room4_final_idle.png`.

## Performances 1920 × 1080

- GPU : NVIDIA GeForce RTX 4070 Laptop GPU
- Renderer : `gl_compatibility`
- V-Sync : désactivée (`0`)
- Durée : 9,5013265 s
- Échantillons : 5 867
- FPS moyen : 710,4319
- FPS minimum : 85,0774
- SubViewports : 9 × 768 × 512
- Triangles rendus approximatifs : 221 796
- Mémoire statique mesurée : 90 784 880 octets
- Cibles > 90 FPS moyen et > 60 FPS minimum : atteintes

Rapport : `C:\Blender_AI_Test\Output\snow_centurion_performance_report.json`.

## Captures et vidéo

Captures de la Run réelle sous `res://artifacts/skeleton_snow_centurion/` :

- `room3_before_room4_transition.png`
- `room4_final_idle.png`
- `snow_centurion_room4_walk.png`
- `snow_centurion_room4_attack.png`
- `snow_centurion_room4_heavy_attack.png`
- `snow_centurion_room4_hit.png`
- `snow_centurion_room4_death.png`
- `skeleton_ranged_room4_attack.png`

Planches de contrôle isolées sous le même dossier :

- `room4_six_enemies.png`
- `room4_three_normal_two_snow_one_ranged.png`
- `trio_vs_room4_roster.png`
- `snow_centurion_y_sort.png`
- `normal_vs_snow_centurion_scale.png`

Vidéo : `res://artifacts/skeleton_snow_centurion/snow_centurion_room3_to_room4_validation.mp4`.

- H.264 High, 1920 × 1080, 30 FPS ;
- 587 images, 19,57 s ;
- aucune piste audio ;
- taille : 4 414 077 octets ;
- SHA-256 : `6DC761A0FB69EB3F0E4E953E12C7615A49E83640F918101D27FE5949D0EBE42D`.

Godot MovieWriter ayant enregistré le viewport logique en 1200 × 896, le MP4 1920 × 1080 conserve ce ratio avec des bandes latérales neutres ; aucune déformation de l'image n'a été introduite.

## Tests

- Snow Centurion : 12/12, 118 assertions.
- Skeleton Chief : 13/13, 120 assertions.
- Squelettes et IA : 13/13, 96 assertions.
- Transitions asynchrones : 10/10, 28 assertions.
- Run (présentation, persistance, progression, après-combat) : 45/45, 477 assertions.
- Parcours runtime complet salles 1→4 : PASS, 4/4 nettoyages contrôlés.
- Suite complète : 442/443, 37 486/37 488 assertions.
- `git diff --check` : PASS.

L'unique échec de la suite complète est hors périmètre Snow et préexistant : `test_dark_pause_menu.gd::test_theme_uses_distinct_texture_states_and_focus_style`, où deux textures de thème restent `null` aux lignes 123–124. Aucun nouvel échec Snow Centurion, Skeleton Chief, Squelettes, IA, transition ou Run n'est présent.

## Avertissements

- Les exécutions GUT/headless et MovieWriter signalent à la fermeture des ressources Godot/RID encore référencées. Les contrôles runtime de transition confirment néanmoins la libération des Battle, `EnemyTurnRunner`, `UnitView`, neuf SubViewports, projectiles et VFX de la salle 4. L'instance finale, qui reste ouverte, ne présente aucune erreur rouge de gameplay.
- La vidéo est livrée en 1920 × 1080 avec bandes latérales, car le viewport logique du projet est 1200 × 896.
- Le working tree contient aussi des changements locaux « Mountain Pass » externes à cette validation. Ils ont été préservés sans modification intentionnelle.

## Conclusion

L'intégration Snow Centurion est validée en salle 4. Les avertissements restants sont hors du périmètre fonctionnel du personnage et n'empêchent ni la transition 3→4, ni les animations, ni la fin de la salle 4, ni le nettoyage runtime.
