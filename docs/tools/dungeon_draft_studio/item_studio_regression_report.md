# Item Studio V1 — rapport de régression

- Date : 2026-08-07
- Branche : `main`
- HEAD de base : `29f307b5ff61822f266bbd2d14636ca8dcea2d95`
- Statut : **WORKTREE_CANDIDATE — READY_FOR_HUMAN_REVIEW**
- Godot : `4.7.1.stable.official.a13da4feb`
- GUT : `9.7.1`
- Non vérifié : revue humaine interactive dans l’éditeur Godot.

## Baseline avant modification

- Import Godot isolé : code 0, avec diagnostic historique de classe globale
  dupliquée sous `output/validation-feedback-candidate`, erreur de certificats et
  fuites `ObjectDB` à la fermeture.
- Inventaire/équipement : 10/10, 93 assertions, code 0.
- Suite globale : 806/819, 52 941/52 998 assertions, code 1.
- Les 13 échecs sont les catégories historiques documentées : textures de pause,
  captures/murs, contrat Eagle Eye/Elfe, Mountain Pass/pool peint et comparaison
  flottante de tour.

## Validations du candidat déjà exécutées

- Caractérisation PASS : 19 définitions, couverture valide, aucun partage mutable.
- GUT Item Studio : 30/30, 190 assertions, code 0.
- Smoke complet : PASS, 3 onglets, 19 objets dynamiques, objet réel, working copy,
  effet ajouté, undo/redo, round-trip brouillon `user://`, projection runtime.
- Capture OpenGL : code 0, métriques valides et PNG exacts en 1280×720 et
  1920×1080. Les avertissements renderer à la fermeture sont ceux déjà observés
  sur les runners Studio de baseline.
- Suite globale finale : 836/849, 53 133/53 190 assertions, code 1. Les 13
  échecs et leurs catégories sont strictement ceux de la baseline : aucun test
  Item Studio et aucun contrat d’onglet Studio n’échoue.

## Matrice fonctionnelle

Les tests couvrent catalogue/empreintes, registre, effet inconnu préservé, copie
profonde, assets immuables, working copy, historique, brouillons, publication
fixture, rollback, collisions, ID publié, tag de récompense, previews
équipement/consommable, breakpoints, EHP, comparaison, état UI, refus
`RUN_SPECIFIC` et construction de l’écran.

Les écritures de test sont exclusivement sous `user://` avec un catalogue propre.
Aucun `.tres` de production n’est créé ou modifié.

## Inspection visuelle

Les captures de base montrent catalogue, filtres, équipement réel, modificateurs
de sorts et analyse. À 1280×720, les trois panneaux restent accessibles par
scroll ; aucun bouton critique n’est hors écran. À 1920×1080, le compositeur et
les références sont lisibles. Le premier passage a révélé « SHARED SHARED » ; le
libellé a été simplifié avant la matrice finale. Une seconde inspection a révélé
la boîte de création trop haute ; sa taille maximale a été corrigée et la
recapture montre le bouton « Créer la working copy » visible. Aucun enum brut
n’est affiché.

## Parité éditeur/runtime

Les ressources Item nécessaires à l’inspecteur portent `@tool`, sans changement
de règle de gameplay. Dans l’éditeur, l’analyse emploie une projection pure des
ressources exportées car `UnitData`/`Unit` ne sont pas des scripts `@tool` ; la
parité réelle `EquipmentService`, `ItemUseService` et `DamageResolver` est
couverte par GUT et le smoke exécutés hors `editor_hint`.

## Diagnostics non fonctionnels connus

- Magasin de certificats Windows non lisible dans la sandbox.
- Copie historique sous `output/validation-feedback-candidate` redéclarant
  `ItemDefinition` pendant l’import éditeur.
- RID/ObjectDB encore vivants à la fermeture des vues complexes, sans échec des
  marqueurs fonctionnels ciblés.
