# Dungeon Draft Studio 2.0 — baseline avant travaux

Statut : **WORKTREE_CANDIDATE — BASELINE OBSERVÉE**  
Date : 2026-08-06  
Godot : 4.7 stable, révision `5b4e0cb0f`  
GUT : 9.7.1

Cette baseline a été exécutée avant toute modification Studio 2.0. Elle décrit l'état réellement observable du worktree, y compris le chantier Run Content déjà présent au démarrage. Les logs et captures ont été copiés hors dépôt dans `C:\tmp\dungeon_draft_studio_2_0_checkpoint_20260806_173721\baseline`.

## Résultats automatiques

| Groupe | Scripts | Assertions | Résultat observé |
|---|---:|---:|---|
| Run Content isolation ciblée | 14/14 | 1493 | PASS |
| Run/trio/GameManager/cinématique/hub | 117/117 | 4908 | PASS |
| Arena/Encounter/Studio | 76/76 | 3941 | PASS, un avertissement GUT float/int |
| Skill Tree Studio + hardening | 50/50 | 521 | PASS |
| Dynamic Arena | 21/22 | 366/368 | 1 échec : capture de mur absente |
| Painted integration | 48/50 | 2268/2296 | 2 scripts en échec à cause de captures absentes |
| Suite globale | 775/788 | 51621/51678 | 13 échecs connus |

Les groupes ciblés ont été relancés avec `-gdir=` afin d'éviter l'héritage de `.gutconfig`. Une première commande globale involontaire a révélé puis confirmé exactement les 13 échecs de baseline décrits ci-dessous ; ils ne doivent pas être attribués au chantier 2.0 sans nouvelle preuve.

### Échecs globaux observés

1. textures de focus du thème pause nulles ;
2. capture `wall_assets_normalized.png` absente ;
3. nombre de modifiers Eagle Eye incorrect ;
4. nombre de rangs Elfe incorrect ;
5. 22 captures Forest Arena absentes ;
6. 11 captures Forest Dynamic Grid absentes ;
7. quatre tests d'images Mountain Pass blueprint ;
8. trois images du pool painted absentes ;
9. cycle progression Eagle Eye : nombre de modifiers incorrect ;
10. comparaison float de l'ordre des tours.

La liste ci-dessus regroupe les assertions par cause ; le total brut demeure 13 tests en échec.

### Smokes runtime

- Painted battle : PASS, `room_01_forest`, grille 14×14, `GridData`, `Pathfinder`, `IsoGridView` et `YSortedWorld` actifs.
- Modular battle : PASS, grille 12×9, mur dynamique, renderer partagé et `YSortedWorld` actifs.
- Run flow : PASS pour la run principale `SINGLE_ENCOUNTER` et la run de test `WAVE_CHAIN`; trois captures produites.

### Scan éditeur

Le scan Godot termine avec code 0. Avertissements observés : fallback d'UID invalide pour trois GLB ennemis et le GLB Elfe, classe `ItemDefinition` dupliquée sous `output/validation-feedback-candidate`, et fuites `ObjectDB` à la fermeture. Les suites GUT produisent également des fuites de nettoyage déjà présentes et quelques logs d'erreur attendus par leurs tests négatifs.

## Captures de référence

Le dossier externe contient 24 captures Arena 1280×720, 17 captures Skill Tree, quatre artefacts run et 14 logs, soit 59 fichiers. Le manifeste externe a pour SHA-256 :

`a30988bc09d90071c7026492903774ae4acae905efcdb6725b8b47269aa1abc5`

Le runner Skill Tree a été relancé avec un `APPDATA` isolé afin de ne ni consommer ni modifier les brouillons réels de l'utilisateur. Le renderer Windows `gl_compatibility` a été utilisé, le renderer headless/dummy ne produisant pas les textures requises.

### Observations Arena 1.3.1

Captures inspectées : nouvelle arène modulaire, terrain pierre, preview art et preview jeu.

- titre supérieur tronqué ;
- aucune run active ni portée d'édition visible ;
- bibliothèque d'autorité limitée à Forêt, Volcan et Espace ;
- outils très abrégés et difficilement découvrables ;
- textures sol/eau/glace/lave correctement visibles ;
- preview Art et preview Jeu visuellement proches, la seconde ajoutant surtout les unités ;
- provenance run/salle insuffisante pour une modification sûre.

### Observations Skill Tree

Captures inspectées : graphe complet, nœud avec effets, preview runtime.

- aucune barre run/héros/profil/portée ;
- graphe dense avec chevauchements et navigation difficile ;
- résumé de nœud contenant « effet spécialisé » ;
- Eagle Eye liste ses modifiers sans formulaire métier complet ;
- la preview appelle réellement `SpellCaster`, mais présente principalement un grand JSON brut.

## Frontières de baseline

- Les changements Run Content listés dans le contrat appartenaient déjà au worktree.
- Les captures manquantes sont des fixtures/artefacts de validation, pas une preuve d'échec logique du runtime.
- Le retour à la ligne ajouté par un runner dans `artifacts/arena_studio/arena_studio_test/validation_report.json` est un effet de sérialisation sans changement sémantique ; il doit être neutralisé ou documenté dans le delta final.
- Les fuites `ObjectDB` sont des avertissements de fermeture à suivre, mais les groupes critiques ciblés passent.

## Seuil de non-régression 2.0

Chaque phase majeure doit au minimum conserver :

1. 14/14 scripts et 1493 assertions d'isolation Run Content ;
2. les groupes Arena/Encounter/Studio et Skill Tree ciblés sans nouvel échec ;
3. les deux smokes battle et le smoke run flow ;
4. aucun nouvel échec global au-delà des 13 cas de baseline ;
5. aucun remplacement silencieux de document sale ;
6. aucune mutation d'une ressource canonique depuis une preview runtime.
