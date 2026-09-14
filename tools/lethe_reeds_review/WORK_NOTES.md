# Les roseaux du tireur — notes de travail

Mise à jour du 12 septembre 2026, avant le verdict GPU final.

## Périmètre et état

La salle `route_6d5efdb88ff0`, étape V, correspond à `d05_1`, graine 2401,
après La stèle des noms. Elle reprend la même barque à trois bancs et sa
lanterne sur une berge ouverte dans les roseaux. Les 112 cellules de sol,
83 cellules de fosse, 8 obstacles et la rencontre existante restent canoniques.

La baseline est conservée dans `artifacts/dev/lethe-reeds/before/`. La peinture,
les prompts et la calibration sont dans `assets/catabase/combat/lethe_reeds_v1/`.
L’image finale mesure 1586 × 992 pixels ; son SHA-256 est
`4a5e890fc8465ae3aa6ec93d07f64b21fc974a7a3ae986f6eaa5958bcf4aa248`.
Le support est installé et les shaders sont prêts. La revue GPU est en cours ;
aucune réussite GPU des Roseaux n’est encore consignée ici. Le responsable de
l’exécution lance seul Godot avec `artifacts/dev/engine.lock` et ajoutera ses
preuves finales. Préserver les autres tâches et les autres maps modifiées.

## Enseignements de la création

La base peinte doit offrir une surface sèche assez large sous les cellules
complètes et leur réserve. Les fosses du parcours sont ensuite rendues en eau
par `Platform` et leur shader local, d’après la géométrie canonique. Cette
séparation conserve une frontière praticable lisible après l’élargissement de
la berge peinte ; la peinture ne décide pas des collisions.

Les premières peintures plaçaient des pointes de dalles sur l’eau ou sur des
faces verticales. Le contour de support suit désormais le bord supérieur sec,
y compris ses concavités. La poche centrale et sa couronne verticale sont
exclues. Une enveloppe convexe de guide ne prouve pas le support d’une rive
intérieure. Les exigences restent de 30 pixels natifs de marge sèche et de
20 pixels natifs de distance aux rives.

Les corrections utilisent un aplat opaque couvrant les cellules en échec et
une réserve dilatée. Les deux encoches persistantes ont demandé des rectangles
opaques couvrant aussi leurs anciennes parois : toute cette emprise devait
devenir du pavage supérieur continu. Le contour a été retracé et audité sur
chaque nouvelle peinture. Guides, vues agrandies et rapports complets :
`artifacts/dev/lethe-reeds/`.

## Contrôles déjà obtenus

- [Support indépendant](../../artifacts/dev/lethe-reeds/final-dry-surface-audit.json) :
  112 cellules sur 112 passent ; marge minimale de 31,0049 pixels natifs.
  [Contour](../../artifacts/dev/lethe-reeds/final-contour.json) : 177 points
  extérieurs, une poche de 23 points, aucune auto-intersection.
- [Parcours unitaire](../../artifacts/dev/20260912-125530-test-test_unit_test_catabase_route_layouts.gd-d0bcd58e/gut-strict-report.json) :
  3 tests, 15 940 assertions réussies, aucun test ignoré ni erreur de parsing.
- [Oracle partagé sur Les lances oubliées](../../artifacts/dev/20260912-125743-lethe-lances-review-d5c7b8e5/summary.json) :
  les deux formats passent, avec rapports et captures présents. Cette preuve
  couvre la non-régression des Lances, pas le rendu final des Roseaux.

## Validation finale

La revue des Roseaux mesure six régions : `water`, `channel`, `vegetation`,
`lantern`, `stable_ground`, `stable_wall`. Huit instants de 0 à 3,15 secondes,
par pas de 0,45, sont capturés en 1920 × 1080 et 1200 × 896. Les quatre premières
régions doivent s’animer ; les deux témoins de pierre doivent rester fixes.
Le mouvement réduit doit figer l’horloge et les pixels des six régions.

Le moteur confirme le support des sprites réels, la barque entière hors HUD,
les proportions entre formats, le picking, le déplacement et la garde.
Les captures finales des deux formats ont été inspectées, ainsi que le
placement initial dans le parcours réel en 1600 × 900. Le cadrage final
est `Vector2(-120, 50)` : il garde aussi la coque hors du journal au placement.

Rapports finaux :

- GPU : `artifacts/dev/20260912-135650-lethe-reeds-review-a5e78c11/summary.json`.
- Production : `artifacts/dev/20260912-135504-lethe-reeds-expedition-8d762996/summary.json`.
- Unités : `artifacts/dev/20260912-134727-test-test_unit_test_catabase_route_layouts.gd-ea0c756c/gut-strict-report.json`.
- Essai ouvert : `artifacts/dev/20260912-140018-lethe-reeds-play-3e864f6f`.

Deux WebP animés de laboratoire bloquaient l’import. Après vérification de
l’absence de références de jeu, seuls leurs dossiers de sortie
`artifacts/spine_trial/veilleur_walk_E_v3` et `veilleur_walk_E_v4` ont reçu
un `.gdignore` ; leurs fichiers sont conservés. Le dernier import passe.

Les contrôles ne jouent pas une victoire complète. Aucune navigation libre
de la barque ni nouvelle liaison de parcours n’a été ajoutée. Mission terminée.
