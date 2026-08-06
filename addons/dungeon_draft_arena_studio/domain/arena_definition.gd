@tool
class_name ArenaDefinition
extends RoomData

## Source de verite versionnee des nouvelles arenes. Elle herite de RoomData :
## la ressource sauvegardee par Arena Studio est donc directement consommable
## par GameManager et painted_battle, sans scene intermediaire generee.

const CURRENT_SCHEMA_VERSION := 2
const DEFAULT_BATTLE_SCENE := "res://data/rooms/maps/painted_battle.tscn"
const MODULAR_BATTLE_SCENE := "res://data/rooms/maps/modular_battle.tscn"
const DEFAULT_PRESENTATION := "res://data/maps/painted/room_01_forest_presentation.tres"

enum CampOrientation {
	HERO_BOTTOM_LEFT,
	HERO_BOTTOM_RIGHT,
	HERO_TOP_LEFT,
	HERO_TOP_RIGHT,
}

enum VisualMode {
	PAINTED,
	MODULAR,
	HYBRID,
}

@export var schema_version := CURRENT_SCHEMA_VERSION
@export var arena_id: StringName = &"nouvelle_arene"
@export var display_name := "Nouvelle arene"
@export_enum("Peinte:0", "Modulaire:1", "Hybride:2")
var visual_mode: int = VisualMode.PAINTED
@export var theme_id: StringName = &"painted_default"
@export var modular_visual_profile: ArenaModularVisualProfile = null
@export_file("*.png", "*.jpg", "*.jpeg", "*.webp") var background_path := ""
@export var source_image_size := Vector2i.ZERO
@export var grid_size := Vector2i(10, 8)
@export var grid_origin := Vector2.ZERO
@export var axis_x := Vector2(48.0, 24.0)
@export var axis_y := Vector2(-48.0, 24.0)
@export var image_offset := Vector2.ZERO
@export var image_scale := Vector2.ONE
@export_file("*.png", "*.jpg", "*.jpeg", "*.webp") var foreground_path := ""
@export_file("*.png") var occlusion_mask_path := ""
@export var foreground_offset := Vector2.ZERO
@export var foreground_scale := Vector2.ONE
@export var foreground_occluder_polygon := PackedVector2Array()
@export var foreground_occluder_sort_y := 0.0
@export var foreground_full_hide_rect := Rect2()
@export var camera_offset := Vector2.ZERO
@export_range(0.25, 3.0, 0.01) var camera_zoom := 1.0
@export_enum("Heros en bas a gauche:0", "Heros en bas a droite:1", "Heros en haut a gauche:2", "Heros en haut a droite:3")
var camp_orientation: int = CampOrientation.HERO_BOTTOM_LEFT
@export var border_thickness := 1
@export var cells: Array[ArenaCellDefinition] = []
@export var obstacles: Array[ArenaObstacleDefinition] = []
@export var spawns: Array[ArenaSpawnDefinition] = []
@export var objectives: Array[ArenaObjectiveDefinition] = []
@export var decorations: Array[ArenaDecorationDefinition] = []
@export var calibration_cells: Array[Vector2i] = []
@export var calibration_pixels: Array[Vector2] = []
@export_file("*.tres") var presentation_profile_path := DEFAULT_PRESENTATION
@export_file("*.tres") var source_room_path := ""
@export_file("*.tres") var source_visual_path := ""
@export var intentionally_isolated_cells: Array[Vector2i] = []
@export_multiline var production_notes := ""


func _init() -> void:
	if battle_scene == null and ResourceLoader.exists(DEFAULT_BATTLE_SCENE):
		battle_scene = load(DEFAULT_BATTLE_SCENE) as PackedScene
	room_name = display_name


func set_identity(new_display_name: String, requested_id := "") -> void:
	display_name = new_display_name.strip_edges()
	arena_id = StringName(sanitize_id(
		requested_id if not requested_id.strip_edges().is_empty() else display_name
	))
	room_name = display_name


func is_in_bounds(cell: Vector2i) -> bool:
	return GridTransformService.is_cell_in_bounds(cell, grid_size)


func get_cell_definition(cell: Vector2i) -> ArenaCellDefinition:
	for definition in cells:
		if definition != null and definition.coordinate == cell:
			return definition
	return null


func ensure_cell(cell: Vector2i) -> ArenaCellDefinition:
	if not is_in_bounds(cell):
		return null
	var existing := get_cell_definition(cell)
	if existing != null:
		existing.defined = true
		return existing
	var definition := ArenaCellDefinition.new()
	definition.coordinate = cell
	cells.append(definition)
	return definition


func erase_cell(cell: Vector2i) -> bool:
	var existing := get_cell_definition(cell)
	if existing == null:
		return false
	cells.erase(existing)
	obstacles = obstacles.filter(func(obstacle):
		return obstacle != null and obstacle.cell != cell
	)
	spawns = spawns.filter(func(spawn):
		return spawn != null and spawn.cell != cell
	)
	objectives = objectives.filter(func(objective):
		return objective != null and objective.cell != cell
	)
	decorations = decorations.filter(func(decoration):
		return decoration != null and decoration.cell != cell
	)
	return true


