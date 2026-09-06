# Audit technique Run Data V1

## Chemin de lancement

| Chemin | Symbole | Statique disponible | Runtime | Déterminisme | Effet secondaire | Export retenu |
| --- | --- | --- | --- | --- | --- | --- |
| `ui/party/PartyPresentationScreen.tscn` | `ExtResource("3_run")` | `first_run.tres` | Aucun | Stable au commit | Aucun au chargement | Racine unique du manifeste. |
| `ui/party/party_presentation_screen.gd` | `_on_start_pressed` | Run et trio ordonné | Appel de `start_preconfigured_run` | Déterministe | Transition de scène | Preuve uniquement, méthode non appelée. |
| `core/game_manager.gd` | `_initialize_run_state` | Salles, seed, plafond | État courant de run | Déterministe à l'initialisation | Mutations d'autoload | Non exécuté ; champs lus depuis `RunData`. |
| `core/run_wave_count_resolver.gd` | `resolve_counts` | Run + seed | Aucun autoload | Pur pour les mêmes entrées | Aucun | API de production appelée directement. |
| `core/game_manager.gd` | `get_current_room` / `get_current_encounter_definition` | Index et références | Dépend de l'avancement | Déterministe pour un état donné | Aucun | Relation statique reproduite via les Resources. |
| `battle/battle.gd` | `_spawn_enemies` | Roster ou fallback | Placement et unités vivantes | Seedée pour la formation | Instancie des unités | Roster exporté, placement non simulé. |
| `data/encounters/encounter_runtime_state.gd` | `can_prepare_summon` | Budgets, plafond, capacités | Compteurs consommés | Dépend du combat | Réserve des invocations | Budgets et limites seulement. |
| `core/enemy_ai.gd` | `build_action_plan` | Profil, sorts, seuils | Cibles et grille | Dépend de l'état | Plan d'action | Profil statique et possibilités seulement. |

## Resources et validation

- `RunData` : `validation_errors()` et `is_valid()`.
- `RoomData` : `get_wave_count()`, bornes clampées, fallback historique et ressources de carte.
- `RoomWaveData` : `validation_errors()` et `is_valid()`.
- `EncounterDefinition` : `get_initial_enemy_count()`, `expanded_roster()`, `validation_errors()` et `is_valid()`.
- `UnitData` : identifiant explicite, statistiques, équipe, sorts, profil d'IA et passifs.
- `EnemyAIProfile` : stratégie technique, rôles, seuils et préférences.
- `Spell` : effets, conditions, limites et `summon_unit_data`.

## Multiplicateurs et agrégats

`Battle._apply_current_wave_scaling` ajoute `multiplier - 1.0` comme `Stat.ModType.PERCENT` à `Unit.max_hp` et `Unit.attack_power`, puis synchronise `current_hp` avec `max_hp.get_int()`. `Stat.get_int()` applique `round((base + plats) × (1 + pourcentages))`.

L'export calcule donc les totaux de vague comme la somme, unité par unité, de `round(base × multiplicateur)`. Les attaques de base lisent `Unit.get_attack()` donc `attack_power`; `SpellCaster` applique `Spell.damage` et ne lit pas `attack_power`. Le statut d'effet du multiplicateur d'attaque est établi à partir de ces chemins et de `basic_attack_enabled`, sans calcul de DPS ni simulation.

## Fermeture des invocations

Le parcours commence par les rosters initiaux et le fallback `RoomData.enemies` uniquement s'il est réellement actif. Chaque `Spell.summon_unit_data` ajoute une arête, avec déduplication par `unit_id`, protection par ensemble visité et fermeture fixe bornée à 8 niveaux. Les contextes de salles et rencontres sont propagés aux unités invoquées ; la composition finale reste runtime-only.
