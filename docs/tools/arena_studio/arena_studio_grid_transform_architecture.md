# Architecture de transformation de grille

## Modèle canonique

La projection reste affine : `P(x,y) = O + xU + yV`. `O` est `grid_origin`,
`U` est `axis_x`, `V` est `axis_y`. Les cellules, terrains, obstacles et spawns
gardent leurs coordonnées logiques. `GridTransformSnapshot` fournit copie,
comparaison tolérante, sérialisation et application à la working copy.

`GridTransformService` est l'autorité mathématique commune : translation,
rotation et échelle autour d'un pivot, axes indépendants, symétrie, snap,
bornes, conversion inverse, validation relative du déterminant et ajustement
affine aux moindres carrés.

## Espaces de coordonnées

1. Pixel natif : repère où O/U/V et les ancres sont stockés.
2. Image affichée : `image_offset + pixel_natif * image_scale`.
3. Viewport : `pan + image_affichée * zoom`.
4. Coordonnée logique : inversion de l'affine O/U/V.

Le Studio et `PaintedGridView` utilisent ce même enchaînement. Les tailles de
poignées et traits sont exprimées en pixels écran, donc restent manipulables au
zoom. Le background, le foreground et l'occlusion sont dessinés avec leur
placement d'image, mais une transformation de grille ne les déplace pas.

## Gizmo

Le corps translate O. Les poignées droite/gauche modifient respectivement U et
V. La poignée circulaire fait tourner O/U/V autour du pivot. La poignée de coin
applique une échelle uniforme. Le pivot est central ou personnalisé et reste un
état d'éditeur. Des verrous indépendants bloquent translation, rotation,
échelle, axe droit et axe gauche. Les options préservent longueur, angle ou
symétrie lorsque demandé.

Toutes les valeurs sont recalculées depuis le snapshot de l'appui : aucun delta
n'est accumulé d'un événement au suivant. Une transformation non finie,
quasi nulle, quasi colinéaire, non inversible ou inversant involontairement
l'orientation est refusée avant prévisualisation.
