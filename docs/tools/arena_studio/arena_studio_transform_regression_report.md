# Rapport de régression — historique et transformations 1.1

## Environnement

- Projet : Godot demandé 4.7, exécuté avec Godot 4.7.1 stable officiel.
- Référence Git : `1aadd1bd1dec5d1cf108740c0f57e80047d22539` sur `main`.
- Ressources de production forêt, volcan et espace : non modifiées.

## Résultats automatisés

- Arena Studio 1.1 : 16/16, 1 375 assertions.
- Arena Studio v1 : 15/15, 1 287 assertions.
- Encounter Studio v1 : 15/15, 166 assertions.
- Suite globale finale : 647/657, 48 752/48 805 assertions. Le baseline était
  643/653 avec les mêmes 10 échecs ; les quatre tests 1.1 ajoutés passent et
  aucun nouvel échec global n'apparaît.
- Intégration peinte ciblée : 48/49 tests. Le seul échec est identique au
  baseline : trois images historiques absentes sous
  `res://artifacts/maps/pool_map/`. Les 48 autres tests, dont projection,
  clics, occlusion et ressources peintes, passent.

Les scénarios 1.1 couvrent working copies isolées, historique et branche Redo,
dirty fingerprint, geste de 100 mouvements en une action, annulation exacte,
offset/scale/pan/zoom, clavier groupé, pivot annulable, affine, snap, ancres,
auto-fit, sauvegarde de fixture non destructive et parité forêt/volcan/espace.

## Parité runtime

Pour chaque cellule des trois maps, la position native attendue et la position
de `PaintedMapVisualData` concordent à 0,0001 px ; l'inversion retrouve la même
cellule. Les centres affichés appliquent `image_offset/image_scale` dans le
Studio comme dans `PaintedGridView`. Les champs foreground et occlusion sont
conservés par import et reconstruction runtime.

Le smoke de scène réel passe avec `ok=true` sur
`res://data/rooms/maps/painted_battle.tscn` : grille 14×14, Pathfinder prêt,
`IsoGridView`, `YSortedWorld`, configuration `full_run` et map
`room_01_forest`. Il emprunte le lanceur direct et une fixture, pas la ressource
de production.

## Alertes connues

Les sorties headless signalent des ObjectDB/resources encore référencés. Des
leaks similaires existent au baseline, notamment dans Encounter. Aucun orphan
supplémentaire n'est produit par le test de conversion ajouté.

Le smoke runtime signale 92 objets et 34 ressources encore référencés ainsi
qu'un RID de chaque type Environment/Material/Shader/Mesh/Texture. La suite
Encounter ciblée signale 52 objets et 35 ressources, comme avant la mission ;
ces fermetures forcées headless restent une limite connue du projet.

## Validation visuelle

Soixante captures ont été produites : 20 états à chacune des résolutions
1280×720, 1920×1080 et 2560×1440. Le lot couvre barre Undo/Redo, Historique,
calques, sélection, cinq poignées, Shift, Ctrl/snap, ancres et résidus,
comparaison, dernière opération, restauration, validation et les trois maps.
Les 60 dimensions ont été vérifiées automatiquement. L'inspection réelle des
états 1280 et des trois maps aux formats supérieurs a conduit à corriger la
barre responsive, le wrapping, le chevauchement des libellés, l'amplitude des
gestes de démonstration et la validation du chemin `uid://` d'Espace.
