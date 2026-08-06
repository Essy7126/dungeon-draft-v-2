# Arena Stone Floor Visibility Fix

Date : 6 août 2026  
Baseline : `main` — `296f17c7c76626f1d2acd3cc5e650daf356d8ba8`

## Diagnostic

**OBSERVÉ** — La ressource réellement reliée à la première salle est `res://data/arenas/room_01_forest.tres`. Sur une working copy HYBRID équivalente à la conversion Studio, la cellule `(4, 0)` possède :

```text
terrain_id : normal
cell_type : NORMAL
defined : true
playable : true
texture : res://tools/labs/dynamic_arena/assets/normalized/stone.png
texture chargée : oui
visual_mode : HYBRID
floor_policy : NON_BASE_TERRAINS
base_terrain_id : stone
visible : non
skip_reason : hybrid_base_terrain
canvas : entrée présente mais invisible
Art : aucun nœud de dalle
Jeu : aucun nœud de dalle
runtime : 0 dalle normale rendue
```

**DIVERGENCE** — L'asset et l'identité terrain étaient corrects. Le filtre NON_BASE_TERRAINS supprimait `stone` et son alias `normal` avant le canvas et le renderer. Studio ne proposait aucun contrôle explicite pour choisir ALL_DEFINED ; importer un décor sur une map MODULAR pouvait donc transformer son affichage complet en HYBRID avec pierre masquée.

**OBSERVÉ** — Le contrôle ALL_DEFINED existait déjà dans le render plan et rend immédiatement les 163 cellules définies de la forêt. Le renderer, la projection affine et `stone.png` n'avaient pas besoin d'être remplacés.

## Décision validée

**DÉCISION VALIDÉE** — Le choix utilisateur **TOUTES LES DALLES TACTIQUES** applique exclusivement `ArenaModularVisualProfile.HybridFloorPolicy.ALL_DEFINED`. Il est disponible :

- dans le dialogue PAINTED → HYBRID ;
- dans le panneau permanent **SOL HYBRIDE** de Construction dynamique ;
- dans le dialogue Importer le décor.

Le changement est une action de working copy, annulable/rétablissable. Il actualise immédiatement le plan du canvas et la preview visible. Aucune ressource de production n'est modifiée sans Sauvegarder/Produire.

**DÉCISION VALIDÉE** — Le défaut rétrocompatible de `ArenaModularVisualProfile` reste NON_BASE_TERRAINS. Lors de l'ajout d'un décor à une map MODULAR, le dialogue présélectionne ALL_DEFINED uniquement pour préserver le sol déjà visible ; l'utilisateur peut choisir une autre politique avant confirmation.

## Chaîne vérifiée

`normal/stone → ArenaTerrainRegistry → stone.png → ArenaTerrainRenderPlanService(ALL_DEFINED) → ArenaStudioCanvas / ArenaTerrainVisualRenderer → Art / Jeu / runtime → ArenaVisualAssemblyReport → ArenaProductionService`

**OBSERVÉ** — Après correction sur la working copy forêt enrichie en mémoire :

- 163 dalles attendues et 163 rendues ;
- 154 dalles `normal` utilisant `stone.png` ;
- eau, glace et lave distinctes ;
- trois murs rendus au-dessus du sol ;
- unités visibles en vue Jeu ;
- Art et Jeu retournent `ok=true` aux trois résolutions.

## Validation

| Gate | Résultat |
|---|---:|
| Suite ciblée Stone/HYBRID | 6/6, 79 assertions |
| Arena Visual Pipeline + Studio 2.0 | 24/24, 553 assertions |
| Arena/Encounter/Studio final + nouveau test | 82/82, 4 020 assertions |
| Skill Tree + Run Content Isolation final | 64/64, 2 014 assertions |
| Suite globale finale | 793/806, 52 123/52 180 assertions |
| Scan éditeur final | code 0 |

**OBSERVÉ** — Le groupe Run/trio/hub a produit 116/117 lors d'un passage, puis son test d'annulation exact a passé isolément. La globale baseline a produit 786/800 : les 13 échecs historiques annoncés plus un test Hub intermittent, passé isolément au passage suivant. Ces tests et leurs fichiers sont hors périmètre et inchangés.

**OBSERVÉ** — Après correction, la globale contient 806 tests (les 800 historiques et les 6 nouveaux), avec 793 réussites et exactement les mêmes 13 échecs historiques. Aucun nouvel échec ni flake Hub n'est présent dans le passage final.

## Captures

Douze PNG réels ont été générés sous `res://artifacts/studio_2_0/stone_floor_visibility_fix/` : avant, canvas corrigé, Art et Jeu, chacun en 1280×720, 1920×1080 et 2560×1440. Le fichier `capture_metrics.json` enregistre 163/163 dalles, le chemin `stone.png`, trois murs et `art_ok/game_ok=true` pour chaque taille.

## Limites et avertissements

**HISTORIQUE** — Le scan éditeur conserve le parse error de la copie `ItemDefinition` sous `output/validation-feedback-candidate`, tout en terminant avec code 0. Les suites conservent des fuites ObjectDB/RID/resources à la fermeture.

**INCONNU** — La demande jointe s'arrête au milieu du bloc d'exemple après `skip_reason : hybrid_base_terrain`. Les exigences disponibles et l'objectif utilisateur complet ont été appliqués ; aucune consigne située après cette troncature n'était accessible.
