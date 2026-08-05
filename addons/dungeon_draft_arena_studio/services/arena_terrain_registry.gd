@tool
class_name ArenaTerrainRegistry
extends RefCounted

const TEXTURE_ROOT := "res://tools/labs/dynamic_arena/assets/normalized"

const ENTRIES := {
	&"void": {"name": "VOID", "cell_type": GridData.CellType.HOLE, "walkable": false, "visual": "", "effects": [], "color": "101722", "dynamic": true},
	&"normal": {"name": "Normal", "cell_type": GridData.CellType.NORMAL, "walkable": true, "visual": TEXTURE_ROOT + "/stone.png", "effects": [], "color": "a8b5c3", "dynamic": true},
	&"stone": {"name": "Pierre", "cell_type": GridData.CellType.NORMAL, "walkable": true, "visual": TEXTURE_ROOT + "/stone.png", "effects": [], "color": "a8b5c3", "dynamic": true},
	&"water": {"name": "Eau", "cell_type": GridData.CellType.NORMAL, "walkable": true, "visual": TEXTURE_ROOT + "/water.png", "effects": [&"water"], "color": "38c8ed", "dynamic": true},
	&"ice": {"name": "Glace", "cell_type": GridData.CellType.ICE, "walkable": true, "visual": TEXTURE_ROOT + "/ice.png", "effects": [&"ice"], "color": "c8f4ff", "dynamic": true},
	# Le Lab historique traite la lave comme impraticable. L'identite reste
	# 'lava' tandis que le GridData effectif est WALL : aucune deduction visuelle.
	&"lava": {"name": "Lave", "cell_type": GridData.CellType.WALL, "walkable": false, "visual": TEXTURE_ROOT + "/lava.png", "effects": [&"fire"], "color": "ff6537", "dynamic": true},
	&"wall": {"name": "Mur logique", "cell_type": GridData.CellType.WALL, "walkable": false, "visual": "", "effects": [], "color": "d24d3f", "dynamic": false},
	&"hole": {"name": "Trou", "cell_type": GridData.CellType.HOLE, "walkable": false, "visual": "", "effects": [], "color": "18202d", "dynamic": false},
	&"shadow": {"name": "Ombre", "cell_type": GridData.CellType.SHADOW, "walkable": true, "visual": "", "effects": [], "color": "51347c", "dynamic": false},
	&"rune": {"name": "Rune", "cell_type": GridData.CellType.RUNE, "walkable": true, "visual": "", "effects": [], "color": "b845e8", "dynamic": false},
}


static func has(terrain_id: StringName) -> bool:
	return ENTRIES.has(terrain_id)


static func get_entry(terrain_id: StringName) -> Dictionary:
	return (ENTRIES.get(terrain_id, {}) as Dictionary).duplicate(true)


static func all_ids(dynamic_only := false) -> Array[StringName]:
	var result: Array[StringName] = []
	for terrain_id in ENTRIES:
		if not dynamic_only or bool(ENTRIES[terrain_id].dynamic):
			result.append(terrain_id)
	return result


static func configure_cell(definition: ArenaCellDefinition, terrain_id: StringName) -> bool:
	if definition == null or not has(terrain_id):
		return false
	var entry := get_entry(terrain_id)
	definition.terrain_id = terrain_id
	definition.defined = terrain_id != &"void"
	definition.playable = bool(entry.walkable)
	definition.cell_type = int(entry.cell_type)
	return true


static func texture_for(terrain_id: StringName) -> Texture2D:
	var path := str(get_entry(terrain_id).get("visual", ""))
	return load(path) as Texture2D if not path.is_empty() and ResourceLoader.exists(path) else null


static func color_for(terrain_id: StringName) -> Color:
	return Color.from_string(str(get_entry(terrain_id).get("color", "ffffff")), Color.WHITE)
