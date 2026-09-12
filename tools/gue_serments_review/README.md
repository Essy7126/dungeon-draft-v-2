# Le gué des serments

Combat de l'étape V, dans la continuité du Camp des compagnons : le chemin
quitte la galerie chaude des tailleurs et traverse une rivière de lave.
L'arcade, le tissu rouille et la roche bleu-gris reprennent le camp. Deux bornes
aux mains jointes, des oboles et une grenade évoquent les serments des voyageurs.

La destination existante `route_1c7d4c943b3a` conserve ses 109 dalles, obstacles,
adversaires et identifiants de sauvegarde. La graine 2401 relie le camp `d04_0`
au gué `d05_0`. Ce lieu utilise le combat tactique commun.

## Essayer

```powershell
./tools/gue_serments_review/open.ps1
./tools/gue_serments_review/verify.ps1
./dev.ps1 test test/unit/test_catabase_route_layouts.gd
```

L'essai utilise l'Explorateur de run et des données utilisateur isolées. Les
victoires antérieures sont simulées. F8 ferme la fenêtre.

## Source et pipeline

- `prepare.py` produit le guide depuis la géométrie canonique avant génération.
- `assets/catabase/combat/gue_serments_v1/land.png` est l'original **1586 × 992**
  de **image_gen intégré**, sans redimensionnement ni retouche déterministe.
- Le guide, le Camp des compagnons et l'Étal du passeur original ont été joints.
  Le prompt exact est conservé dans `assets/catabase/combat/gue_serments_v1/PROMPT.md`.
  La révision demandée remplace toute l'eau par de la lave : `PROMPT-lava.md`.
  L'ancienne peinture est conservée dans `land-water.png` ; les contours du
  gué ont été réinspectés sur la nouvelle source.
- `apply.py` adapte les UV au canevas 1920 × 1200, trace la rive pour contrôler
  le support des dalles et conserve les collisions du moteur.
- `prepare.ps1` synchronise par `ArenaRuntimeBridge` du Studio et compare
  l'empreinte de gameplay avant/après sauvegarde et rechargement.
- Le shader anime des zones de lave explicitement délimitées et trois lampes.
  Le sol reste fixe ; l'option de réduction des animations arrête les effets.
- La revue GPU contrôle matériaux, support, picking, proportions, cadrage,
  déplacement et garde en 1920 × 1080 et 1200 × 896. Huit captures temporelles
  mesurent lave latérale, lave amont, lampe et sol témoin, puis le gel GPU.

Le champ historique `boat_region` de la revue partagée désigne ici la lampe
des bornes votives ; aucun bateau n'est présent. La revue ne gagne pas une
bataille entière. Les rapports finaux sont consignés dans `WORK_NOTES.md`.

## Vérifications

**Révision lave : PASS**, synchronisation Studio et revue GPU aux deux formats,
20 captures, inspection après mouvement/garde. Rapports :
`artifacts/dev/20260912-140215-gue-serments-prepare-6dd000d5/summary.json` et
`artifacts/dev/20260912-140331-gue-serments-review-34cb0022/summary.json`.
Gameplay et géométrie conservés ; lave animée, sol fixe et mode réduit vérifiés.

Les rapports ci-dessous concernent la version initiale avec eau. Les contrôles
de la révision lave sont consignés dans `WORK_NOTES.md`.

- Import et synchronisation Studio PASS :
  `artifacts/dev/20260912-134824-gue-serments-prepare-8a6f821f/summary.json`.
- Revue GPU PASS, deux formats et 20 captures :
  `artifacts/dev/20260912-135149-gue-serments-review-074a7e6c/summary.json`.
  Captures après déplacement/garde inspectées. Les 109 polygones gardent au
  moins 85,92 unités du canevas natif de marge à la rive tracée. Eau, lampe,
  immobilité du sol et gel des effets validés sur les pixels rendus.
- Catalogue, connexité et rencontres PASS : 3 tests, 15 940 assertions :
  `artifacts/dev/20260912-135347-test-test_unit_test_catabase_route_layouts.gd-6b8c5921/gut-strict-report.json`.
