# Chemins migrés

Ce relevé distingue les déplacements physiques des migrations fonctionnelles réalisées en place. Aucun déplacement massif n'a été effectué : les UID Godot utiles ont été conservés et toutes les références actives ont été validées après migration.

| Ancien chemin | Nouveau chemin | Raison | Références mises à jour |
| --- | --- | --- | --- |
| `res://artifacts/skill_tree_refined_v2/node_icon_mapping.json` | `res://docs/reference/skill_tree_node_icon_mapping.json` | Conserver le mapping éditorial utile hors du dossier d'artefacts générés. | `res://test/unit/test_log_definitions.gd` |
| `res://data/runs/run_default.tres` et anciennes ressources de run | `res://data/runs/first_run.tres` | Une seule run de production, préconfigurée pour l'équipe fixe. | `res://ui/party/PartyPresentationScreen.tscn`, `res://core/game_manager.gd`, tests de run et de présentation |
| `res://data/rooms/bible/le_gue.tres` | `res://data/rooms/first_run_room_01.tres` | Conserver le contenu réellement exploitable sans garder la taxonomie de l'ancienne Bible MVP. | `res://data/runs/first_run.tres` |
| `res://data/rooms/terrain_2.tres` | `res://data/rooms/first_run_room_02.tres` | Conserver la salle active sous un nom de production explicite. | `res://data/runs/first_run.tres` |
| `res://data/rooms/bible/la_forge.tres` | `res://data/rooms/first_run_room_03.tres` | Conserver la salle active sous un nom de production explicite. | `res://data/runs/first_run.tres` |
| `res://data/rooms/bible/elite_brute.tres` | `res://data/rooms/first_run_room_04_boss.tres` | Réutiliser le layout existant comme salle de boss avec le chef squelette existant, sans inventer de valeurs. | `res://data/runs/first_run.tres`, tests du chef squelette et de la run |

## Migrations fonctionnelles en place

| Chemin conservé | Migration | Consommateurs vérifiés |
| --- | --- | --- |
| `res://units/unit.gd` | Retrait des façades énergie/Éveil, reset PA+PM, clamp des PV, statuts stables et événements de dégâts clarifiés. | Combat, tours, HUD, tests de contrats |
| `res://data/spell.gd` | Retrait des coûts et propriétés énergétiques ainsi que de `crit_multiplier`; ajout de l'identifiant de statut bonus. | SpellCaster, tooltips, ressources des sorts |
| `res://core/spell_caster.gd` | Cast payé uniquement en PA; XP attribuée une fois par cast; conservation des SpellModifier de progression. | Combat, progression, tests de casts |
| `res://core/event_bus.gd` | Retrait des signaux énergétiques; ajout de `health_damage_taken` et `status_refreshed`. | Journal, nombres flottants, vue d'unité, tests |
| `res://data/status/status_data.gd` | Identifiant stable et métadonnées explicites des dégâts périodiques. | Unité, statuts actifs, tests de contrats |
| `res://data/runs/run_data.gd` | Réduction au nom de run et à la séquence de salles; retrait du graphe/draft historiques. | GameManager, présentation de l'équipe, transitions |
| `res://data/units/alliés/Guerrier.tres` | Alignement sur quatre sorts et trois disciplines; arbres incomplets laissés incomplets. | Équipe fixe, HUD, progression, tests Guerrier |

