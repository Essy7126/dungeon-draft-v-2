# Poignée Angle de la grille

La poignée violette règle l’angle intérieur entre `axis_x` et `axis_y` sans
introduire de rotation ou d’échelle implicite non demandée.

## Modes

- **Symétrique** : conserve les longueurs des deux axes, leur bissectrice
  globale et l’orientation; chaque axe reçoit la moitié du delta angulaire.
- **Conserver X** : `axis_x` reste exactement inchangé et seul `axis_y`
  pivote.
- **Conserver Y** : `axis_y` reste exactement inchangé et seul `axis_x`
  pivote.

Le mode est un état éditeur persisté dans la session, pas une donnée runtime.

## Sécurité numérique

`GridTransformService.set_grid_angle` borne l’ouverture à 10°–170°, refuse
NaN/Inf, axes nuls ou quasi colinéaires et toute inversion d’orientation. Les
longueurs ne peuvent pas devenir nulles. La fonction renvoie un résultat
explicite `{ok, snapshot, angle}`; le document ne change pas si `ok` est faux.

## Interaction

Le delta est calculé depuis la direction initiale du pointeur autour de
l’origine. En mode symétrique, la sensibilité compense la demi-rotation des
axes. L’inspecteur affiche en direct l’ouverture, le mode, les longueurs, les
angles absolus, la rotation globale, le pivot, le déterminant et
l’inversibilité.

Cent cycles ouverture 150° / restauration de l’angle initial sont testés sans
dérive d’origine, NaN/Inf ni changement d’orientation.

