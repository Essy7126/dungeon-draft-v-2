# La Forge des Racines — seconde halte peinte

## Intention

`bronze_forge_v1` éprouve la réutilisation de la scène et des services communs sur
un lieu sec. Le foyer et les lanternes remplacent l'eau comme matière vivante.
L'entrée, le commerce, le récit et la sortie entourent une enclume centrale basse.
La référence artistique reste l'original `hall_v1/hall.png`.

## Fabrication

Le plan normalisé et son diagramme ont été enregistrés avant la génération dans
`art/source/halts/bronze_forge_v1/spatial_plan.json` et `spatial_plan.png`.
Le prompt versionné a été donné à l'outil natif `image_gen` avec la Halle comme
référence artistique et le plan comme référence de composition. L'image générée
est conservée sans modification à `asset/map/painted/halts/bronze_forge_v1/forge.png`.

Définition réelle : **1 672 × 941 pixels**. SHA-256 :
`3c7ff21be9eabcc38bb24ab3f0fc4be1ce82e8c3b3a6c3eb8c795966f325bcbf`.
Les requêtes et l'origine du fichier sont dans `request.json` et `provenance.json`.

La génération respecte la circulation générale et la position relative des
services. La stèle demandée a pris la forme d'un petit comptoir d'archives ; ce
résultat a été accepté car sa fonction reste lisible et son approche est dégagée.
Les contours finaux sont mesurés sur cette image, dans `calibrate.py`, puis
enregistrés dans `data/halts/bronze_forge_v1.json`. Aucun contour du sanctuaire
n'est repris. Le script de calibration refuse d'écraser le manifeste existant
sans option explicite ; les modifications suivantes passent par le Studio.

## Choix de contenu

- Boucle de navigation continue et obstacle correspondant au socle de l'enclume.
- Trois destinations typées : `merchant`, `dialogue`, `exit`, avec un point
  d'approche distinct du centre visuel de l'objet.
- Neuf foyers/lanternes localisés ; les lanternes fermées ne produisent pas de
  fumée. Deux sources sonores de feu et des pas sur pierre utilisent le runtime.
- Aucune eau, cascade, caustique ou ondulation de mousse statique.
- Trois découpes de profondeur issues de la peinture : enclume et deux piliers.
  Le bord du socle de l'enclume reste interdit aux pieds ; sa silhouette masque
  le personnage lorsqu'il passe derrière.
- Les points interdits incluent l'enclume, le foyer, le comptoir, un mur et le
  pilier d'entrée. Un échantillon de dalle sèche contrôle la stabilité.

## Validation

La préparation Python (`halt_workshop.py prepare res://data/halts/bronze_forge_v1.json`)
a réussi avec le Python fourni par l'application et Pillow : source, dimensions,
empreinte et polygones acceptés ; masque technique et `build.json` produits.
`calibration_review.png` superpose les contours et les ancrages à l'image et a été
inspecté.

La validation graphique Godot finale a réussi : **283 contrôles, 42 captures,
5 836 échantillons de déplacement, aucun échantillon dangereux**, aucune erreur
moteur ni fuite signalée. Elle couvre la navigation, les matières du lieu sec,
les découpes de profondeur, le son et les interactions. Les résultats complets
sont conservés dans
`artifacts/dev/20260910-142839-halt-verify-59a2ae53/verification.json` et son
`summary.json`. La source et les captures finales en 1080p ont été inspectées
visuellement pendant la mission d'intégration.

Cette preuve porte sur la Forge dans le vérificateur graphique isolé. Le scénario
séparé `verify_production.ps1` contrôle le raccord au vrai singleton GameManager,
à la sauvegarde et à l’interface persistante. Le contrôle final de production a
réussi : **46 contrôles et 8 captures**, dont le HUD à 720p et 1080p, dans
`artifacts/dev/20260910-143012-halt-production-merchant-297ca532/summary.json`.
