# Rapport de régression Dungeon Draft Studio 1.2.1

## Environnement et baseline

- dépôt : `C:\Users\paolo\Documents\dungeon-draft-v-2` ;
- branche/HEAD initial et final attendu : `main`, `1ba5ea5f91c8600bc8a139853859788aa7557334` ;
- moteur : Godot `4.7.1.stable.official.a13da4feb`, Forward Plus ;
- état initial : 0 fichier modifié, non suivi, staged ou en conflit ;
- recette globale initiale : 70 scripts, 676 tests, 666 passes,
  10 échecs, 49026/49079 assertions.

## Résultats 1.2.1

| Suite | Résultat | Assertions |
|---|---:|---:|
| Studio 1.2.1 | 10/10 | 871 |
| Arena Studio 1.0 | 15/15 | 1287 |
| Historique/transform 1.1 | 16/16 | 1378 |
| Dungeon Draft Studio 1.2 | 8/8 | 108 |
| Encounter Studio | 15/15 | 166 |
| Dynamic Arena | 21/22 | 366/368 |
| Arena Map Editor | 9/9 | 198 |
| Projection ISO | 6/6 | 34 |
| IsoGridView | 8/8 | 111 |
| Présence unités peintes | 20/20 | 257 |

Les deux smokes runtime passent : salle peinte forêt et salle modulaire 1.2,
avec `GridData`, pathfinder, monde Y-sorté et renderer partagés.

## Recette globale finale

La recette finale exécute 71 scripts et 686 tests : **676 passent, 10
échouent, 49897/49950 assertions passent**. Les dix tests 1.2.1 passent dans
ce run. Le nombre et l’identité des échecs sont identiques au baseline :

1. deux styles absents du thème pause sombre ;
2. `wall_assets_normalized.png` absent du jeu de captures Dynamic Arena ;
3. les 22 captures historiques forêt absentes ;
4. les 11 captures historiques de grille forêt absentes ;
5. quatre tests blueprint montagne dépendant de PNG absents ;
6. trois images du pool peint absentes ;
7. une comparaison flottante instable dans la timeline d’ordre des tours.

Aucun de ces fichiers ou systèmes n’appartient au diff Studio 1.2.1.

## Captures

Le dossier `artifacts/studio_1_2_1/screenshots/before` contient 15 références
avant. Le dossier `after` contient 66 captures : 22 cas indépendants à
1280×720, 1920×1080 et 2560×1440. `capture_metrics.json` confirme le même
nombre d’enfants dans le centre, le canvas visible en Construction dynamique,
la palette contextuelle correspondante et aucun delta de fenêtre ou popup
entre édition, mode intégré, focus, détachement simulé et gameplay.

Les cas couvrent notamment : mode dynamique intégré/détaché/focus, peinture
terrain/mur, gizmo complet, translation, rotation, échelle, pivot, angle
ouvert/fermé, Conserver X/Y, ancres isolées, gameplay isolé et parité
forêt/volcan/espace.

## Compilation et avertissements

Le scan éditeur final ne signale aucune erreur de parsing Studio. Restent les
avertissements initiaux : magasin de certificats Windows inaccessible dans le
sandbox, trois UID de textures GLB historiques, et une classe globale masquée
dans le projet imbriqué hors périmètre
`output/validation-feedback-candidate`.

## Verdict

`DUNGEON_DRAFT_STUDIO_1_2_1_COMPLETE_WITH_WARNINGS`

Les avertissements correspondent exclusivement à des défauts préexistants ou
à des assets de certification historiques absents. Aucun échec nouveau n’est
introduit par la mission.

