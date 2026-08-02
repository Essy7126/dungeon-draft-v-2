# Intégration du premier ennemi Squelette

## État

L'implémentation a été appliquée au dépôt réel `C:\Users\paolo\Documents\dungeon-draft-v-2` sur la branche `main`, au HEAD `fdbccb290382265b4ab73991de08f53ac941168d`. Les 40 fichiers du paquet ont été superposés au dépôt propre, sans conflit, suppression, commit ni push.

## Architecture partagée

Un seul GLB alimente les deux profils : `res://assets/enemies/skeleton/skeleton_character_v01.glb`.

- `SkeletonVisual3D.tscn` / `skeleton_visual_3d.gd` étendent `CharacterVisual3D`
- `SkeletonIsoUnitView.tscn` / `skeleton_iso_unit_view.gd` étendent `CharacterIsoUnitView`
- `SkeletonMeleeIsoUnitView.tscn` sélectionne `CombatStyle.MELEE`
- `SkeletonRangedIsoUnitView.tscn` sélectionne `CombatStyle.RANGED`

Les deux scènes minces ne diffèrent que par `combat_style`. Elles partagent mesh, rig, skin, matériaux, textures, AnimationPlayer, SubViewport et contrôleur de base.

Les variantes utilisent des animations simulant une attaque de mêlée et un tir à distance. Les équipements visibles ne font pas partie de cette première version.

Les origines d'effet sont attachées uniquement aux os audités `LeftHand` et `RightHand`. Aucun objet d'équipement n'est instancié.

## Profils gameplay

### `skeleton_melee`

- 75 PV, 2 PM, 16 attaque, 8 armure
- attaque de base physique, portée 1, coût 2 PA existant
- `ai_behavior = MELEE`
- `combat_style = MELEE`
- cherche l'adjacence
- animation `DD_Skeleton_MeleeAttack`, impact normalisé 0,244444

### `skeleton_ranged`

- 38 PV, 3 PM, 7 attaque
- attaque de base désactivée
- sort `skeleton_ranged_shot` : 2 PA, 8 dégâts physiques, portée 6, ligne de vue obligatoire
- `ai_behavior = RANGED`
- `combat_style = RANGED`
- `minimum_range = 3`, `preferred_range = 6`, `maximum_range = 6`, `keep_distance = true`
- animation `DD_Skeleton_RangedAttack`, libération normalisée 0,850575

Les propriétés de portée sont génériques dans `UnitData` et `Unit`. `enemy_ai.gd` ne contient aucune condition sur `unit_name`, « squelette », MELEE ou RANGED comme nom de personnage.

## Synchronisation et projectile

`EnemyTurnRunner` suit le même contrat générique que le joueur : orientation, préparation visuelle, attente de l'impact/libération, résolution unique, puis récupération visuelle. Le chemin distant utilise `SpellCaster.begin_cast()` puis `resolve_cast()` exactement une fois.

`skeleton_ranged_projectile_vfx.tscn` dessine un trait ivoire sobre :

- origine projetée entre les mains ;
- trajet linéaire de 0,22 s ;
- disparition et `queue_free` à l'impact ;
- watchdog local de 1,0 s ;
- aucun dégât et aucun événement gameplay.

## Run V1

La vraie chaîne active est `Title → PartyPresentationScreen → fixed_trio_prototype_run.tres`. Les quatre RoomData actives sont :

1. `res://data/rooms/bible/le_gue.tres`
2. `res://data/rooms/terrain_2.tres`
3. `res://data/rooms/bible/la_forge.tres`
4. `res://data/rooms/bible/elite_brute.tres`

Chaque roster préparé est exactement, dans cet ordre :

1. `skeleton_melee`
2. `skeleton_melee`
3. `skeleton_ranged`

Toutes les références Gobelin, GobTest, Pyromage, Éclaireur et placeholders sont retirées de ces quatre listes seulement. Les ressources historiques restent présentes et chargeables. Le trio joueur reste strictement Elfe, Mage, Guerrier.

## Validation automatisée

`test_skeleton_first_enemy.gd` couvre :

- un GLB, un rig, 24 os, un skin, 4 054 triangles et sept animations ;
- boucles Idle/Walk/Run ;
- profils distincts partageant le même modèle ;
- aucune arme ou accessoire attaché ;
- durées et marqueurs d'impact ;
- ressources génériques et portée 1/6 ;
- IA de mêlée et tir à six cases ;
- ligne de vue bloquée ;
- absence de branchement par nom ;
- exactement 2 MELEE + 1 RANGED dans chaque salle ;
- projectile nettoyé ;
- dégâts uniques via SpellCaster et EnemyTurnRunner ;
- récupération visuelle attendue ;
- libération de cellule sans déplacement de la racine visuelle ;
- quatre orientations ;
- cadence partagée 0,24 s.

