@tool
class_name ArenaCellDefinition
extends Resource

@export var coordinate := Vector2i.ZERO
@export var defined := true
@export var playable := true
@export var border := false
@export_enum("Normal:0", "Mur:1", "Trou:2", "Lave:3", "Glace:4", "Ombre:5", "Rune:6")
var cell_type: int = GridData.CellType.NORMAL
@export var terrain_id: StringName = &"normal"
@export_multiline var production_note := ""


func to_dict() -> Dictionary:
	return {
		"coordinate": [coordinate.x, coordinate.y],
		"defined": defined,
		"playable": playable,
		"border": border,
		"cell_type": cell_type,
		"terrain_id": str(terrain_id),
		"production_note": production_note,
	}


static func from_dict(data: Dictionary) -> ArenaCellDefinition:
	var definition := ArenaCellDefinition.new()
	var coordinate_data: Array = data.get("coordinate", [0, 0])
	definition.coordinate = Vector2i(int(coordinate_data[0]), int(coordinate_data[1]))
	definition.defined = bool(data.get("defined", true))
	definition.playable = bool(data.get("playable", true))
	definition.border = bool(data.get("border", false))
	definition.cell_type = clampi(
		int(data.get("cell_type", GridData.CellType.NORMAL)),
		GridData.CellType.NORMAL,
		GridData.CellType.RUNE
	)
	definition.terrain_id = StringName(data.get("terrain_id", "normal"))
	definition.production_note = str(data.get("production_note", ""))
	return definition
