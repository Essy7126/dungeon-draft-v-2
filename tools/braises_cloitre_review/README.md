# Les braises du cloître

Un vestige grec creusé dans les abysses : piliers érodés sous une voûte naturelle,
galerie obscure à gauche et gouffre profond avec escalier ruiné à droite.
Basalte bleu-noir, quelques ossements, braseros modestes et braises localisées.
Le sol rocheux continu donne au lieu une composition distincte du Gué.

La map habille la destination existante de l'étape **IX**, `route_edce0087c741`,
**d09_0** pour la graine 2401. Elle conserve ses **138 dalles**, ses obstacles,
sa rencontre et son identité sauvegardée. Le parcours n'est pas réordonné :
c'est la prochaine map produite, pas une nouvelle liaison directe après le Gué.

## Essayer

```powershell
./tools/braises_cloitre_review/open.ps1
./tools/braises_cloitre_review/verify.ps1
./dev.ps1 test test/unit/test_catabase_route_layouts.gd
```

L'Explorateur de run ouvre la destination réelle avec des données utilisateur
isolées et les victoires précédentes simulées. **F8** ferme l'essai.

## Source et pipeline

- `prepare.py` conserve la géométrie et le baseline. `prepare_interior_guide.py`
  construit le plan d'occupation intérieur avant les nouvelles générations.
- Original final **1586 × 992**, créé par **image_gen intégré** :
  `assets/catabase/combat/braises_cloitre_v1/land.png`. La roche et la palette
  du Pied du puits validé et le plan d'occupation guident cette composition.
  Prompts exacts : `PROMPT-v4-abyss.md` puis `PROMPT-v5-clearance.md`.
- La v1 trop proche du Gué est écartée et conservée dans `land-v1-rejected.png`.
  `interior-v2.png` et `interior-v3-rejected.png` conservent la piste écartée
  de bâtiment rouge. `abyss-v4.png` précède le dégagement du bord du gouffre.
- `apply.py` conserve les pixels, adapte les UV au canevas 1920 × 1200 et trace
  les limites du sol à la main. Ce contour vérifie le support, sans définir
  de collisions ; le champ technique historique est nommé `shorelines`.
- `prepare.ps1` synchronise via `ArenaRuntimeBridge` du Studio ; l'empreinte
  de gameplay est comparée au baseline avant/après sauvegarde et rechargement.
- Le shader fait varier les deux braseros, les braises au fond de la galerie
  et la fissure incandescente dans les régions calibrées. Le mode réduit fige
  les effets. Le sol, les piliers et le gouffre restent immobiles.
- La revue GPU utilise les oracles communs : matériaux, support, géométrie,
  picking, proportions, cadrage, déplacement et garde, puis huit images
  temporelles par format en 1920 × 1080 et 1200 × 896.

Le champ historique `boat_region` du contrôleur de revue partagé désigne le
brasero de la galerie. Les mesures comparent la fissure, les braises au fond,
le brasero gauche et un sol témoin. Le contrôle ne gagne pas une
bataille entière. Rapports et inspection visuelle : `WORK_NOTES.md`.

## Validation de la composition abyssale

- Import et synchronisation Studio PASS :
  `artifacts/dev/20260912-142933-braises-cloitre-prepare-f4b31e79/summary.json`.
  Géométrie identique octet pour octet ; gameplay identique après rechargement.
- Revue GPU PASS, 1920 × 1080 et 1200 × 896, 20 captures :
  `artifacts/dev/20260912-143039-braises-cloitre-review-d53ef3a2/summary.json`.
  Captures après mouvement/garde inspectées dans les deux formats. Les 138
  polygones sont soutenus ; distance minimale aux limites peintes : 22,85
  unités du canevas natif. Foyers, sol fixe et mode réduit vérifiés.
- Catalogue et rencontres PASS : 3 tests, 15 940 assertions :
  `artifacts/dev/20260912-143156-test-test_unit_test_catabase_route_layouts.gd-231111c8/gut-strict-report.json`.
