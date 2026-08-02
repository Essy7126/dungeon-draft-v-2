# Passe de rythme des animations de combat

## Source de vérité partagée

`res://characters/character_movement_timing.gd` porte désormais toutes les constantes de terrain :

- `MOVE_SEGMENT_DURATION = 0.24` seconde par case
- `WALK_CYCLE_DURATION = 0.84` seconde
- `RUN_CYCLE_DURATION = 0.65` seconde

`battle.gd` utilise cette durée pour le Tween de chaque segment. `CharacterIsoUnitView` calcule la vitesse des boucles Walk/Run à partir de la même ressource. L'IA appelle toujours `battle._animate_move`, donc héros et ennemis partagent exactement la même cadence. Les PM, portées, chemins et transformations racine 2D ne changent pas.

## Déplacement avant / après

| Distance | Avant | Après | Cycles Walk après |
|---:|---:|---:|---:|
| 1 case | 0,15 s | 0,24 s | 0,286 |
| 3 cases | 0,45 s | 0,72 s | 0,857 |
| 6 cases | 0,90 s | 1,44 s | 1,714 |

Avant, un cycle de jambes complet était forcé par case, soit un cycle toutes les 0,15 s. Après, la boucle est indépendante de la longueur du chemin et garde une cadence continue de 0,84 s.

| Personnage | Action | Durée source Godot | Playback speed | Durée de cycle finale |
|---|---|---:|---:|---:|
| Elfe | Walk | 1,000 s | 1,190476 | 0,840 s |
| Mage | Walk | 1,033 s | 1,230159 | 0,840 s |
| Guerrier | Walk | 1,033 s | 1,230159 | 0,840 s |
| Squelette | Walk | 1,250 s | 1,488095 | 0,840 s |
| Elfe | Run | 0,600 s | 0,923077 | 0,650 s |
| Mage | Run | 0,800 s | 1,230769 | 0,650 s |
| Guerrier | Run | 0,633 s | 0,974359 | 0,650 s |
| Squelette | Run | 0,750 s | 1,153846 | 0,650 s |

## Guerrier avant / après

Le GLB et les animations du Guerrier ne sont pas modifiés. Seules les vitesses de lecture sont recalibrées.

| Action | Avant | Après | Playback speed après | Impact normalisé | Impact réel après |
|---|---:|---:|---:|---:|---:|
| Attack | 0,83 s | 1,20 s | 4,944444 | 0,7191 | 0,863 s |
| SpinAttack | 0,99 s | 1,45 s | 3,908046 | 0,2294 | 0,333 s |
| HeavyAttack | 1,12 s | 1,65 s | 2,646465 | 0,3511 | 0,579 s |
| Parry | 0,60 s | 0,80 s | 0,708333 | 0,5879 | 0,470 s |
| Hit | 0,50 s | 0,65 s | 1,897436 | sans effet gameplay | — |
| Death | 1,46 s | 2,00 s | 1,483333 | sans effet gameplay | — |

Le contrat générique `UnitView.prepare_basic_attack_visual()` attend l'impact, applique les dégâts une seule fois, puis `wait_for_action_visual_finished()` laisse se terminer la récupération avant le retour au tour. Le signal de l'EventBus ne rejoue pas l'animation déjà préparée. Death conserve sa priorité.

## Squelette après

| Action | Durée importée | Playback speed | Durée finale | Événement |
|---|---:|---:|---:|---|
| MeleeAttack | 3,750 s | 3,000000 | 1,250 s | impact 0,244444, soit 0,306 s |
| RangedAttack | 7,250 s | 5,000000 | 1,450 s | libération 0,850575, soit 1,233 s |
| Hit | 5,833 s | 8,974359 | 0,650 s | fin de réaction |
| Death | 2,792 s | 1,395833 | 2,000 s | fin de mort |

Le projectile distant parcourt son trajet en 0,22 s. Il est strictement visuel et se détruit à l'impact ou au watchdog local.

## Validation

- Tests ciblés Squelette : 13/13
- Tests combinés Squelette + Guerrier + Run V1 dans le dépôt réel : 27/27, 461 assertions
- Tests scène + HUD + trio dans le dépôt réel : 23/23, 263 assertions
- Suite complète réelle : 387/392 et 6 736/6 752 assertions ; les cinq échecs Elfe historiques restent distincts et n'ont pas été touchés.
- Le script historique `test_dark_pause_menu.gd` est ignoré par GUT pour quatre erreurs d'inférence `path` préexistantes sous Godot 4.7.1.
- Validation graphique réelle D3D12/Forward+ à 1920 × 1080, V-Sync désactivée : 852,68 FPS de moyenne combinée, 756 FPS minimum sur 2 228 échantillons couvrant repos, déplacement, attaque et plusieurs ennemis visibles.
- Six SubViewports 768 × 512 sont actifs ; aucun avertissement renderer et aucun VFX résiduel n'ont été observés.

## APPLICATION AU DÉPÔT RÉEL

- Paquet : `C:\Blender_AI_Test\Output\skeleton_godot_patch_20260802.zip`
- SHA-256 : `12F67C2171FEB83BB84AA85185EC56A8C54EBCEC396FA7360F6DBFDA53DD8992`
- Application : 40 fichiers, sans conflit ni suppression, sur `main` au HEAD `fdbccb290382265b4ab73991de08f53ac941168d`
- GLB : importé par Godot 4.7.1, SHA-256 `048245A6A4A35A97AA73CAE04FD9A4C1C4F693C28ACBE26C8E0AFE30A4BE1827`
- Captures : quatorze nouvelles captures Godot 1920 × 1080 dans `res://artifacts/skeleton_first_enemy/`, dont la salle 1 réelle avec trio, deux Squelettes mêlée, un Squelette distance et HUD compact
- Git final : 14 fichiers suivis modifiés, 69 non suivis, `git diff --check` propre ; aucun chemin `.git`, `.godot` ou `.claude/settings.local.json`, aucun commit ni push
