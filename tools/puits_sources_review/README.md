# La garde des sources — seconde map du passage du puits

Cette destination de l'étape III prolonge **Le pied du puits** (nom de catalogue
de la première salle : La sente des oliviers). La liaison de production existe
déjà ; pour la graine 2401, elle relie `d02_0` à `d03_1`. La salle conserve son
nom, ses adversaires, ses obstacles et ses 185 dalles canoniques.

L'arcade de sortie du premier lieu est reprise côté arrivée. On rejoint un ancien
poste de garde aménagé près de deux sources de magma : trois lances, un bouclier
de bronze, quelques ossements et un passage vers la suite. La lave devient plus
présente sans changer la palette bleu-gris, les contours peints ni les volumes
simples de la première map. Le puits est désormais derrière nous.

## Jouer et vérifier

```powershell
./tools/puits_sources_review/open.ps1
./tools/puits_sources_review/verify.ps1
./dev.ps1 test test/unit/test_catabase_route_layouts.gd
```

L'essai ouvre la destination réelle dans une session avec sauvegarde isolée,
grâce au laboratoire de l'explorateur de run. **F8** ferme l'essai. Les victoires
précédentes sont simulées pour atteindre la salle. Le lieu utilise le combat
tactique commun ; les arcades ne créent pas une nouvelle navigation libre.

## Source et pipeline

- Guide géométrique produit par `prepare.py` avant l'image depuis
  `data/rooms/catabase_routes/route_9c104c2158d3/geometry_manifest.json`.
- Peinture originale **1586 × 992**, générée avec **image_gen intégré**. Le guide,
  le Pied du puits validé et l'Étal du passeur original ont été joints. Prompt
  exact : `assets/catabase/combat/puits_sources_v1/PROMPT.md`.
- `apply.py` conserve les pixels originaux dans `land.png`, avec adaptation UV
  au canevas 1920 × 1200. La rive est tracée manuellement sur cette version pour
  vérifier le support des dalles. Elle ne définit aucune collision.
- `prepare.ps1` synchronise la ressource par `ArenaRuntimeBridge` du Studio,
  avec empreinte de gameplay identique avant/après sauvegarde et rechargement.
- Le shader anime les deux sources, les coulées périphériques et quatre lumières
  peintes, en protégeant le sol. Il suit l'option de réduction des animations.
- `verify.ps1` reprend les contrôles communs de matériaux, géométrie, support,
  picking, cadrage et proportions, puis un déplacement et une garde. Huit images
  par résolution mesurent séparément les deux sources, une torche et un témoin
  de sol fixe. La réduction des animations est vérifiée sur les pixels rendus.

Le champ historique `boat_region` du contrôleur de revue partagé désigne ici
la torche d'arrivée ; aucun bateau n'est présent. Le contrôle n'est pas une
bataille entièrement gagnée. La suite du trajet et le graphe restent inchangés.

## Vérifications

- Import et synchronisation Studio PASS :
  `artifacts/dev/20260912-130225-puits-sources-prepare-7deccd2b/summary.json`.
- Revue GPU finale PASS, **1920 × 1080** et **1200 × 896**, 20 captures :
  `artifacts/dev/20260912-130328-puits-sources-review-80d44c16/summary.json`.
  Les captures après déplacement et garde des deux formats ont été inspectées :
  fond entier, plus de découpe blanche ni liseré brun, pas de dalle sous le HUD.
  Les 185 polygones sont soutenus avec au moins **36,65 px natifs** de marge à
  la rive tracée. Deux sources animées, torche, sol fixe et gel GPU vérifiés.
- Empreinte de gameplay identique après rechargement ; géométrie originale
  inchangée octet pour octet. Empreintes et source dans `manifest.json`.
- Catalogue, connexité et résolution du parcours PASS : **3 tests, 15 940
  assertions**, rapport
  `artifacts/dev/20260912-130436-test-test_unit_test_catabase_route_layouts.gd-78739ff5/gut-strict-report.json`.

La première revue automatique passait mais ses captures ont révélé la découpe
héritée de l'ancien décor. Cette version a été corrigée puis contrôlée de nouveau.
La fiche `WORK_NOTES.md` conserve les exécutions intermédiaires et leur verdict.
