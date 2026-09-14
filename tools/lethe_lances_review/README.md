# Les lances oubliées — étape III du Léthé

La destination `route_10ce1ff88330` utilise une berge peinte dédiée, avec la barque
brune à trois bancs, proue relevée, corde et lanterne. La niche aux lances distingue
cet amarrage du premier quai. Références : Sanctuaire Émeraude et Étal du passeur.

Le plan remplace les deux usages du fond de caverne et couvre le canevas entier.
La réserve et la rive tracée sur l'image vérifient le support des 185 dalles.
Obstacles, spawns, rencontres et collisions restent issus des données du jeu.
Les vides gardent leurs parois et leur comportement, avec fond transparent.
L'ancien bandeau brun est désactivé. Eau et lumières s'animent localement, avec
sol et coque protégés des déplacements UV, et gel en mouvement réduit.
Le cadrage local `(-120,-30)` est borné au débord disponible de l'image.

## Reprendre

```powershell
./tools/lethe_lances_review/open.ps1
./tools/lethe_lances_review/verify.ps1
./dev.ps1 test test/unit/test_catabase_route_layouts.gd
```

`open.ps1` ouvre la vraie destination d03_3, graine 2401, avec ses monstres de
parcours et des données utilisateur isolées. Les victoires antérieures sont
simulées par le laboratoire. F8 ferme cet essai.

`verify.ps1` utilise la rencontre persistée et les oracles partagés : géométrie,
support, matériaux, cadrage, picking, déplacement et garde aux deux tailles,
avec comparaison des proportions. Le contrôle local ajoute le cadrage complet
de la barque face au HUD, huit images par taille, eau/torche/lanterne animées,
sol stable et réduction des animations. Inspecter aussi les captures.

`prepare.py` conserve un baseline local dans `artifacts/dev/lethe-lances/before`
et génère le guide depuis les cellules. `apply.py` installe uniquement le plan
visuel, avec garde sur l'image retenue : une autre peinture demande de recalibrer
rive et régions de shader/revue. `prepare.ps1` importe puis sauvegarde avec les
services Studio et comparaison du gameplay avant/après rechargement.
Le baseline est nécessaire à cette préparation, pas à l'exécution du jeu.

Source originale 1586×992, échelle UV vers 1920×1200, sans découpe ni retouche
déterministe. Prompt, guide, image, shaders et manifeste :
`assets/catabase/combat/lethe_lances_v1/`.

## Preuves du 12 septembre 2026

- Import/préparation PASS : `artifacts/dev/20260912-110335-lethe-lances-prepare-67071bfe/summary.json`.
- GPU PASS, 2 formats et 20 captures : `artifacts/dev/20260912-110523-lethe-lances-review-96c907f9/summary.json`.
  Captures après déplacement/garde inspectées : barque entière, aucun recouvrement
  HUD et aucune dalle hors berge. Marge dalle/rive minimale : 53,33 px natifs.
- Catalogue/connexité/résolution/formations PASS, 3 tests et 15 940 assertions :
  `artifacts/dev/20260912-110740-test-test_unit_test_catabase_route_layouts.gd-4b1ede52/gut-strict-report.json`.
- Destination réelle via explorateur PASS :
  `artifacts/dev/20260912-111012-lethe-lances-expedition-2e7225cc/summary.json`.

Le contrôle GPU exécute un déplacement et une garde, pas une bataille gagnée
entièrement. La barque est rétablie dans le décor ; cette livraison n'ajoute pas
de navigation libre en bateau ni de liaison de parcours. Graphe et sauvegardes
conservent leur fonctionnement actuel.