Résultats dans le dépôt réel avec Godot 4.7.1 :

- Squelette : 13/13 tests, 104 assertions
- Squelette + Guerrier + Run V1 : 27/27 tests, 461 assertions
- Scène + HUD + trio : 23/23 tests, 263 assertions
- Suite complète : 387/392, 6 736/6 752 assertions ; les cinq échecs concernent exclusivement les tests Elfe historiques déjà identifiés (`test_elf_archer_skill_tree`, trois cas `test_elf_rank_two_disciplines`, `test_progression_lifecycle`).
- GUT ignore aussi le script historique `test_dark_pause_menu.gd` à cause de quatre inférences `path` déjà invalides sous Godot 4.7.1 ; ce script n'est pas compté parmi les cinq échecs et n'est pas lié à cette passe.

## Captures et performances

Les cinq captures Blender et quatorze captures Godot 1920 × 1080 sont dans `res://artifacts/skeleton_first_enemy/`. Elles couvrent les deux profils au repos, attaque de mêlée, libération distante, projectile, Hit, Death, Y-sort, déplacement, le trio contre les trois Squelettes et la salle 1 réelle avec HUD compact.

La validation graphique utilise D3D12/Forward+ sur une NVIDIA GeForce RTX 4070 Laptop GPU, à 1920 × 1080, V-Sync désactivée. Les quatre phases mesurées (repos, déplacement, attaque, plusieurs ennemis visibles) totalisent 2 228 échantillons : 852,68 FPS de moyenne et 756 FPS minimum. Une seconde fenêtre stable de salle 1 mesure 915,18 FPS de moyenne et 882 FPS minimum. Six SubViewports 768 × 512 sont actifs. Aucun avertissement renderer ni VFX résiduel n'a été observé.

## Fichiers principaux préparés

Créés : GLB Squelette, six scènes/scripts Squelette, projectile, sort distant, deux UnitData, source de timing, banc d'import, banc de capture, test Squelette, trois rapports et cinq captures Blender.

Modifiés : `battle.gd`, `enemy_turn_runner.gd`, `unit_view.gd`, `character_iso_unit_view.gd`, `warrior_visual_3d.gd`, `enemy_ai.gd`, `unit_data.gd`, `unit.gd`, quatre RoomData et deux tests existants.

## Git

- Branche cible : `main`
- HEAD : `fdbccb290382265b4ab73991de08f53ac941168d`
- État cible final : modifications de travail attendues correspondant au paquet et aux captures de validation ; `git diff --check` propre
- Commit : aucun
- Push : aucun

## APPLICATION AU DÉPÔT RÉEL

- ZIP utilisé : `C:\Blender_AI_Test\Output\skeleton_godot_patch_20260802.zip`
- SHA-256 du ZIP : `12F67C2171FEB83BB84AA85185EC56A8C54EBCEC396FA7360F6DBFDA53DD8992`
- Entrées contrôlées : 45, dont 40 fichiers et 5 dossiers ; aucun chemin absolu, parent, `.git`, `.godot` ou `.claude/settings.local.json`
- Fichiers appliqués : 40, soit 26 ajouts et 14 remplacements ciblés au moment de l'application
- Conflits détectés : aucun ; le dépôt était propre au HEAD attendu et les 40 fichiers copiés correspondaient exactement au staging validé
- Suppressions : aucune
- GLB importé : `res://assets/enemies/skeleton/skeleton_character_v01.glb`
- SHA-256 du GLB : `048245A6A4A35A97AA73CAE04FD9A4C1C4F693C28ACBE26C8E0AFE30A4BE1827`
- Import réel : un Skeleton3D de 24 os avec racine `Hips`, un mesh skinné, environ 4 054 triangles et les sept animations de production
- Renderer : D3D12/Forward+, 1920 × 1080, RTX 4070 Laptop GPU ; moyenne combinée 852,68 FPS, minimum 756 FPS, 2 228 échantillons
- SubViewports : 6, chacun en 768 × 512
- Captures : 13 captures graphiques produites par `SkeletonCaptureValidation.tscn`, plus `first_room_trio_vs_skeletons_1920x1080.png` issue de la salle 1 réelle
- Tests réels : 27/27 ciblés, 23/23 scène/HUD/trio, suite 387/392 avec uniquement les cinq échecs Elfe préexistants
- Git final : 14 fichiers suivis modifiés et 69 fichiers non suivis. Ce total regroupe les 40 fichiers du paquet et 43 sorties générées par Godot/validation (14 captures, 19 sidecars d'import d'images, 3 fichiers d'import/extraction du GLB et 7 UID de scripts). Aucun chemin `.git`, `.godot` ou `.claude/settings.local.json` n'apparaît dans le statut ; aucun commit ni push.

Les variantes utilisent des animations simulant une attaque de mêlée et un tir à distance. Les équipements visibles ne font pas partie de cette première version.
