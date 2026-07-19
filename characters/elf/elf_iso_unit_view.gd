class_name ElfIsoUnitView
extends Node2D

signal animation_started(animation_name: StringName)
signal animation_finished(animation_name: StringName)
signal cast_release_reached
signal hit_reaction_finished
signal death_animation_finished

const GRID_FOOTPRINT := Vector2(64.0, 32.0)
const MOVE_SEGMENT_DURATION := 0.15
const WALK_SOURCE_DURATION := 31.0 / 30.0
const RUN_SOURCE_DURATION := 19.0 / 30.0

enum VisualPriority {
	IDLE,
	MOVEMENT,
	CAST,
	HIT,
	DEATH,
}

@export var viewport_size := Vector2i(768, 512):
	set(value):
		viewport_size = Vector2i(maxi(value.x, 64), maxi(value.y, 64))
		if is_node_ready():
			_apply_viewport_configuration()

@export_range(2.0, 32.0, 0.001) var camera_orthographic_size := 2.220395:
	set(value):
		camera_orthographic_size = maxf(value, 2.0)
		if is_node_ready():
			camera.size = camera_orthographic_size
			_realign_foot_deferred()

@export_range(0.0, 2.0, 0.01) var camera_look_at_height := 0.87:
	set(value):
		camera_look_at_height = value
		if is_node_ready():
			camera.look_at(Vector3(0.0, camera_look_at_height, 0.0), Vector3.UP)
			_realign_foot_deferred()

@export_range(0.05, 1.0, 0.0001) var render_display_scale := 0.1387747:
	set(value):
		render_display_scale = clampf(value, 0.05, 1.0)
		if is_node_ready():
			render_sprite.scale = Vector2.ONE * render_display_scale
			_realign_foot_deferred()

@export var model_scale_multiplier := Vector3(1.10, 1.10, 1.10):
	set(value):
		model_scale_multiplier = value
		if is_node_ready():
			character_pivot.scale = model_scale_multiplier
			_realign_foot_deferred()

@export_range(0.75, 1.50, 0.01) var character_scale: float = 1.10:
	set(value):
		character_scale = clampf(value, 0.75, 1.50)
		model_scale_multiplier = Vector3.ONE * character_scale

@export var render_offset_adjustment := Vector2.ZERO:
	set(value):
		render_offset_adjustment = value
		if is_node_ready():
			_realign_foot_deferred()

@export var shadow_size := Vector2(30.0, 9.0):
	set(value):
		shadow_size = Vector2(maxf(value.x, 1.0), maxf(value.y, 1.0))
		if is_node_ready():
			_update_shadow()

@export_range(0.0, 1.0, 0.01) var shadow_opacity := 0.28:
	set(value):
		shadow_opacity = clampf(value, 0.0, 1.0)
		if is_node_ready():
			_update_shadow()

## The imported elf faces +Z at yaw 0. The fixed camera maps logical +X to
## world +X and logical +Y to world +Z.
@export_range(-360.0, 360.0, 0.1) var facing_yaw_pos_x := 90.0
@export_range(-360.0, 360.0, 0.1) var facing_yaw_neg_x := -90.0
@export_range(-360.0, 360.0, 0.1) var facing_yaw_pos_y := 0.0
@export_range(-360.0, 360.0, 0.1) var facing_yaw_neg_y := 180.0

## Corrections artistiques appliquees apres le calcul distance/duree/boucle.
@export_range(0.25, 3.0, 0.01) var walk_animation_speed_multiplier: float = 1.0
@export_range(0.25, 3.0, 0.01) var run_animation_speed_multiplier: float = 1.0

@onready var ground_shadow: Polygon2D = $GroundShadow
@onready var render_sprite: Sprite2D = $RenderSprite
@onready var character_viewport: SubViewport = $CharacterViewport
@onready var character_world: Node3D = $CharacterViewport/CharacterWorld
@onready var camera: Camera3D = $CharacterViewport/CharacterWorld/CharacterCamera
@onready var character_pivot: Node3D = $CharacterViewport/CharacterWorld/CharacterPivot
@onready var elf_visual: ElfVisual3D = $CharacterViewport/CharacterWorld/CharacterPivot/ElfVisual3D

