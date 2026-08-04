class_name StaticForestWall
extends Node2D

## Obstacle de relief permanent du test : ni PV, ni duree, ni ciblage. Sa base
## remplace visuellement la dalle de la cellule au lieu de flotter au-dessus.

var logical_cell := Vector2i(-1, -1)


func configure(cell: Vector2i) -> void:
	logical_cell = cell
	name = "StaticWall_%d_%d" % [cell.x, cell.y]


func get_cell() -> Vector2i:
	return logical_cell


func blocks_movement() -> bool:
	return true


func blocks_line_of_sight() -> bool:
	return true


func blocks_projectiles() -> bool:
	return true


func is_targetable() -> bool:
	return false

