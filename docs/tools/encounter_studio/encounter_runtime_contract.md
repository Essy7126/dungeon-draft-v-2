# Contrat runtime des rencontres

Ce document décrit le comportement observé dans le checkout local au 5 août 2026. Il ne définit pas un second moteur : le Studio appelle les mêmes Resources et services que le jeu.

## Graphe de ressources

```text
RunData
└── rooms: Array[RoomData]
    ├── battle_scene
    ├── grid_layout / painted_map_visual_data
    ├── hero_spawn_zone / enemy_spawn_zone
    ├── waves: Array[RoomWaveData]
    │   └── encounter_definition: EncounterDefinition
    │       └── roster_units: Array[UnitData] + roster_counts
    ├── encounter_definition          (fallback historique)
    └── enemies: Array[UnitData]       (fallback historique ancien)

Combat
└── EncounterRuntimeState             (budgets et compteurs consommables)
```

La première run de production est `res://data/runs/first_run.tres`. Elle référence six salles et dix définitions de vague par salle. Dans une salle donnée, les dix vagues partagent actuellement la même `EncounterDefinition`; les multiplicateurs appartiennent aux `RoomWaveData`.

## Sélection moderne et fallbacks historiques

- Si `RoomData.waves` n’est pas vide, `RoomData.get_wave(index)` puis `wave.encounter_definition` sont l’unique source moderne. Les champs `room.encounter_definition` et `room.enemies` restent des fallbacks affichés comme historiques et ne sont pas synchronisés artificiellement.
- Si `waves` est vide, l’index 0 utilise `room.encounter_definition`.
- Si cette définition est absente, l’ancien roster `room.enemies` reste lisible par le contrat historique.
- Une migration historique n’est jamais exécutée au chargement. L’assistant crée une vague et une définition dans la copie de travail, conserve les anciens champs, puis attend une sauvegarde confirmée.

Le roster réel est développé par `EncounterDefinition.expanded_roster()`. Seule la portion parallèle commune de `roster_units` et `roster_counts` est consommée; chaque quantité positive répète la même référence externe `UnitData`.

## Grille, distances et maps peintes

`EncounterGridFactory` est partagé par `battle.gd`, le Studio et les tests.

- Map peinte : la taille et les types de cases viennent de `RoomGridLayout.apply_to_grid()`.
- Map scène : la scène de bataille est instanciée sans l’ajouter à l’arbre; le `TerrainLayer` et sa donnée `cell_type` sont importés avec les mêmes règles que le combat.
- `GridData` reste l’autorité sur la validité, le terrain, la praticabilité et l’occupation.
- `Pathfinder` calcule les chemins et distances. La prévisualisation mesure la distance minimale à `hero_spawn_zone`, c’est-à-dire la **zone de déploiement alliée avant placement manuel**, pas les positions finales des héros.

Pour une map peinte, `PaintedMapVisualData.cell_to_image()`, `cell_polygon()` et `image_to_cell()` sont les seules transformations visuelles utilisées. L’image n’est jamais interprétée pour inventer du gameplay.

## Planification et seed

`EncounterFormationPlanner.build_plan()` est appelé directement par le combat, la prévisualisation et l’analyse multi-seeds. La seed effective est calculée par le service partagé :

```text
seed_effective = seed_run + index_affrontement × 104729
```

L’index de salle ne participe pas à la formule runtime actuelle. `EncounterSeedResolver` centralise donc exactement cette formule, sans appel au RNG global.

Les formations reconnues sont exclusivement `EncounterDefinition.FORMATION_IDS` : `line`, `double_line`, `left_flank`, `right_flank`, `chief_forward`, `centurion_rear`, `split`. Le Studio ne maintient que leurs libellés français, avec un test de couverture du registre.

Le planificateur contient des politiques spécialisées pour les rôles squelettes (`skeleton_normal`, `skeleton_chief`, `skeleton_centurion`). Un rôle différent suit le fallback générique réel et produit un avertissement informatif; il n’est pas bloqué.

## Contraintes strictes et préférences souples

Contraintes strictes :

- cellule valide, praticable et libre;
- `forbidden_initial_spawn_cells` exclue sans exception le déploiement initial ennemi;
- `minimum_path_distance_by_role` rejette une case trop proche;
- une unité ne peut pas partager une case;
- le nombre de placements doit couvrir le roster développé.

Préférences souples :

- `enemy_spawn_zone` est une **zone ennemie préférée**; le score favorise ses cellules, mais le planificateur peut sortir de la zone;
- `maximum_path_distance_by_role` est une **distance maximale souhaitée**; la dépasser pénalise le score sans invalider le placement;
- les profils de formation ordonnent et notent les candidats dans la limite de `maximum_formation_attempts`.

`allowed_spawn_groups` est présent dans la Resource mais n’est pas consommé par le runtime actuel. Il reste visible en mode Avancé avec ce statut explicite et sans validation fictive.

## Invocations et état de combat

`EncounterRuntimeState` copie les plafonds et budgets depuis la définition au début du combat. Les capacités d’invocation actives consomment `shared_normal_summon_budget` ou `shared_chief_summon_budget`; `living_enemy_cap` limite le nombre vivant. `disabled_ability_ids` est évalué avant de rendre une capacité disponible. Les compteurs consommés ne sont jamais écrits dans l’`EncounterDefinition` canonique.

## Vagues, transitions et persistance

`RunWaveCountResolver` reproduit la séquence RNG historique de `GameManager` : un seul `RandomNumberGenerator` seedé par la run parcourt les salles dans l’ordre, applique le plafond `RunData.maximum_waves_per_room`, puis tire entre les bornes de chaque salle. Le comportement historique étrange d’une salle vide est conservé : les `clampi` imbriqués peuvent aboutir à un compte de 1; il n’a pas été « corrigé » dans cette mission afin de préserver la parité.

Chaque affrontement reste un combat distinct qui recharge `battle_scene`. Persistent entre deux combats : seed de run, index de salle/vague, états de personnages, PV/progression, inventaire, récompenses et rapport de salle agrégé selon `GameManager`. Réinitialisés : grille, `Pathfinder`, unités ennemies, `EncounterRuntimeState`, file de tours, surbrillances, terrain local et état visuel de bataille.

`RoomRewardProjectionService` partage les salts et calculs déterministes de chance ultime et de multiplicateur cumulatif avec `GameManager`. Aucun équilibrage, roster, multiplicateur, statistique, IA, récompense ou règle de sortie n’a été modifié.

## Invariants

1. Les Resources de production sont la source de vérité et restent inchangées avant confirmation explicite.
2. Prévisualiser, valider, analyser ou tester ne mute jamais la ressource canonique.
3. Le Studio ne consomme pas le RNG global.
4. Une ressource partagée reste partagée jusqu’à l’action explicite « Dupliquer pour cet affrontement ».
5. La suppression d’une vague retire une référence; elle ne supprime jamais le fichier de rencontre.
6. Les enfants sont sauvegardés avant les parents, puis rechargés et reliés comme ressources externes.
7. Un conflit de fingerprint disque bloque la sauvegarde.
8. Les maps peintes conservent exactement leurs transformations et types de cases.