var _unit: Unit = null
var _facing := Vector2i(0, 1)
var _movement_active := false
var _movement_seen_motion := false
var _movement_stable_time := 0.0
var _last_parent_position := Vector2.ZERO
var _has_parent_sample := false
var _debug_run_for_next_movement := false
var _death_locked := false
var _foot_pixel := Vector2.ZERO
var _visual_priority := VisualPriority.IDLE
var _missing_socket_warning_emitted := false


func _ready() -> void:
	_apply_viewport_configuration()
	model_scale_multiplier = Vector3.ONE * character_scale
	character_pivot.scale = model_scale_multiplier
	camera.look_at(Vector3(0.0, camera_look_at_height, 0.0), Vector3.UP)
	render_sprite.texture = character_viewport.get_texture()
	render_sprite.centered = false
	render_sprite.scale = Vector2.ONE * render_display_scale
	render_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_update_shadow()
	_connect_visual_signals()
	_realign_foot_deferred()
	set_process(true)


func _process(delta: float) -> void:
	_track_parent_movement(delta)


func bind_unit(unit: Unit) -> void:
	if _unit == unit:
		return
	if is_instance_valid(_unit):
		var moved_callable := Callable(self, "_on_bound_unit_moved")
		var died_callable := Callable(self, "_on_bound_unit_died")
		if _unit.moved.is_connected(moved_callable):
			_unit.moved.disconnect(moved_callable)
		if _unit.died.is_connected(died_callable):
			_unit.died.disconnect(died_callable)
	_unit = unit
	if _unit != null:
		_unit.moved.connect(_on_bound_unit_moved)
		_unit.died.connect(_on_bound_unit_died)
	if not EventBus.damage_dealt.is_connected(_on_damage_dealt):
		EventBus.damage_dealt.connect(_on_damage_dealt)


func play_idle() -> bool:
	if _death_locked or _visual_priority > VisualPriority.IDLE:
		return false
	return _play_if_new(ElfVisual3D.ANIM_IDLE, VisualPriority.IDLE, 1.0)


func play_walk(speed_scale: float = 1.0) -> bool:
	if _death_locked or _visual_priority > VisualPriority.MOVEMENT:
		return false
	return _play_if_new(
		ElfVisual3D.ANIM_WALK,
		VisualPriority.MOVEMENT,
		maxf(speed_scale, 0.01) * walk_animation_speed_multiplier
	)


func play_run(speed_scale: float = 1.0) -> bool:
	if _death_locked or _visual_priority > VisualPriority.MOVEMENT:
		return false
	return _play_if_new(
		ElfVisual3D.ANIM_RUN,
		VisualPriority.MOVEMENT,
		maxf(speed_scale, 0.01) * run_animation_speed_multiplier
	)


func play_cast() -> bool:
	if _death_locked or _visual_priority > VisualPriority.CAST:
		return false
	return _play_if_new(ElfVisual3D.ANIM_CAST_FULL, VisualPriority.CAST, 1.0)


func play_hit() -> bool:
	if _death_locked or _visual_priority > VisualPriority.HIT:
		return false
	return _play_if_new(ElfVisual3D.ANIM_HIT, VisualPriority.HIT, 1.0)


func play_death() -> bool:
	if _death_locked or _visual_priority == VisualPriority.DEATH:
		return false
	_death_locked = true
	_movement_active = false
	return _play_if_new(ElfVisual3D.ANIM_DEATH, VisualPriority.DEATH, 1.0)


