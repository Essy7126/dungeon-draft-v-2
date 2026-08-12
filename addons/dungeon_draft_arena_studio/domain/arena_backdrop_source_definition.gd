@tool
class_name ArenaBackdropSourceDefinition
extends Resource

@export var source_id: StringName = &"backdrop"
@export var display_name := "Décor"
@export var source_arena_path := ""
@export var source_run_path := ""
@export var source_room_index := -1
@export var background_path := ""
@export var source_image_size := Vector2i.ZERO
@export var grid_size := Vector2i(14, 14)
@export var grid_origin := Vector2.ZERO
@export var axis_x := Vector2(48, 24)
@export var axis_y := Vector2(-48, 24)
@export var image_offset := Vector2.ZERO
@export var image_scale := Vector2.ONE
@export var camera_offset := Vector2.ZERO
@export var camera_zoom := 1.0
@export var foreground_path := ""
@export var occlusion_mask_path := ""
@export var foreground_offset := Vector2.ZERO
@export var foreground_scale := Vector2.ONE
@export var foreground_occluder_polygon := PackedVector2Array()
@export var foreground_occluder_sort_y := 0.0
@export var foreground_full_hide_rect := Rect2()
@export var presentation_profile_path := ""
@export var theme_id: StringName = &"painted_default"
@export var calibration_available := true
@export var foreground_available := false


func is_loadable() -> bool:
	return not background_path.is_empty() and (
		ResourceLoader.exists(background_path) or FileAccess.file_exists(background_path)
	)


func to_summary() -> Dictionary:
	return {
		"source_id": source_id,
		"display_name": display_name,
		"background_path": background_path,
		"source_image_size": source_image_size,
		"grid_size": grid_size,
		"grid_angle_degrees": rad_to_deg(axis_x.angle()),
		"theme_id": theme_id,
		"calibration_available": calibration_available,
		"foreground_available": foreground_available,
		"source_arena_path": source_arena_path,
		"source_run_path": source_run_path,
		"source_room_index": source_room_index,
	}


static func from_arena(arena: ArenaDefinition, path := "") -> ArenaBackdropSourceDefinition:
	if arena == null:
		return null
	var result := ArenaBackdropSourceDefinition.new()
	result.source_id = arena.arena_id
	result.display_name = arena.display_name
	result.source_arena_path = path if not path.is_empty() else arena.resource_path
	result.background_path = arena.background_path
	result.source_image_size = arena.source_image_size
	result.grid_size = arena.grid_size
	result.grid_origin = arena.grid_origin
	result.axis_x = arena.axis_x
	result.axis_y = arena.axis_y
	result.image_offset = arena.image_offset
	result.image_scale = arena.image_scale
	result.camera_offset = arena.camera_offset
	result.camera_zoom = arena.camera_zoom
	result.foreground_path = arena.foreground_path
	result.occlusion_mask_path = arena.occlusion_mask_path
	result.foreground_offset = arena.foreground_offset
	result.foreground_scale = arena.foreground_scale
	result.foreground_occluder_polygon = arena.foreground_occluder_polygon.duplicate()
	result.foreground_occluder_sort_y = arena.foreground_occluder_sort_y
	result.foreground_full_hide_rect = arena.foreground_full_hide_rect
	result.presentation_profile_path = arena.presentation_profile_path
	result.theme_id = arena.theme_id
	result.calibration_available = GridTransformService.is_invertible(arena.axis_x, arena.axis_y)
	result.foreground_available = not arena.foreground_path.is_empty()
	return result
