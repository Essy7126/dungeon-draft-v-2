# Dungeon Draft Studio 2.0 — rapport de régression

Statut : **WORKTREE_CANDIDATE — VALIDATION TERMINÉE AVEC AVERTISSEMENTS**  
Date : 2026-08-06

## Preuves Studio 2.0 acquises

| Groupe | Résultat | Assertions |
|---|---:|---:|
| Contexte, graphe, run Arena, projection/surfaces, art, rattachement, profils Skills, descripteurs | 12/12 | 423 |
| Run Content isolation | 14/14 | 1 493 |
| Skill Tree historique | 50/50 | 521 |
| Arena/Encounter/Studio historique ciblé | 76/76 | 3 941 |
| Suite globale, 78 scripts | 787/800 | 52 044/52 101 |

Les 12 tests 2.0 incluent deux écritures temporaires réelles sous `res://artifacts/studio_2_0/`, supprimées en fin de suite : rattachement et relecture à l’index exact d’une RunData ; sauvegarde/relecture du `CharacterProgressionProfile` canonique sans sauvegarder la vue UnitData.

## Captures inspectées

- Arena run-aware : 1280×720 et 1920×1080 ;
- grid-first/surfaces : 1280×720 et 1920×1080 ;
- Skills profile-authoritative : 1280×720 et 1920×1080.

Constats : contexte partagé visible, séquence réelle de trois salles, textures pierre/eau/glace/lave et trois murs visibles, unités et spawns visibles, outils de surface visibles, graphe Archer lisible au grand viewport, descriptions métier sans fallback « spécialisé ». Le viewport 1280 reste plus dense et utilise les scrolls prévus.

## Avertissements connus

- fuites `ObjectDB` à la fermeture des runners graphiques/GUT ;
- suite globale finale à 13 échecs connus, exactement au niveau de la baseline :
  captures/assets absents, textures de focus pause nulles, contrats Eagle Eye
  historiques et comparaison flottante de timeline ;
- scan éditeur terminé avec le code 0 ; le duplicat historique de classe
  `ItemDefinition` sous `output/validation-feedback-candidate/` reste signalé ;
- `validation_report.json` historique peut recevoir un retour à la ligne de sérialisation sans delta métier.

Aucun statut `CURRENT` n’est déclaré par ce document.