func _play_if_new(animation_name: StringName, priority: VisualPriority, speed_scale: float) -> bool:
	if elf_visual.get_current_animation() == animation_name \
			and elf_visual.is_animation_playing(animation_name):
		return false
	_visual_priority = priority
	match animation_name:
		ElfVisual3D.ANIM_IDLE:
			elf_visual.play_idle()
		ElfVisual3D.ANIM_WALK:
			elf_visual.play_walk(speed_scale)
		ElfVisual3D.ANIM_RUN:
			elf_visual.play_run(speed_scale)
		ElfVisual3D.ANIM_CAST_FULL:
			elf_visual.play_cast_full(speed_scale)
		ElfVisual3D.ANIM_HIT:
			elf_visual.play_hit(speed_scale)
		ElfVisual3D.ANIM_DEATH:
			elf_visual.play_death(speed_scale)
		_:
			return false
	return true


func set_facing(direction: Vector2i) -> void:
	if direction == Vector2i.ZERO:
		return
	var cardinal := direction
	if direction not in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		cardinal = Vector2i(signi(direction.x), 0) if absi(direction.x) >= absi(direction.y) else Vector2i(0, signi(direction.y))
	_facing = cardinal
	match cardinal:
		Vector2i.RIGHT:
			character_pivot.rotation_degrees.y = facing_yaw_pos_x
		Vector2i.LEFT:
			character_pivot.rotation_degrees.y = facing_yaw_neg_x
		Vector2i.DOWN:
			character_pivot.rotation_degrees.y = facing_yaw_pos_y
		Vector2i.UP:
			character_pivot.rotation_degrees.y = facing_yaw_neg_y


func set_socket_debug_visible(visible: bool) -> void:
	elf_visual.set_socket_debug_visible(visible)


func get_elf_visual() -> Node:
	return elf_visual


func get_logical_foot_position() -> Vector2:
	return Vector2.ZERO


func get_projected_foot_pixel() -> Vector2:
	return _foot_pixel


func get_facing_direction() -> Vector2i:
	return _facing


func get_left_hand_effect_origin() -> Vector2:
	return _project_effect_origin(elf_visual.get_left_weapon_mount(), "WeaponMountLeft")


func get_right_hand_effect_origin() -> Vector2:
	return _project_effect_origin(elf_visual.get_right_weapon_mount(), "WeaponMountRight")


func get_default_cast_effect_origin() -> Vector2:
	return get_right_hand_effect_origin()


func _project_effect_origin(mount: Node3D, socket_name: String) -> Vector2:
	var world_position: Vector3
	if is_instance_valid(mount):
		world_position = mount.global_position
	else:
		world_position = character_pivot.to_global(Vector3(0.0, 1.15, 0.0))
		if not _missing_socket_warning_emitted:
			_missing_socket_warning_emitted = true
			push_warning("ElfIsoUnitView: %s absent; origine de sort repliee pres du torse." % socket_name)
	var viewport_pixel := camera.unproject_position(world_position)
	return to_local(render_sprite.to_global(viewport_pixel))


func set_debug_run_for_next_movement(enabled: bool) -> void:
	_debug_run_for_next_movement = enabled


func cancel_movement_feedback() -> void:
	_movement_active = false
	_movement_seen_motion = false
	_movement_stable_time = 0.0
	_has_parent_sample = false
	if not _death_locked:
		if _visual_priority == VisualPriority.MOVEMENT:
			_visual_priority = VisualPriority.IDLE
		play_idle()


func _on_bound_unit_moved(from_cell: Vector2i, to_cell: Vector2i) -> void:
	if _death_locked:
		return
	set_facing(to_cell - from_cell)
	_movement_active = true
	_movement_seen_motion = false
	_movement_stable_time = 0.0
	_has_parent_sample = false
	var distance_cells := absi(to_cell.x - from_cell.x) + absi(to_cell.y - from_cell.y)
	var playback_speed := _movement_playback_speed(
		RUN_SOURCE_DURATION if _debug_run_for_next_movement else WALK_SOURCE_DURATION,
		distance_cells
	)
	if _debug_run_for_next_movement:
		play_run(playback_speed)
	else:
		play_walk(playback_speed)


