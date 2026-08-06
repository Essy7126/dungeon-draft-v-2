# Audit des sources de production

- Statut : **CURRENT**
- Branche : `feature/observatory-truth-v1-1`
- Commit de référence : HEAD propre utilisé par l’export ; valeur exacte publiée dans `meta.source_game_commit`.
- Date UTC : `2026-08-06T10:45:38Z`
- Validation : parcours des références chargées par le jeu, import Godot 4.7.1 et tests d’export V1.1.

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

## Baseline de non-régression V1.1

Après report de la V1 sur le main courant, Godot 4.7.1 et GUT 9.7.1 exécutent 728 tests : 717 réussites et 11 échecs hors Observatory, pour 50 353 assertions réussies sur 50 516. La suite Observatory isolée expose initialement 11 échecs dus au warning d’UID gameplay préexistant de `frappe_lourde.tres`. Le frontend intégré réussit 40 Vitest et 23 Playwright, avec zéro vulnérabilité npm.
