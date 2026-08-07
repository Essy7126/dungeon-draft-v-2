extends "res://battle/battle.gd"

## Adaptateur runtime modulaire. Toute la logique reste dans battle.gd ; cet
## adaptateur ne fait qu'assembler les visuels declares par ArenaDefinition.

var arena_assembly := {}


func _ready() -> void:
	room_data = GameManager.get_current_room()
	if room_data != null and room_data.grid_layout != null:
		grid_cols = room_data.grid_layout.logical_size.x
		grid_rows = room_data.grid_layout.logical_size.y
	super()
	var definition := room_data as ArenaDefinition
	if definition == null or grid == null or pathfinder == null:
		return
	var floor_parent := _find_or_create_arena_tile_parent(false)
	arena_assembly = ArenaVisualAssembler.assemble(
		definition, grid, pathfinder, grid_view,
		_find_unit_view_parent(), self, true, floor_parent
	)
