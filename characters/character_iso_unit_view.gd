class_name CharacterIsoUnitView
extends Node2D

const MovementTiming = preload("res://characters/character_movement_timing.gd")

signal animation_started(animation_name: StringName)
signal animation_finished(animation_name: StringName)
signal cast_release_reached
signal hit_reaction_finished
signal death_animation_finished

const GRID_FOOTPRINT := Vector2(64.0, 32.0)

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

@export_range(-360.0, 360.0, 0.1) var facing_yaw_pos_x := 90.0
@export_range(-360.0, 360.0, 0.1) var facing_yaw_neg_x := -90.0
@export_range(-360.0, 360.0, 0.1) var facing_yaw_pos_y := 0.0
@export_range(-360.0, 360.0, 0.1) var facing_yaw_neg_y := 180.0
@export_range(0.25, 3.0, 0.01) var walk_animation_speed_multiplier: float = 1.0
@export_range(0.25, 3.0, 0.01) var run_animation_speed_multiplier: float = 1.0

@onready var ground_shadow: Polygon2D = $GroundShadow
@onready var render_sprite: Sprite2D = $RenderSprite
@onready var character_viewport: SubViewport = $CharacterViewport
@onready var character_world: Node3D = $CharacterViewport/CharacterWorld
@onready var camera: Camera3D = $CharacterViewport/CharacterWorld/CharacterCamera
@onready var character_pivot: Node3D = $CharacterViewport/CharacterWorld/CharacterPivot
@onready var character_visual: CharacterVisual3D = _find_character_visual()

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
var _foot_realign_pending := false
var _readability_base_shadow_size := Vector2.ZERO
var _readability_outline_enabled := false
var _readability_outline_color := Color.TRANSPARENT
var _readability_outline_width := 1.0


func _ready() -> void:
	if character_visual == null:
		push_error("%s: CharacterVisual3D enfant introuvable." % get_class())
		return
	_apply_viewport_configuration()
	model_scale_multiplier = Vector3.ONE * character_scale
	character_pivot.scale = model_scale_multiplier
	camera.look_at(Vector3(0.0, camera_look_at_height, 0.0), Vector3.UP)
	render_sprite.texture = character_viewport.get_texture()
	render_sprite.centered = false
	render_sprite.scale = Vector2.ONE * render_display_scale
	render_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_update_shadow()
	_readability_base_shadow_size = shadow_size
	_connect_visual_signals()
	_realign_foot_deferred()
	set_process(true)


func _process(delta: float) -> void:
	_track_parent_movement(delta)


func _exit_tree() -> void:
	set_process(false)
	_foot_realign_pending = false
	_disconnect_bound_unit()
	if EventBus.hit_resolved.is_connected(_on_hit_resolved):
		EventBus.hit_resolved.disconnect(_on_hit_resolved)
	if is_instance_valid(character_viewport):
		character_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


func bind_unit(unit: Unit) -> void:
	if _unit == unit:
		return
	_disconnect_bound_unit()
	_unit = unit
	if _unit != null:
		_apply_character_animation_set()
		_unit.moved.connect(_on_bound_unit_moved)
		_unit.died.connect(_on_bound_unit_died)
		if not EventBus.hit_resolved.is_connected(_on_hit_resolved):
			EventBus.hit_resolved.connect(_on_hit_resolved)


## La fiche d'animations du personnage, editee dans le Studio, surcharge la
## fiche canonique du visuel. Sans surcharge, rien ne change.
func _apply_character_animation_set() -> void:
	if _unit == null or _unit.character_data == null \
			or not is_instance_valid(character_visual):
		return
	character_visual.apply_animation_set(_unit.character_data.animation_set)


func _disconnect_bound_unit() -> void:
	if is_instance_valid(_unit):
		var moved_callable := Callable(self, "_on_bound_unit_moved")
		var died_callable := Callable(self, "_on_bound_unit_died")
		if _unit.moved.is_connected(moved_callable):
			_unit.moved.disconnect(moved_callable)
		if _unit.died.is_connected(died_callable):
			_unit.died.disconnect(died_callable)
	_unit = null


func play_idle() -> bool:
	if _death_locked or _visual_priority > VisualPriority.IDLE:
		return false
	return _play_if_new(CharacterVisual3D.ACTION_IDLE, VisualPriority.IDLE, 1.0)


func play_walk(speed_scale: float = 1.0) -> bool:
	if _death_locked or _visual_priority > VisualPriority.MOVEMENT:
		return false
	return _play_if_new(
		CharacterVisual3D.ACTION_WALK,
		VisualPriority.MOVEMENT,
		maxf(speed_scale, 0.01) * walk_animation_speed_multiplier
	)


func play_run(speed_scale: float = 1.0) -> bool:
	if _death_locked or _visual_priority > VisualPriority.MOVEMENT:
		return false
	return _play_if_new(
		CharacterVisual3D.ACTION_RUN,
		VisualPriority.MOVEMENT,
		maxf(speed_scale, 0.01) * run_animation_speed_multiplier
	)


func play_cast() -> bool:
	if _death_locked or _visual_priority > VisualPriority.CAST:
		return false
	return _play_if_new(CharacterVisual3D.ACTION_CAST, VisualPriority.CAST, 1.0)


