class_name HubTechnicalMarker
extends Marker2D

## Metadonnee de placement/debug. La cellule sert a initialiser la position
## monde du marqueur, mais n'impose plus le chemin visuel du joueur.

@export var cell := Vector2i.ZERO
@export var debug_color := Color(1.0, 0.82, 0.22, 1.0)
