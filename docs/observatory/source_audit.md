# Audit des sources de production

- Statut : **CURRENT**
- Branche : `feature/observatory-live-v1-2`
- Commit de référence : HEAD propre utilisé par l’export ; valeur exacte publiée dans `meta.source_game_commit`.
- Date UTC : `2026-08-06`
- Validation : parcours actuel des deux runs, import Godot 4.7.1 et tests d’export V1.2.

## Parcours de production

Le hub référence la run principale `res://data/runs/first_run.tres` et l’outil de test `res://data/runs/fixed_trio_prototype_run.tres`. La première déclare `SINGLE_ENCOUNTER` ; la seconde déclare `WAVE_CHAIN`. Seule cette dernière appelle `RunWaveCountResolver` avec sa seed.

| Domaine | Source | Autorité | Stratégie |
| --- | --- | --- | --- |
| Runs | deux chemins explicites du manifeste | `declared_root` | Alias `primary_run` et `test_wave_run` ; aucune découverte de dossier. |
| Salles | `RunData.rooms` | `declared_reference` | Ordre du tableau et identité dérivée sous chaque alias. |
| Rencontres production | `RoomData.encounter_definition` | `production_reference` | Une rencontre unique par salle valide. |
| Vagues de test | `RoomData.waves` | `test_reference` | Profils ordonnés réels ; aucun pseudo-profil. |
| Ennemis | `EncounterDefinition.roster_units` | `production_reference` | Fermeture des rosters initiaux puis de `Spell.summon_unit_data`, profondeur maximale 8. |
| Sorts ennemis | `UnitData.spells` des ennemis atteignables | `production_reference` | Déduplication par `Spell.get_effective_spell_id()`. |
| Profils d'IA | `UnitData.ai_profile` | `production_reference` | `profile_id`, sinon chemin de Resource normalisé. |
| Héros | `GameManager.PRODUCTION_HERO_DATA_PATHS` | `production_reference` | Trio explicite conservé depuis V0. |
| Objets | `default_item_catalog.tres` | `catalog` | `ItemCatalog.get_definitions()` après validation. |
| Récompenses | Services post-combat | `static_service_definition` | Préchargements explicites et filtre de tag. |

## Exclusions

- Les runs debug ou legacy non déclarées par le manifeste ne sont pas exportées ; la run de test explicitement proposée reste consultable comme `test`, jamais comme production.
- Aucun `.tres` n'est déclaré actif à partir de sa seule présence dans un dossier.
- Aucune scène de combat n'est instanciée et aucun `.tscn` n'est parsé manuellement.
- Les placements, la formation choisie, les invocations réellement consommées et la composition finale restent des résultats runtime.

## Baseline de non-régression V1.2

La baseline initiale de cette mission sur le `main` vérifié exécute 848 tests GUT : 832 réussites et 16 échecs, dont deux tests Observatory obsolètes corrigés par le contrat V1.2 et quatorze échecs gameplay historiques. Le contrat machine-readable de CI documente uniquement ces derniers et accepte leur disparition, jamais un nouvel échec. Les chiffres finaux autoritaires sont ceux des rapports JUnit et CI attachés au commit V1.2.