func play_spell_action(_spell: Spell = null) -> bool:
	return play_cast()


## Contrat commun appele par UnitView lors d'une annulation, d'un timeout ou
## d'une fermeture de salle. Les specialisations peuvent le surcharger pour
## nettoyer leurs accessoires (arc, projectile, etc.).
func cancel_spell_action() -> void:
	_movement_active = false
	_movement_seen_motion = false
	_movement_stable_time = 0.0
	_has_parent_sample = false
	if is_instance_valid(character_visual) and not character_visual.is_death_locked():
		character_visual.reset_to_idle()
		_visual_priority = VisualPriority.IDLE


func cancel_pending_visual_actions() -> void:
	cancel_spell_action()


func synchronize_external_movement() -> void:
	var parent_2d := get_parent() as Node2D
	if parent_2d != null:
		_last_parent_position = parent_2d.position
		_has_parent_sample = true
	_movement_active = false
	_movement_seen_motion = false
	_movement_stable_time = 0.0


func _play_cast_action(animation_name: StringName, play_callable: Callable) -> bool:
	if _death_locked or _visual_priority > VisualPriority.CAST:
		return false
	if character_visual.get_current_animation() == animation_name \
			and character_visual.is_animation_playing(animation_name):
		return false
	_visual_priority = VisualPriority.CAST
	var started = play_callable.call()
	if started is bool and not started:
		_visual_priority = VisualPriority.IDLE
		return false
	return true


func play_hit() -> bool:
	if _death_locked or _visual_priority > VisualPriority.HIT:
		return false
	return _play_if_new(CharacterVisual3D.ACTION_HIT, VisualPriority.HIT, 1.0)


func play_death() -> bool:
	if _death_locked or _visual_priority == VisualPriority.DEATH:
		return false
	_death_locked = true
	_movement_active = false
	return _play_if_new(CharacterVisual3D.ACTION_DEATH, VisualPriority.DEATH, 1.0)


func _play_if_new(action: StringName, priority: VisualPriority, speed_scale: float) -> bool:
	var animation_name := character_visual.get_animation_name_for_action(action)
	if animation_name == &"":
		return false
	if character_visual.get_current_animation() == animation_name \
			and character_visual.is_animation_playing(animation_name):
		return false
	_visual_priority = priority
	match action:
		CharacterVisual3D.ACTION_IDLE:
			return character_visual.play_idle()
		CharacterVisual3D.ACTION_WALK:
			return character_visual.play_walk(speed_scale)
		CharacterVisual3D.ACTION_RUN:
			return character_visual.play_run(speed_scale)
		CharacterVisual3D.ACTION_CAST:
			return character_visual.play_cast_full(speed_scale)
		CharacterVisual3D.ACTION_HIT:
			return character_visual.play_hit(speed_scale)
		CharacterVisual3D.ACTION_DEATH:
			return character_visual.play_death(speed_scale)
	return false


func set_facing(direction: Vector2i) -> void:
	if direction == Vector2i.ZERO:
		return
	var cardinal := direction
	if direction not in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		cardinal = (
			Vector2i(signi(direction.x), 0)
			if absi(direction.x) >= absi(direction.y)
			else Vector2i(0, signi(direction.y))
		)
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
	character_visual.set_socket_debug_visible(visible)


func get_character_visual() -> CharacterVisual3D:
	return character_visual


func get_logical_foot_position() -> Vector2:
	return Vector2.ZERO


func get_projected_foot_pixel() -> Vector2:
	return _foot_pixel


func get_facing_direction() -> Vector2i:
	return _facing


## Presentation locale au billboard. L'origine (0, 0) reste le pied logique ;
## la taille et l'ombre sont appliquees de facon absolue, donc sans cumul.
func set_painted_readability(
		enabled: bool,
		outline_color: Color,
		outline_width_px: float,
		shadow_enabled: bool,
		shadow_scale: float,
		shadow_alpha: float
	) -> void:
	if _readability_base_shadow_size == Vector2.ZERO:
		_readability_base_shadow_size = shadow_size
	shadow_size = _readability_base_shadow_size * shadow_scale
	shadow_opacity = shadow_alpha if enabled and shadow_enabled else 0.28
	_readability_outline_enabled = enabled
	_readability_outline_color = outline_color
	_readability_outline_width = maxf(outline_width_px, 0.5)
	render_sprite.material = null
	queue_redraw()


func _draw() -> void:
	if not _readability_outline_enabled:
		return
	# Deux liseres courts encadrent la silhouette sans retraiter les 768x512
	# pixels du SubViewport. Ils restent derriere le billboard et ne modifient
	# ni sa texture, ni ses animations, ni son point de pied.
	var left := PackedVector2Array([
		Vector2(-10.5, -55.0),
		Vector2(-15.5, -45.0),
		Vector2(-17.0, -29.0),
		Vector2(-13.0, -11.0),
	])
	var right := PackedVector2Array()
	for point in left:
		right.append(Vector2(-point.x, point.y))
	draw_polyline(left, _readability_outline_color, _readability_outline_width, true)
	draw_polyline(right, _readability_outline_color, _readability_outline_width, true)


