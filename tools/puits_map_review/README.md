# Passage du puits — première map

**Le pied du puits** est le nom artistique de cette première terrasse souterraine.
Elle habille la destination existante **La sente des oliviers**, étape II,
`route_76ac69bb7c8d`, reliée au puits du Seuil. Le nom du catalogue et les identités
de sauvegarde restent conservés. Aucune suite de maps ni liaison nouvelle n'est créée.

La roche bleu-noir, le bronze et les contours peints reprennent les originaux
Autel des serments / Étal du passeur. Deux coulées latérales, une croûte de magma,
quelques ossements et le treuil du puits annoncent les profondeurs. Le décor est
modeste : une terrasse de passage maçonnée avec un accès vers la suite.

## Essayer

```powershell
./tools/puits_map_review/open.ps1
./tools/puits_map_review/verify.ps1
./dev.ps1 test test/unit/test_catabase_route_layouts.gd
```

L'essai ouvre d02_0, graine 2401, avec les adversaires du parcours et des données
utilisateur isolées. F8 ferme cet essai. Les victoires précédentes sont simulées
par le laboratoire. L'explorateur de run retrouve aussi la destination sous son
nom historique. Le lieu utilise le combat tactique commun ; il n'ajoute pas une
exploration libre ou une animation de descente dans le puits.

## Pipeline reprise du Léthé

1. `prepare.py` conserve le baseline et construit le guide à partir des 112
   dalles canoniques. Le plan géométrique fait autorité sur les pixels.
2. Peinture via **image_gen intégré**, guidée par ce plan et les deux références
   originales. La v1 conservée avait inventé une faille intérieure : la v2 remplit
   cette zone afin de supporter toutes les dalles. Prompts exacts dans
   `assets/catabase/combat/puits_descent_v1/PROMPT.md` et `PROMPT-v2.md`.
3. `apply.py` conserve l'original de 1586 × 992 pixels, sans retouche ni découpe,
   et l'ajuste par UV au canevas 1920 × 1200. Le tracé manuel de la rive sert au
   contrôle du support, jamais aux collisions. Une autre image exige un retracé.
4. `prepare.ps1` importe et synchronise via les services Studio. Il compare
   l'empreinte de gameplay au baseline avant et après sauvegarde/rechargement.
5. `verify.ps1` reprend les oracles de combat : support, matériaux, cadrage,
   picking, mouvement et garde. Les échantillons GPU contrôlent lave, lanterne,
   sol immobile et gel en mouvement réduit. Le champ historique `boat_region`
   du contrôleur de revue partagé désigne ici la lanterne du puits, pas une barque.

Les effets restent dans des régions explicitement dessinées : la lave ondule
lentement et pulse, les quatre flammes/vitrages varient en luminance. Les dalles,
ossements et contours de roche ne sont pas déformés. Le contrôleur suit le mode
de réduction des animations du jeu.

## Preuves du 12 septembre 2026

- Import et sauvegarde Studio PASS :
  `artifacts/dev/20260912-124709-puits-descent-prepare-629405f5/summary.json`.
- Revue GPU PASS en 1920 × 1080 et 1200 × 896, 20 captures :
  `artifacts/dev/20260912-124818-puits-descent-review-477db2d9/summary.json`.
  Les captures initiale 1080p et après mouvement/garde au format compact ont
  été inspectées : dalles soutenues, personnages lisibles, pas de recouvrement HUD.
  Marge minimale entre les dalles et la rive tracée : 38,66 pixels natifs.
- Empreinte de gameplay identique après rechargement, géométrie originale
  inchangée octet pour octet. Source, guide et empreintes dans `manifest.json`.
- Catalogue, connexité et résolution des destinations PASS : 3 tests,
  15 940 assertions, rapport
  `artifacts/dev/20260912-124956-test-test_unit_test_catabase_route_layouts.gd-43593faa/gut-strict-report.json`.

Le contrôle joue un déplacement et une garde ; il ne gagne pas une bataille
entière. Les proportions du héros restent celles du profil de combat commun.
Le premier essai sous bac à sable avait échoué sur des imports externes et des
droits locaux ; l'import suivant avec le compte local passe sans erreur moteur.