func _movement_playback_speed(loop_duration: float, distance_cells: int) -> float:
	var travelled_distance := maxf(float(distance_cells), 1.0) * GRID_FOOTPRINT.length() * 0.5
	var one_cell_distance := GRID_FOOTPRINT.length() * 0.5
	var visual_cycles := travelled_distance / one_cell_distance
	var gameplay_duration := maxf(float(distance_cells), 1.0) * MOVE_SEGMENT_DURATION
	return loop_duration * visual_cycles / gameplay_duration


func _on_bound_unit_died(unit: Unit) -> void:
	if unit == _unit:
		play_death()


func _on_damage_dealt(target, _attacker, amount: int, _category: int, _element: int, _is_crit: bool) -> void:
	if target == _unit and amount > 0 and _unit.is_alive:
		play_hit()


func _track_parent_movement(delta: float) -> void:
	var parent_2d := get_parent() as Node2D
	if parent_2d == null:
		return
	var current := parent_2d.position
	if not _has_parent_sample:
		_last_parent_position = current
		_has_parent_sample = true
		return
	var screen_delta := current - _last_parent_position
	_last_parent_position = current
	if not _movement_active:
		return
	if screen_delta.length_squared() > 0.0001:
		_movement_seen_motion = true
		_movement_stable_time = 0.0
		_update_facing_from_projected_delta(screen_delta)
		return
	if not _movement_seen_motion:
		return
	_movement_stable_time += delta
	if _movement_stable_time >= 0.06:
		_movement_active = false
		_movement_seen_motion = false
		if _visual_priority == VisualPriority.MOVEMENT:
			_visual_priority = VisualPriority.IDLE
		play_idle()


func _update_facing_from_projected_delta(delta: Vector2) -> void:
	## Inverse of (+X -> (32,16), +Y -> (-32,16)).
	var grid_x := delta.x / GRID_FOOTPRINT.x + delta.y / GRID_FOOTPRINT.y
	var grid_y := -delta.x / GRID_FOOTPRINT.x + delta.y / GRID_FOOTPRINT.y
	if absf(grid_x) >= absf(grid_y):
		set_facing(Vector2i(signi(grid_x), 0))
	else:
		set_facing(Vector2i(0, signi(grid_y)))


func _apply_viewport_configuration() -> void:
	character_viewport.size = viewport_size
	camera.size = camera_orthographic_size
	_realign_foot_deferred()


func _realign_foot_deferred() -> void:
	if not is_inside_tree():
		return
	call_deferred("_realign_foot_after_frame")


func _realign_foot_after_frame() -> void:
	await get_tree().process_frame
	_foot_pixel = camera.unproject_position(character_world.to_global(Vector3.ZERO))
	render_sprite.position = -_foot_pixel * render_sprite.scale + render_offset_adjustment


func _update_shadow() -> void:
	var points := PackedVector2Array()
	for index in range(32):
		var angle := TAU * float(index) / 32.0
		points.append(Vector2(cos(angle) * shadow_size.x * 0.5, sin(angle) * shadow_size.y * 0.5))
	ground_shadow.polygon = points
	ground_shadow.color = Color(0.02, 0.025, 0.03, shadow_opacity)


func _connect_visual_signals() -> void:
	elf_visual.animation_started.connect(_on_visual_animation_started)
	elf_visual.animation_finished.connect(_on_visual_animation_finished)
	elf_visual.cast_release_reached.connect(func(): cast_release_reached.emit())
	elf_visual.hit_reaction_finished.connect(func(): hit_reaction_finished.emit())
	elf_visual.death_animation_finished.connect(func(): death_animation_finished.emit())


func _on_visual_animation_started(animation_name: StringName) -> void:
	animation_started.emit(animation_name)


func _on_visual_animation_finished(animation_name: StringName) -> void:
	animation_finished.emit(animation_name)
	if animation_name == ElfVisual3D.ANIM_HIT and _visual_priority == VisualPriority.HIT:
		_visual_priority = VisualPriority.IDLE
	elif animation_name in [ElfVisual3D.ANIM_CAST_FULL, ElfVisual3D.ANIM_CAST_END] \
			and _visual_priority == VisualPriority.CAST:
		_visual_priority = VisualPriority.IDLE
