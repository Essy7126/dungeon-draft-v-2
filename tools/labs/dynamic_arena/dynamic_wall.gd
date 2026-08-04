class_name DynamicWall
extends Node2D

## Prototype visuel sans logique de grille propre.
## DynamicArenaLab enregistre son blocage dans l'unique GridData du lab.

var cell := Vector2i(-1, -1)


func setup(target_cell: Vector2i) -> void:
	cell = target_cell
