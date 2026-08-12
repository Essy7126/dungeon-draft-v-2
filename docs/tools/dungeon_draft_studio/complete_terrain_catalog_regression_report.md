# Régression — catalogue complet des terrains

Statut : **WORKTREE_CANDIDATE** — baseline locale `8bd9d455bced1c68acf98843e6f6d4844d4174e8`.

## Observé et corrigé

- la lave était classée `WALL` et non marchable malgré `CellType.LAVA` ;
- le brush appliquait des filtres de thème/profil qui écartaient Eau et Glace ;
- Poison, Vapeur et Eau électrifiée n’étaient pas des terrains permanents ;
- le vortex était auteur seulement et bloqué par validation/Tester ;
- les domaines dirty n’exposaient pas tous le contrat complet de transition.

## Validation dédiée

`test_complete_terrain_catalog_and_status_effects.gd` : **64/64**, 317
assertions. La suite couvre catalogue, palette, brush, snapshot, sauvegarde,
statuts, LoS, choc, déduplication, pathfinding, IA, vortex, rendu, handlers et
parité Studio/user copy/preview/runtime.

L’inventaire des neuf assets rapporte un alignement valide, un delta de centre
maximal de 0 px et des bounds normalisés 256×128.

## Validations finales

- scan/import Godot 4.7.1 : code 0 ;
- catalogue complet : 64/64, 317 assertions ;
- régressions rendu/alignement/catalogue/topologie/test direct : 68/68,
  1 502 assertions ;
- Run Content Isolation : 14/14, 1 504 assertions ;
- Skill Tree protégé : 84/84, 5 264 assertions ;
- suite globale : 1 061/1 081, 56 288 assertions ; les 20 échecs restants
  sont hors catalogue terrain (captures historiques absentes, anciennes
  attentes run/forêt, progression divergente et tests UI instables) ;
- test direct réel : un renderer de sol, 164/164 dalles, aucun doublon,
  fingerprints et topologie identiques, configuration et caméra consommées ;
- smokes painted, modular et Encounter : PASS ;
- captures : 60/60, soit 15 cas dans quatre résolutions.

Deux échecs historiques isolés subsistent notamment dans le lot
run/trio/GameManager/hub : la run principale référence déjà l’arène gelée
`arena_principal.tres` au lieu de l’ancienne fixture attendue et
`eagle_eye.tres` possède déjà deux modificateurs au rang 2. Ils ne proviennent
pas du chantier terrain. Les scripts terrain/Arena affectés par le patch ont été
rejoués isolément après le global et passent tous.

## Bundle de production gelé

`data/runs/first_run.tres` référence directement, à l’index de salle 0,
`res://data/arenas/produced/room_01_forest/arena_principal.tres`. Le bundle est
donc référencé et classé `OWNED_DIRTY` par l’inspecteur (payload étranger au
manifeste), et non `UNREFERENCED_INCOMPLETE_PRODUCTION_BUNDLE`. Aucun de ses
quatre fichiers n’a été modifié ; les SHA-256 finaux sont identiques au prévol.
Le test direct charge exclusivement la copie temporaire `user://` de la working
copy.

## Avertissements hors patch

Le scan conserve l’UID invalide déjà présent dans le bundle gelé et la collision
de classe `ItemDefinition` sous `output/validation-feedback-candidate`. Les
fermetures headless signalent aussi les fuites RID/ObjectDB historiques. Aucun de
ces avertissements ne change le résultat fonctionnel du candidat.

Ce document ne transforme pas le candidat local en état `CURRENT`.