func get_left_hand_effect_origin() -> Vector2:
	return _project_effect_origin(character_visual.get_left_weapon_mount(), "left mount")


func get_right_hand_effect_origin() -> Vector2:
	return _project_effect_origin(character_visual.get_right_weapon_mount(), "right mount")


func get_default_cast_effect_origin() -> Vector2:
	return _project_effect_origin(character_visual.get_default_cast_mount(), "cast mount")


func _project_effect_origin(mount: Node3D, socket_name: String) -> Vector2:
	var world_position: Vector3
	if is_instance_valid(mount):
		world_position = mount.global_position
	else:
		world_position = character_pivot.to_global(Vector3(0.0, 1.15, 0.0))
		if not _missing_socket_warning_emitted:
			_missing_socket_warning_emitted = true
			push_warning("%s: %s absent; origine de sort repliee pres du torse." % [
				get_class(), socket_name,
			])
	var viewport_pixel := camera.unproject_position(world_position)
	return to_local(render_sprite.to_global(viewport_pixel))


func set_debug_run_for_next_movement(enabled: bool) -> void:
	_debug_run_for_next_movement = enabled


## Demarre le retour visuel avant que la racine UnitView ne quitte sa case.
## Le signal Unit.moved reste un filet de securite pour les autres contextes,
## mais le combat pilote explicitement ce cycle afin d'eviter une case glissee.
func begin_movement_feedback(from_cell: Vector2i, to_cell: Vector2i) -> void:
	if _death_locked or from_cell == to_cell:
		return
	set_facing(to_cell - from_cell)
	_movement_active = true
	_movement_seen_motion = false
	_movement_stable_time = 0.0
	_has_parent_sample = false
	var distance_cells := absi(to_cell.x - from_cell.x) + absi(to_cell.y - from_cell.y)
	var action := (
		CharacterVisual3D.ACTION_RUN
		if _debug_run_for_next_movement
		else CharacterVisual3D.ACTION_WALK
	)
	var source_duration := character_visual.get_animation_length_for_action(action)
	var playback_speed := _movement_playback_speed(
		source_duration,
		distance_cells,
		action == CharacterVisual3D.ACTION_RUN
	)
	if _debug_run_for_next_movement:
		play_run(playback_speed)
	else:
		play_walk(playback_speed)


func cancel_movement_feedback() -> void:
	_movement_active = false
	_movement_seen_motion = false
	_movement_stable_time = 0.0
	_has_parent_sample = false
	if not _death_locked and _visual_priority == VisualPriority.MOVEMENT:
		_visual_priority = VisualPriority.IDLE
		play_idle()


func _on_bound_unit_moved(from_cell: Vector2i, to_cell: Vector2i) -> void:
	if _death_locked:
		return
	if _movement_active:
		set_facing(to_cell - from_cell)
		return
	begin_movement_feedback(from_cell, to_cell)


func _movement_playback_speed(
		loop_duration: float,
		_distance_cells: int,
		running: bool = false
	) -> float:
	return MovementTiming.playback_speed_for_loop(loop_duration, running)


func _on_bound_unit_died(unit: Unit) -> void:
	if unit == _unit:
		play_death()


func _on_hit_resolved(fact: CombatEventFact) -> void:
	if fact.target == _unit \
			and fact.amount_resolved > 0 \
			and _unit != null \
			and _unit.is_alive:
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
	if not is_inside_tree() or _foot_realign_pending:
		return
	var tree := get_tree()
	if tree == null:
		return
	_foot_realign_pending = true
	tree.process_frame.connect(_realign_foot_after_frame, CONNECT_ONE_SHOT)


func _realign_foot_after_frame() -> void:
	_foot_realign_pending = false
	if not is_inside_tree():
		return
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
	character_visual.animation_started.connect(_on_visual_animation_started)
	character_visual.animation_finished.connect(_on_visual_animation_finished)
	character_visual.cast_release_reached.connect(_on_visual_cast_release)
	character_visual.hit_reaction_finished.connect(_on_visual_hit_finished)
	character_visual.death_animation_finished.connect(_on_visual_death_finished)


func _on_visual_animation_started(animation_name: StringName) -> void:
	animation_started.emit(animation_name)


func _on_visual_animation_finished(animation_name: StringName) -> void:
	animation_finished.emit(animation_name)
	if animation_name == character_visual.animation_hit \
			and _visual_priority == VisualPriority.HIT:
		_visual_priority = VisualPriority.IDLE
	elif character_visual.is_cast_animation(animation_name) \
			and _visual_priority == VisualPriority.CAST:
		_visual_priority = VisualPriority.IDLE


func _on_visual_cast_release() -> void:
	cast_release_reached.emit()


func _on_visual_hit_finished() -> void:
	hit_reaction_finished.emit()


func _on_visual_death_finished() -> void:
	death_animation_finished.emit()


func _find_character_visual() -> CharacterVisual3D:
	if character_pivot == null:
		return null
	for child in character_pivot.get_children():
		if child is CharacterVisual3D:
			return child as CharacterVisual3D
	return null
