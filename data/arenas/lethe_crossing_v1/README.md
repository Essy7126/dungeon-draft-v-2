# Le Gué du Léthé

Carte IV Catabase : deux cours décalées, reliées par un passage de cinq cellules entièrement libres. Le renderer reste `res://battle/painted/registered_terrain/RegisteredTerrainBattle.tscn` et utilise les vraies dalles `stone` en mode HYBRID / ALL_DEFINED.

- Canevas : 1920 × 1200 ; grille : 18 × 19.
- Origine : (1000, 125) ; axes : (51.6, 25.8) et (-51.6, 25.8).
- 114 cellules FLOOR ; 228 VOID, dont six cellules annotées dans trois fosses.
- Huit obstacles tactiques ; 106 cellules marchables connectées.
- Passage libre : u=7..11, v=8..11 ; trajet de contrôle entre les camps : 21 cellules.
- Quatre positions de départ par camp, dont quatre cases ennemies pour la rencontre courante de trois unités.
- Aucune scène cosmétique périphérique ; détails procéduraux désactivés ; joints intérieurs neutres.

## Source et régénération

La géométrie est définie dans [generate_lethe_crossing.py](../../../tools/registered_terrain_authoring/generate_lethe_crossing.py), avec Python 3 et sa seule bibliothèque standard. Depuis la racine du projet :

```powershell
python tools/registered_terrain_authoring/generate_lethe_crossing.py --validate-only
python tools/registered_terrain_authoring/generate_lethe_crossing.py
```

La première commande calcule les contrôles sans écrire. La seconde régénère ce package : arène canonique, manifeste, présentation, coordonnées de terrain et guides PNG/SVG. Les paramètres artistiques déjà présents dans le plan sont conservés ; les coordonnées de terre et de rives restent commandées par le générateur. Une copie de campagne doit ensuite être synchronisée et sauvegardée séparément par `ArenaRuntimeBridge`, sans réutiliser un ancien layout.

Le générateur ne modifie ni la run, ni la rencontre, ni les autres cartes. La rencontre référencée est `res://data/encounters/catabase_room_04_encounter.tres`.

## Contrat de peinture et contrôles

Réserve calme native : x=240..1660, y=180..1030. Le dallage occupe x=535.6..1412.8, y=228.2..924.8. Son bandeau de largeur 0.42 cellule occupe x=492.256..1456.144, y=206.528..946.472.

Le [rapport de génération](authoring_validation.json) mesure 193.803 px minimum entre les dalles et les rives, et 152.808 px entre le bandeau et les rives. La réserve tactique `allowed_floor_polygon` conserve son contour initial et une marge de 125.116 px autour des dalles. La terre visible est désormais une péninsule plus large, qui inclut tout le haut du canevas pour préserver les ruines ; les rives dessinées sont limitées aux côtés bas. Ces distances proviennent des polygones complets et des distances entre segments, pas seulement des centres. Le rapport contrôle aussi la connectivité, les fosses, les positions de départ et le passage libre.

Pour régénérer uniquement le plan géométrique, les rapports et les guides sans réécrire les ressources de combat et de présentation, utiliser `python tools/registered_terrain_authoring/generate_lethe_crossing.py --terrain-only`. Les palettes et les paramètres artistiques du plan restent conservés.

Ces mesures sont des contrôles de données en Python. Elles ne remplacent ni la validation des sprites réellement assemblés, ni les actions de combat, ni la revue GPU du paysage. Les images de référence sont des guides géométriques, pas le décor final : le background de calibration est caché par la composition de production.
