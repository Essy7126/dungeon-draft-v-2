# Audit des sources de production

Audit réalisé sur le commit de jeu `1aadd1bd1dec5d1cf108740c0f57e80047d22539`.

## Parcours de production

`res://ui/party/PartyPresentationScreen.tscn` référence `res://data/runs/first_run.tres`. Son script appelle `GameManager.start_preconfigured_run`, qui construit l’état avec le trio déclaré dans `GameManager.PRODUCTION_HERO_DATA_PATHS`.

| Domaine | Source | Classement | Preuve |
| --- | --- | --- | --- |
| Première run | `res://data/runs/first_run.tres` | `production_root` | Référence directe de `PartyPresentationScreen.tscn` avant l’appel à `start_preconfigured_run`. |
| Elfe | `res://data/units/alliés/elfe.tres` | `production_reference` | Membre du trio ordonné utilisé par `GameManager`. |
| Mage | `res://data/units/alliés/mage.tres` | `production_reference` | Membre du trio ordonné utilisé par `GameManager`. |
| Guerrier | `res://data/units/alliés/Guerrier.tres` | `production_reference` | Membre du trio ordonné utilisé par `GameManager`. |
| Sorts | Références `UnitData.spells` | `production_reference` | Traversée depuis les trois `UnitData`, sans découverte de dossier. |
| Disciplines | Références `UnitData.disciplines` | `production_reference` | Traversée depuis les trois `UnitData`, rangs et choix inclus lorsqu’ils sont déclarés. |
| Objets | `res://data/items/catalogs/default_item_catalog.tres` | `catalog` | Préchargé par `GameManager.DEFAULT_ITEM_CATALOG`, puis validé à l’initialisation de run. |
| Récompenses génériques | `res://data/post_combat/post_combat_reward_service.gd` | `static_service_definition` | Trois ressources préchargées par le service instancié et appelé par `GameManager`. |
| Pool d’équipement | `res://data/post_combat/first_run_equipment_reward_service.gd` | `static_service_definition` | Filtrage du catalogue par `first_run_equipment_reward`, avec deux options requises. |

## Exclusions et découverte

- Les autres `.tres` présents dans les dossiers ne sont pas considérés actifs sans référence de production.
- `fixed_trio_prototype_run.tres`, les laboratoires et les captures sont classés `debug` ou `discovery_only`.
- Les valeurs calculées au runtime, probabilités sans poids explicite et simulations de combat ne sont pas exportées.
- Les ressources de salles et ennemis sont atteignables depuis la run, mais leur détail reste reporté dans cette version.

## Baseline de non-régression

Godot 4.7.1 et GUT 9.7.1 exécutent 653 tests sur le commit de base : 642 réussites et 11 échecs préexistants. Ces échecs concernent huit scripts de captures, d’assets et de présentation ; la fondation ne tente pas de les corriger.
