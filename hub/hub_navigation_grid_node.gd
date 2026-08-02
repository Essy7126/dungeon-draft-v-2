class_name HubNavigationGridNode
extends Node

## Adaptateur de scene : les marqueurs restent des enfants Node, tandis que le
## modele HubNavigationGrid conserve une API pure incluant get_path().

@export var grid_size := Vector2i(20, 20)
@export var tile_size := Vector2(128.0, 64.0)
@export var grid_origin := Vector2(1024.0, 640.0)
@export var minimum_floor_sum := 3
@export var maximum_floor_sum := 33
@export var maximum_floor_axis_delta := 13
@export var blocked_cells: Array[Vector2i] = []

var model := HubNavigationGrid.new()


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	model.grid_size = grid_size
	model.tile_size = tile_size
	model.grid_origin = grid_origin
	model.minimum_floor_sum = minimum_floor_sum
	model.maximum_floor_sum = maximum_floor_sum
	model.maximum_floor_axis_delta = maximum_floor_axis_delta
	model.blocked_cells = blocked_cells.duplicate()
	model.rebuild()
