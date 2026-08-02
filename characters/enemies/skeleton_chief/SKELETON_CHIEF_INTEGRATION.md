# Intégration Godot — Chef squelette

## Résultat

Le Chef squelette est un ennemi élite exclusivement présent dans la salle 2 de la Run V1. Il possède son propre GLB, ses propres contrôleurs visuels et une frappe lourde data-driven. Aucun changement n’a été apporté à `battle.gd`, au calcul de dégâts, à la grille ou au moteur d’IA générique.

## Architecture

- GLB : `res://assets/enemies/skeleton_chief/skeleton_chief_character_v01.glb`
- `SkeletonChiefVisual3D.tscn` / `skeleton_chief_visual_3d.gd` étendent `CharacterVisual3D`;
- `SkeletonChiefIsoUnitView.tscn` / `skeleton_chief_iso_unit_view.gd` étendent `CharacterIsoUnitView`;
- les sockets mains sont uniquement des origines d’effet, sans équipement créé;
- priorité partagée conservée : Death > Hit > Attack > Movement > Idle;
- signaux hérités : `animation_started`, `animation_finished`, `cast_release_reached`, `hit_reaction_finished`, `death_animation_finished`;
- aucun NLA, root motion logique, autorité gameplay visuelle ou branche par `unit_id`.

Le SubViewport est 768 × 512, transparent, `own_world_3d`, Linear, MSAA 4X, sans TAA ni FXAA. L’échelle interne finale est 1,16 avec caméra orthographique 2,55. Mesure réelle : 388 px, soit 75,78 % de la hauteur utile et 16,17 % de plus que le Squelette standard. Death occupe 361 × 175 px et ne touche aucun bord. Le léger dépassement de la cible indicative « 8–15 % » est documenté : descendre à 15 % ferait passer la hauteur utile sous 76 % avec les proportions actuelles des deux modèles.

## Animations et rythme

| Action Godot | Source | Durée importée | Vitesse | Durée finale | Impact |
|---|---|---:|---:|---:|---:|
| `DD_SkeletonChief_Idle` | Idle production | 2,300 s | 1,0 | 2,300 s | boucle |
| `DD_SkeletonChief_Walk` | Walk production | 1,000 s | 1,190476 dynamique | 0,840 s | boucle |
| `DD_SkeletonChief_Run` | Run production | 0,600 s | partagé | 0,600 s nominal | boucle |
| `DD_SkeletonChief_Attack` | Slash | 1,500 s | 1,0 | 1,500 s | frame source 24, normalisé 0,511111 |
| `DD_SkeletonChief_HeavyAttack` | Ground Slam | 3,000 s | 1,7 | 1,765 s | frame source 61, normalisé 0,666667 |
| `DD_SkeletonChief_Hit` | Hit | 1,233 s | 1,5 | 0,822 s | — |
| `DD_SkeletonChief_Death` | Dead | 2,967 s | 1,3 | 2,282 s | — |

## UnitData et combat

Ressource : `res://data/units/ennemie/skeleton_chief.tres`.

- ID : `skeleton_chief`;
- nom : `Chef squelette`;
- ennemi, 130 PV, 6 PA, 2 PM, 21 attaque, 12 armure, initiative 6;
- 1,733× les PV et 1,3125× l’attaque du Squelette mêlée;
- IA mêlée générique, portée/préférence 1, `keep_distance = false`;
- aucune énergie, Ferveur, phase, invocation, résurrection ou barre de boss.

Sort optionnel unique : `res://data/spells/enemies/skeleton_chief_heavy_strike.tres`. Il coûte 3 PA, porte à 1, inflige exactement 24 dégâts physiques, n’a ni élément magique, ni VFX inventé, ni cooldown spécial. L’IA générique choisit le déplacement vers l’adjacence puis cette ressource lorsque la cible est valide.

## Salle 2

La vraie deuxième RoomData de la Run V1 est `res://data/rooms/terrain_2.tres`, référencée en deuxième position par `run_default.tres` et `fixed_trio_prototype_run.tres`.

Composition finale :

1. `skeleton_chief` à la première cellule ennemie `(10, 3)`;
2. `skeleton_melee` à `(11, 2)`;
3. `skeleton_ranged` à `(12, 0)`.

La salle 1, les salles 3/4 et leur équilibrage restent inchangés : 2 mêlées + 1 distance. Le Chef apparaît une seule fois dans la Run V1 et le total de la salle 2 reste trois ennemis.

## Validation

- Import isolé : 24 os, racine Hips, 1 mesh skinné, 3 354 triangles, 7 animations non vides, boucles correctes;
- test Chef GUT : 13/13;
- test Squelette standard : 13/13 dans la suite complète;
- suite complète finale : 410/415; les seuls échecs restent les cinq échecs Elfe historiques;
- parcours réel des quatre salles : PASS en 8,080 s;
- salle 1 : `skeleton_melee`, `skeleton_melee`, `skeleton_ranged`;
- salle 2 : `skeleton_chief`, `skeleton_melee`, `skeleton_ranged`;
- salle 3 et salle 4 inchangées;
- chaque transition libère Battle, EnemyTurnRunner et UnitViews; 0 projectile résiduel, VFXManager délié;
- suppression du Chef pendant Attack et Death/Hit : aucun visuel ni SubViewport résiduel;
- aucun `await get_tree().process_frame` ou timer non protégé ajouté au gameplay.

Performance réelle à 1920 × 1080 : Forward+, RTX 4070 Laptop, V-Sync actif, 6 SubViewports 768 × 512, 1 362 échantillons sur 9,252 s, 165 FPS moyens et minimum. Les phases couvrent Idle, mouvements, attaque Chef, tir distance, frappe lourde, plusieurs Hit et trois Death.

## Captures

Les captures Blender, Iso, Y-sort et salle 2 sont dans `res://artifacts/skeleton_chief/`. La vidéo réelle `skeleton_chief_room_flow.mp4` montre la fin de salle 1, la transition, l’apparition du Chef, son déplacement, Attack, Hit, Death et l’arrivée en salle 3. Elle dure 12,23 s, contient 367 frames à 30 FPS, vidéo H.264 sans piste audio; SHA-256 : `238E3B9FB7FA66F313E3708E9F087C6E2671C453079A94F777ECCA88518DE95D`.

## Avertissements conservés

- Le compromis de cadrage place le Chef 16,17 % au-dessus du Squelette standard, très légèrement au-delà de la cible indicative de 15 %, afin de conserver environ 76 % de hauteur utile.
- Death conserve volontairement jusqu’à 0,45 m de déplacement horizontal artistique; la racine logique 2D ne bouge pas.
- Les cinq échecs Elfe historiques de la suite complète ne sont pas liés à cette intégration.
