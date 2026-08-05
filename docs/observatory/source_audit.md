# Audit des sources de production

Audit réalisé sur le commit de jeu `1aadd1bd1dec5d1cf108740c0f57e80047d22539`.

## Parcours de production

`res://ui/party/PartyPresentationScreen.tscn` référence directement `res://data/runs/first_run.tres`. `party_presentation_screen.gd` transmet cette `RunData` à `GameManager.start_preconfigured_run`, puis `_initialize_run_state` conserve l'ordre de `RunData.rooms` et appelle `RunWaveCountResolver.resolve_counts` avec `default_seed`.

| Domaine | Source | Autorité | Stratégie |
| --- | --- | --- | --- |
| Run | `res://data/runs/first_run.tres` | `production_root` | Alias de manifeste `first_run` ; aucune découverte de dossier. |
| Salles | `RunData.rooms` | `production_reference` | Ordre du tableau, IDs Observatory `first_run.room.NN`. |
| Vagues | `RoomData.waves` | `production_reference` | Profils ordonnés ; fallback historique seulement lorsque le tableau est vide. |
| Rencontres | `RoomWaveData.encounter_definition` | `production_reference` | Déduplication par `resource_path`. |
| Ennemis | `EncounterDefinition.roster_units` | `production_reference` | Fermeture des rosters initiaux puis de `Spell.summon_unit_data`, profondeur maximale 8. |
| Sorts ennemis | `UnitData.spells` des ennemis atteignables | `production_reference` | Déduplication par `Spell.get_effective_spell_id()`. |
| Profils d'IA | `UnitData.ai_profile` | `production_reference` | `profile_id`, sinon chemin de Resource normalisé. |
| Héros | `GameManager.PRODUCTION_HERO_DATA_PATHS` | `production_reference` | Trio explicite conservé depuis V0. |
| Objets | `default_item_catalog.tres` | `catalog` | `ItemCatalog.get_definitions()` après validation. |
| Récompenses | Services post-combat | `static_service_definition` | Préchargements explicites et filtre de tag. |

## Exclusions

- Les runs de prototype, debug ou legacy qui ne sont pas référencées par le lancement ne sont pas exportées.
- Aucun `.tres` n'est déclaré actif à partir de sa seule présence dans un dossier.
- Aucune scène de combat n'est instanciée et aucun `.tscn` n'est parsé manuellement.
- Les placements, la formation choisie, les invocations réellement consommées et la composition finale restent des résultats runtime.

## Baseline de non-régression V1

Godot 4.7.1 et GUT 9.7.1 exécutent 679 tests sur le commit de base : 668 réussites et 11 échecs préexistants dans huit scripts hors Observatory. Les 26 tests Observatory V0 réussissent. Le frontend V0 réussit ses 29 tests Vitest et 17 tests Playwright, avec zéro violation Axe sérieuse et zéro vulnérabilité npm signalée.
