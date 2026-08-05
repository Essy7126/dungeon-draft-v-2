# ArenaInputRouter

`ArenaInputRouter` est l’unique porte d’entrée des interactions arène. Le
canvas intégré appelle `route_canvas_event`; le Lab autonome appelle
`route_standalone_event`. Les deux chemins délèguent ensuite au contrôleur qui
possède réellement l’outil.

## Modes

`IDLE`, `PAN`, `PAINT_CELL`, `PAINT_TERRAIN`, `PLACE_WALL`, `PLACE_SPAWN`,
`TRANSFORM_GRID` et `DRAG_ANCHOR` décrivent le consommateur actif. Un seul mode
de geste peut être actif à la fois.

## Garanties

- déduplication par identifiant d’instance de l’`InputEvent` ;
- compteurs processed/consumed utilisables par les tests ;
- identité du consommateur mémorisée pour le diagnostic ;
- `begin_gesture`, `finish_gesture` et `cancel_gesture` explicites ;
- retour obligatoire à `IDLE` après fin ou annulation ;
- changement d’outil synchronisé sans conserver de drag résiduel.

Le routeur ne modifie pas le document. Il garantit seulement qu’un événement
n’alimente jamais simultanément peinture, gizmo, ancres et Lab.

