extends Node


## Explicit one-shot authoring operation through the Studio serializer.
func _ready() -> void:
	if not "apply" in OS.get_cmdline_user_args():
		get_tree().quit(1)
		return
	var path := "res://data/rooms/catabase_routes/route_260dc8ac79d8/room.tres"
	var arena := load(path) as ArenaDefinition
	var changed: Array[String] = []
	for cell: ArenaCellDefinition in arena.cells:
		if cell.terrain_id == &"lava" or cell.cell_type == GridData.CellType.LAVA:
			changed.append(str(cell.coordinate))
			cell.terrain_id = &"stone"
			cell.cell_type = GridData.CellType.NORMAL
	var result := ArenaSerializer.save_canonical(arena, path)
	print(
		"EARLY_WATER_FLOOR ",
		JSON.stringify({ "path": path, "changed": changed, "save_error": result }),
	)
	get_tree().quit(0 if result == OK else 1)
