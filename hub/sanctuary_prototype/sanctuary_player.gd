class_name SanctuaryPlayer
extends Node2D

## Preparatory sprite component, not a playable scene. The future hub controller
## owns position and navigation; this wrapper never creates any 3D content.
signal visual_initialized(success: bool)

const SpriteBackend := preload("res://characters/achilles/2d/achilles_sprite_2d_backend.gd")
const DEFAULT_PROFILE := preload("res://data/visuals/achilles/achilles_kit_sprite_profile_v2.tres")

@export var sprite_profile: AchillesSpriteVisualProfile = DEFAULT_PROFILE
@export_range(0.05, 2.0, 0.01) var display_scale := 0.35
@export_range(0.1, 1.0, 0.01) var isometric_vertical_ratio := 0.5
@export_enum("N", "E", "S", "W") var initial_facing := "S"

var _backend: AchillesSprite2DBackend
var _local_profile: AchillesSpriteVisualProfile
var _facing := "S"
var _visual_ready := false


func _ready() -> void:
	_facing = initial_facing
	if sprite_profile == null:
		visual_initialized.emit(false)
		return
	_local_profile = sprite_profile.duplicate(true) as AchillesSpriteVisualProfile
	_local_profile.display_scale = display_scale
	_backend = SpriteBackend.new()
	_backend.name = "AchillesSprite"
	add_child(_backend)
	_visual_ready = _backend.configure(_local_profile)
	_backend.set_backend_active(_visual_ready)
	if _visual_ready:
		_backend.play_idle(_facing)
	visual_initialized.emit(_visual_ready)


func _exit_tree() -> void:
	_visual_ready = false
	if is_instance_valid(_backend):
		_backend.shutdown()


func is_visual_ready() -> bool:
	return _visual_ready


## Direction is a vector in the same local 2D space as the painted floor.
## Converts the isometric axes into the four authored sprite directions.
func face_for_direction(direction: Vector2) -> String:
	if direction.is_zero_approx() or not direction.is_finite():
		return _facing
	var vertical := direction.y / maxf(isometric_vertical_ratio, 0.01)
	var grid_direction := Vector2(direction.x + vertical, vertical - direction.x)
	if absf(grid_direction.x) >= absf(grid_direction.y):
		_facing = "E" if grid_direction.x > 0.0 else "W"
	else:
		_facing = "S" if grid_direction.y > 0.0 else "N"
	if _visual_ready:
		_backend.set_facing_label(_facing)
	return _facing


func play_walk(direction := Vector2.ZERO) -> bool:
	face_for_direction(direction)
	return _backend.play_move(_facing, false) if _visual_ready else false


func play_idle() -> bool:
	return _backend.play_idle(_facing) if _visual_ready else false


func cancel_movement_feedback() -> void:
	if _visual_ready:
		_backend.cancel_action()
		_backend.play_idle(_facing)


func get_facing() -> String:
	return _facing


func get_visual_state() -> Dictionary:
	return _backend.get_runtime_state() if _visual_ready else {}
