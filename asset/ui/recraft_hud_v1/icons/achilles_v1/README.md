# Kit d’icônes HUD — Achille V1

Ce dossier contient une première famille vectorielle monochrome pour le HUD d’Achille. Les capacités reprennent les contrats de production de `data/spells/achilles/` : frappe droite, engagement en ligne, balayage avec poussée et garde personnelle.

## Contrat graphique

- grille source commune de `64 × 64` ;
- zone sûre comprise entre `6` et `58` sur chaque axe ;
- trait nominal de `4 px`, terminaisons et jointures arrondies ;
- une seule encre blanche sur fond transparent ;
- formes principales lisibles à `32 px`, états secondaires prévus jusqu’à `16 px` ;
- teinte appliquée au runtime avec `modulate` ou `self_modulate` ;
- aucun texte, filtre, masque, dégradé ni dépendance externe.

Les silhouettes ne dépendent pas de la couleur. La coche, la croix, le cadenas, le cercle barré, l’horloge et les arcs de résolution demeurent donc identifiables en désaturation ou avec une palette d’accessibilité.

## Distinctions sémantiques

| Identifiant | Silhouette dominante |
| --- | --- |
| `achilles_spear_thrust` | lance horizontale et pointe d’impact |
| `achilles_advance` | progression droite sur une rangée de cases |
| `achilles_sweep` | rotation complète autour d’une lance |
| `achilles_guard` | bouclier hoplitique et lance dressée |
| `move` | chemin sur une case isométrique |
| `end_turn` | sablier puis passage à l’étape suivante |
| `action_points` | étincelle d’énergie angulaire |
| `movement_points` | sandale en mouvement |

`icon_manifest_v1.json` constitue le mapping stable entre les identifiants de gameplay et les chemins `res://`. Il est volontairement indépendant des thèmes et scènes actuels afin que cette proposition puisse être évaluée avant intégration.
