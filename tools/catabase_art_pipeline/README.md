# Catabase : assets peints Higgsfield

Le lot pilote contient seize icônes de familles de sorts, le camp des compagnons
et la bibliothèque engloutie réemployée depuis la référence approuvée. Les deux
nouvelles générations sont consignées dans `generation_requests.json` ; leurs
sources, exports et empreintes sont dans
`art/source/catabase/painted/pilot_exports.json`. Le manifeste de production du
même dossier distingue les exports existants des lots restant à produire.

## Traitement reproductible

Exécuter `build_pilot.py` dans le sandbox Higgsfield, avec Pillow, NumPy et SciPy
(`python3 -m pip install scipy==1.17.1` si nécessaire). Le script vérifie
l'empreinte de la planche avant de réutiliser sa segmentation revue.

La planche n'est pas une grille parfaitement régulière : la dernière ligne
déborde des cellules nominales. L'extraction attribue les composantes peintes
aux seize symboles, conserve leurs éclats détachés, sépare le reflet commun entre
Contretemps et Marche, puis centre chaque symbole sur un export 256×256. Les
fonds bleu-noir sont conservés. Le camp et la bibliothèque sont redimensionnés
uniformément puis recadrés au centre en 1920×1200 ; aucune déformation des axes.

Avant la commande de production, réserver une archive avec `media_upload`.
Dans la même commande sandbox, exécuter le script puis envoyer l'archive
`/home/user/catabase_pilot/catabase_pilot.zip` avec l'URL PUT et le Content-Type
renvoyés par le plugin. Confirmer le média après HTTP 200. L'archive contient
uniquement les images et leurs métadonnées ; le script reste dans ce dépôt.

Après récupération, vérifier chaque chemin d'archive dans le workspace et les
empreintes des dix-huit exports avant l'import Godot. Les répertoires de sources
et de revue portent un `.gdignore`. La planche de revue inclut les tailles réelles
48 et 64 pixels dans `artifacts/catabase_painted_art/icon_review.png`.

## Branchement

- `CatabasePaintedIconCatalog` : famille commune, variante spécifique prioritaire
  si disponible, correspondances explicites pour les 46 sorts et 55 nœuds.
- `ExpeditionBuildCatalog` : copies de présentation, sans modifier les sorts
  sources. Le HUD privilégie les icônes portées par ces copies Catabase.
- `CatabaseHaltArtCatalog` : 17 clés de destinations stables, indépendantes de
  l'inversion des branches par seed ; cibles et libellés mesurés par peinture.
- `CatabaseHubCanvas` : cadrage uniforme, cibles et libellés distincts, sélection
  du service puis confirmation de la transaction dans le panneau habituel.

Les PNG absents conservent le rendu existant. Tempête, les éléments, les serments,
les équipements, les emblèmes, les nouveaux décors d'arène, la carte et les VFX
restent des postes de production distincts ; leur présence dans un catalogue ne
signifie pas qu'ils sont générés.

## Vérification moteur

Importer le projet puis lancer les suites GUT `test_catabase_painted_icons.gd`
et `test_catabase_halt_art.gd`. Le probe
`res://tests/expedition/CatabasePaintedArtProbe.tscn` vérifie l'ouverture de combat,
le HUD réel, les deux haltes et leurs transactions, puis capture l'arbre. Exécuter
avec un pilote graphique réel et `-- resolution=1280x720`, puis `1920x1080`.
Les victoires intermédiaires sont des fixtures explicites, sans prétention de
validation d'une run complète jouée.