func defined_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for definition in cells:
		if definition != null and definition.defined:
			result.append(definition.coordinate)
	return result


func playable_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for definition in cells:
		if definition != null and definition.defined and definition.playable \
				and not definition.border \
				and GridData.PROPERTIES[definition.cell_type]["walkable"]:
			result.append(definition.coordinate)
	return result


func border_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for definition in cells:
		if definition != null and definition.defined and definition.border:
			result.append(definition.coordinate)
	return result


func obstacle_at(cell: Vector2i) -> ArenaObstacleDefinition:
	for obstacle in obstacles:
		if obstacle != null and obstacle.cell == cell:
			return obstacle
	return null


func spawns_at(cell: Vector2i) -> Array[ArenaSpawnDefinition]:
	var result: Array[ArenaSpawnDefinition] = []
	for spawn in spawns:
		if spawn != null and spawn.cell == cell:
			result.append(spawn)
	return result


func to_snapshot() -> Dictionary:
	return {
		"schema_version": schema_version,
		"arena_id": str(arena_id),
		"display_name": display_name,
		"visual_mode": visual_mode,
		"theme_id": str(theme_id),
		"modular_visual_profile": modular_visual_profile.to_dict() \
			if modular_visual_profile != null else {},
		"background_path": background_path,
		"source_image_size": [source_image_size.x, source_image_size.y],
		"grid_size": [grid_size.x, grid_size.y],
		"grid_origin": [grid_origin.x, grid_origin.y],
		"axis_x": [axis_x.x, axis_x.y],
		"axis_y": [axis_y.x, axis_y.y],
		"image_offset": [image_offset.x, image_offset.y],
		"image_scale": [image_scale.x, image_scale.y],
		"foreground_path": foreground_path,
		"occlusion_mask_path": occlusion_mask_path,
		"foreground_offset": [foreground_offset.x, foreground_offset.y],
		"foreground_scale": [foreground_scale.x, foreground_scale.y],
		"foreground_occluder_polygon": Array(foreground_occluder_polygon).map(
			func(value): return [value.x, value.y]
		),
		"foreground_occluder_sort_y": foreground_occluder_sort_y,
		"foreground_full_hide_rect": [
			foreground_full_hide_rect.position.x,
			foreground_full_hide_rect.position.y,
			foreground_full_hide_rect.size.x,
			foreground_full_hide_rect.size.y,
		],
		"camera_offset": [camera_offset.x, camera_offset.y],
		"camera_zoom": camera_zoom,
		"camp_orientation": camp_orientation,
		"border_thickness": border_thickness,
		"cells": cells.filter(func(value): return value != null).map(
			func(value): return value.to_dict()
		),
		"obstacles": obstacles.filter(func(value): return value != null).map(
			func(value): return value.to_dict()
		),
		"spawns": spawns.filter(func(value): return value != null).map(
			func(value): return value.to_dict()
		),
		"objectives": objectives.filter(func(value): return value != null).map(
			func(value): return value.to_dict()
		),
		"decorations": decorations.filter(func(value): return value != null).map(
			func(value): return value.to_dict()
		),
		"calibration_cells": calibration_cells.map(
			func(value): return [value.x, value.y]
		),
		"calibration_pixels": calibration_pixels.map(
			func(value): return [value.x, value.y]
		),
		"presentation_profile_path": presentation_profile_path,
		"source_room_path": source_room_path,
		"source_visual_path": source_visual_path,
		"encounter_path": encounter_definition.resource_path \
			if encounter_definition != null else "",
		"battle_scene_path": battle_scene.resource_path if battle_scene != null else "",
		"intentionally_isolated_cells": intentionally_isolated_cells.map(
			func(value): return [value.x, value.y]
		),
		"production_notes": production_notes,
	}


