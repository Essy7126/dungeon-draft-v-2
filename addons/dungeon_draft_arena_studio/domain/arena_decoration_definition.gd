@tool
class_name ArenaDecorationDefinition
extends Resource

@export var decoration_id: StringName = &"decoration"
@export_file("*.tscn") var scene_path := ""
@export var visual_variant: StringName = &""
@export var cell := Vector2i.ZERO
@export var local_offset := Vector2.ZERO
@export var rotation_degrees := 0.0
@export var visual_scale := Vector2.ONE
@export var layer: StringName = &"props"
@export var y_sort := true
@export var gameplay_preset: StringName = &""


func to_dict() -> Dictionary:
	return {
		"decoration_id": str(decoration_id),
		"scene_path": scene_path,
		"visual_variant": str(visual_variant),
		"cell": [cell.x, cell.y],
		"local_offset": [local_offset.x, local_offset.y],
		"rotation_degrees": rotation_degrees,
		"visual_scale": [visual_scale.x, visual_scale.y],
		"layer": str(layer),
		"y_sort": y_sort,
		"gameplay_preset": str(gameplay_preset),
	}


static func from_dict(data: Dictionary) -> ArenaDecorationDefinition:
	var value := ArenaDecorationDefinition.new()
	value.decoration_id = StringName(data.get("decoration_id", "decoration"))
	value.scene_path = str(data.get("scene_path", ""))
	value.visual_variant = StringName(data.get("visual_variant", ""))
	value.cell = ArenaDefinition._vector2i(data.get("cell", [0, 0]))
	value.local_offset = ArenaDefinition._vector2(data.get("local_offset", [0.0, 0.0]))
	value.rotation_degrees = float(data.get("rotation_degrees", 0.0))
	value.visual_scale = ArenaDefinition._vector2(data.get("visual_scale", [1.0, 1.0]))
	value.layer = StringName(data.get("layer", "props"))
	value.y_sort = bool(data.get("y_sort", true))
	value.gameplay_preset = StringName(data.get("gameplay_preset", ""))
	return value
