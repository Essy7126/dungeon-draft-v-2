# Gizmo affine de grille

`GridAffineGizmo` est un `Control` de dessin pur avec
`MOUSE_FILTER_IGNORE`. Le hit-test est effectué par `ArenaStudioCanvas` via le
routeur unique : le gizmo ne forme donc jamais un mur d’input.

## Poignées

- origine **O** et contour cyan : déplacement du corps ;
- axe **X** cyan et axe **Y** magenta : inclinaison/longueur indépendante ;
- anneau orange : rotation autour du pivot ;
- carré vert : échelle uniforme ;
- poignée/arc violet : ouverture de l’angle de grille ;
- croix jaune : pivot éditeur.

Les rayons d’affichage et de hit-test sont constants à l’écran
(`HANDLE_RADIUS = 9 px`, `HIT_RADIUS = 14 px`). Les positions sont recalculées
à chaque zoom; les tests couvrent 25 %, 50 %, 100 %, 200 % et 300 %.

## Priorité de hit-test

En cas de proximité, l’ordre est : pivot, rotation, angle, échelle, X, Y,
puis corps de grille. La poignée d’angle est placée sur la bissectrice
intérieure afin de rester distincte des deux axes.

## Cycle d’un geste

Au press, le canvas capture l’instantané affine, le pivot et les options. Les
mouvements affichent un ghost pointillé et une mesure live. Au relâchement,
une seule action est enregistrée. Toute annulation réapplique l’instantané
initial bit à bit et efface le ghost.