func restore_snapshot(data: Dictionary) -> bool:
	if int(data.get("schema_version", -1)) > CURRENT_SCHEMA_VERSION:
		return false
	schema_version = int(data.get("schema_version", CURRENT_SCHEMA_VERSION))
	arena_id = StringName(data.get("arena_id", "nouvelle_arene"))
	display_name = str(data.get("display_name", "Nouvelle arene"))
	visual_mode = clampi(
		int(data.get("visual_mode", VisualMode.PAINTED)),
		VisualMode.PAINTED, VisualMode.HYBRID
	)
	theme_id = StringName(data.get("theme_id", "painted_default"))
	var modular_data = data.get("modular_visual_profile", {})
	modular_visual_profile = ArenaModularVisualProfile.from_dict(modular_data) \
		if modular_data is Dictionary and not modular_data.is_empty() else null
	room_name = display_name
	background_path = str(data.get("background_path", ""))
	source_image_size = _vector2i(data.get("source_image_size", [0, 0]))
	grid_size = _vector2i(data.get("grid_size", [10, 8]))
	grid_origin = _vector2(data.get("grid_origin", [0.0, 0.0]))
	axis_x = _vector2(data.get("axis_x", [48.0, 24.0]))
	axis_y = _vector2(data.get("axis_y", [-48.0, 24.0]))
	image_offset = _vector2(data.get("image_offset", [0.0, 0.0]))
	image_scale = _vector2(data.get("image_scale", [1.0, 1.0]))
	foreground_path = str(data.get("foreground_path", ""))
	occlusion_mask_path = str(data.get("occlusion_mask_path", ""))
	foreground_offset = _vector2(data.get("foreground_offset", [0.0, 0.0]))
	foreground_scale = _vector2(data.get("foreground_scale", [1.0, 1.0]))
	foreground_occluder_polygon = _packed_vector2_array(
		data.get("foreground_occluder_polygon", [])
	)
	foreground_occluder_sort_y = float(data.get("foreground_occluder_sort_y", 0.0))
	foreground_full_hide_rect = _rect2(
		data.get("foreground_full_hide_rect", [0.0, 0.0, 0.0, 0.0])
	)
	camera_offset = _vector2(data.get("camera_offset", [0.0, 0.0]))
	camera_zoom = float(data.get("camera_zoom", 1.0))
	camp_orientation = clampi(
		int(data.get("camp_orientation", CampOrientation.HERO_BOTTOM_LEFT)),
		CampOrientation.HERO_BOTTOM_LEFT,
		CampOrientation.HERO_TOP_RIGHT
	)
	border_thickness = maxi(1, int(data.get("border_thickness", 1)))
	cells.clear()
	for entry in data.get("cells", []):
		if entry is Dictionary:
			cells.append(ArenaCellDefinition.from_dict(entry))
	obstacles.clear()
	for entry in data.get("obstacles", []):
		if entry is Dictionary:
			obstacles.append(ArenaObstacleDefinition.from_dict(entry))
	spawns.clear()
	for entry in data.get("spawns", []):
		if entry is Dictionary:
			spawns.append(ArenaSpawnDefinition.from_dict(entry))
	objectives.clear()
	for entry in data.get("objectives", []):
		if entry is Dictionary:
			objectives.append(ArenaObjectiveDefinition.from_dict(entry))
	decorations.clear()
	for entry in data.get("decorations", []):
		if entry is Dictionary:
			decorations.append(ArenaDecorationDefinition.from_dict(entry))
	calibration_cells.clear()
	for entry in data.get("calibration_cells", []):
		calibration_cells.append(_vector2i(entry))
	calibration_pixels.clear()
	for entry in data.get("calibration_pixels", []):
		calibration_pixels.append(_vector2(entry))
	presentation_profile_path = str(data.get(
		"presentation_profile_path", DEFAULT_PRESENTATION
	))
	source_room_path = str(data.get("source_room_path", ""))
	source_visual_path = str(data.get("source_visual_path", ""))
	var encounter_path := str(data.get("encounter_path", ""))
	encounter_definition = load(encounter_path) as EncounterDefinition \
		if ResourceLoader.exists(encounter_path) else null
	var battle_path := str(data.get("battle_scene_path", DEFAULT_BATTLE_SCENE))
	battle_scene = load(battle_path) as PackedScene \
		if ResourceLoader.exists(battle_path) else null
	intentionally_isolated_cells.clear()
	for entry in data.get("intentionally_isolated_cells", []):
		intentionally_isolated_cells.append(_vector2i(entry))
	production_notes = str(data.get("production_notes", ""))
	return true


static func sanitize_id(value: String) -> String:
	var normalized := value.strip_edges().to_lower()
	var replacements := {
		"à": "a", "â": "a", "ä": "a", "á": "a", "ã": "a",
		"ç": "c", "é": "e", "è": "e", "ê": "e", "ë": "e",
		"î": "i", "ï": "i", "í": "i", "ô": "o", "ö": "o",
		"ó": "o", "ù": "u", "û": "u", "ü": "u", "ú": "u",
		"ÿ": "y", "œ": "oe", " ": "_", "'": "_", "-": "_",
	}
	for key in replacements:
		normalized = normalized.replace(key, replacements[key])
	var safe := ""
	for character in normalized:
		var byte := character.to_ascii_buffer()[0] if not character.is_empty() else 0
		if byte in range(48, 58) or byte in range(97, 123) or character == "_":
			safe += character
	while "__" in safe:
		safe = safe.replace("__", "_")
	safe = safe.trim_prefix("_").trim_suffix("_")
	return safe if not safe.is_empty() else "nouvelle_arene"


static func _vector2(data) -> Vector2:
	return Vector2(float(data[0]), float(data[1])) \
		if data is Array and data.size() >= 2 else Vector2.ZERO


static func _vector2i(data) -> Vector2i:
	return Vector2i(int(data[0]), int(data[1])) \
		if data is Array and data.size() >= 2 else Vector2i.ZERO


static func _packed_vector2_array(data) -> PackedVector2Array:
	var result := PackedVector2Array()
	if data is Array:
		for entry in data:
			result.append(_vector2(entry))
	return result


static func _rect2(data) -> Rect2:
	return Rect2(
		float(data[0]), float(data[1]), float(data[2]), float(data[3])
	) if data is Array and data.size() >= 4 else Rect2()
