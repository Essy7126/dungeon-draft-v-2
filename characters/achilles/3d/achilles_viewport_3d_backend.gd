class_name AchillesViewport3DBackend
extends Node2D

signal backend_ready
signal backend_failed(error_code: StringName)
signal action_started(action_name: StringName)
signal action_release_reached
signal action_finished(action_name: StringName)

const RENDER_DISPLAY_SIZE := 96.0
const WARMUP_FRAME_COUNT := 2

@onready var rendered_sprite: Sprite2D = $RenderedSprite
@onready var character_viewport: SubViewport = $AchillesSubViewport
@onready var render_world: Node3D = $AchillesSubViewport/RenderWorld
@onready var camera: Camera3D = $AchillesSubViewport/RenderWorld/Camera3D

var _profile: AchillesVisualProfile = null
var _visual: Achilles3DVisual = null
var _active := false
var _ready_for_render := false
var _shutdown := false
var _foot_pixel := Vector2.ZERO
var _facing := "S"
var _last_error_code: StringName = &""
var _foot_realign_pending := false
var _warmup_generation := 0


func _ready() -> void:
	set_process_input(false)
	set_process_unhandled_input(false)
	set_process_unhandled_key_input(false)
	character_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	rendered_sprite.texture = character_viewport.get_texture()
	rendered_sprite.centered = false


func _exit_tree() -> void:
	shutdown()


func configure(profile: AchillesVisualProfile) -> bool:
	if _shutdown:
		return false
	if is_instance_valid(_visual) or _ready_for_render:
		_last_error_code = &"SUBVIEWPORT_BACKEND_ALREADY_CONFIGURED"
		return false
	_profile = profile
	if _profile == null or not _profile.is_character_only_valid():
		_fail_backend(&"INVALID_CHARACTER_ONLY_PROFILE")
		return false
	_apply_profile_configuration()
	if _profile.character_scene == null:
		_fail_backend(&"CHARACTER_VISUAL_SCENE_MISSING")
		return false
	var candidate := _profile.character_scene.instantiate()
	if not candidate is Achilles3DVisual:
		if candidate != null:
			candidate.free()
		_fail_backend(&"CHARACTER_VISUAL_SCENE_INVALID")
		return false
	_visual = candidate as Achilles3DVisual
	_visual.name = "Achilles3DVisual"
	render_world.add_child(_visual)
	_visual.setup_completed.connect(_on_visual_setup_completed, CONNECT_ONE_SHOT)
	_visual.setup_failed.connect(_on_visual_setup_failed, CONNECT_ONE_SHOT)
	_visual.action_started.connect(_on_visual_action_started)
	_visual.action_release_reached.connect(_on_visual_action_release)
	_visual.action_finished.connect(_on_visual_action_finished)
	character_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	return _visual.initialize_from_profile(_profile)


func set_backend_active(active: bool) -> void:
	_active = active and _ready_for_render and not _shutdown
	visible = _active
	character_viewport.render_target_update_mode = (
		SubViewport.UPDATE_ALWAYS if _active else SubViewport.UPDATE_DISABLED
	)
	if _active:
		_realign_foot_deferred()


func is_backend_active() -> bool:
	return _active and visible and _ready_for_render and not _shutdown


func is_ready_for_render() -> bool:
	return _ready_for_render


func set_facing_label(direction: String) -> void:
	_facing = direction.to_upper()
	if is_instance_valid(_visual):
		_visual.set_facing_label(_facing)


func get_facing_label() -> String:
	return _facing


func play_idle(_direction := "S") -> bool:
	return is_instance_valid(_visual) and _visual.play_idle()


func play_move(_direction := "S") -> bool:
	return is_instance_valid(_visual) and _visual.play_move()


func play_action(_direction := "S") -> bool:
	return is_instance_valid(_visual) and _visual.play_action()


func cancel_action() -> void:
	if is_instance_valid(_visual):
		_visual.cancel_action()


func set_viewport_resolution(resolution: int) -> bool:
	var requested := Vector2i(resolution, resolution)
	if requested not in AchillesVisualProfile.SUPPORTED_VIEWPORT_SIZES:
		return false
	character_viewport.size = requested
	_update_render_scale()
	_realign_foot_deferred()
	return true


func get_vfx_origin() -> Vector2:
	if not is_instance_valid(_visual):
		return Vector2(0.0, -92.0)
	var marker := _visual.vfx_marker
	if not is_instance_valid(marker):
		return Vector2(0.0, -92.0)
	var viewport_pixel := camera.unproject_position(marker.global_position)
	return rendered_sprite.position + viewport_pixel * rendered_sprite.scale


func get_projected_foot_pixel() -> Vector2:
	return _foot_pixel


func get_achilles_visual() -> Achilles3DVisual:
	return _visual if is_instance_valid(_visual) else null


func get_last_error_code() -> StringName:
	return _last_error_code


func shutdown() -> void:
	if _shutdown:
		return
	_shutdown = true
	_warmup_generation += 1
	_foot_realign_pending = false
	_active = false
	_ready_for_render = false
	visible = false
	if is_instance_valid(character_viewport):
		character_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if is_instance_valid(rendered_sprite):
		rendered_sprite.texture = null
	if is_instance_valid(_visual):
		_visual.cancel_action()
		_visual.free()
	_visual = null


func is_shutdown() -> bool:
	return _shutdown


func _apply_profile_configuration() -> void:
	character_viewport.size = _profile.validated_viewport_size()
	camera.transform = _profile.camera_transform
	if camera.position.length_squared() < 0.01:
		camera.position = Vector3(3.5, 2.8, 3.5)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = _profile.orthographic_size
	camera.look_at(Vector3(0.0, 0.85, 0.0), Vector3.UP)
	_update_render_scale()


func _update_render_scale() -> void:
	var longest_side := maxi(character_viewport.size.x, character_viewport.size.y)
	var display_scale := RENDER_DISPLAY_SIZE / float(maxi(longest_side, 1))
	rendered_sprite.scale = Vector2.ONE * display_scale


func _on_visual_setup_completed() -> void:
	if _shutdown or not is_instance_valid(_visual):
		return
	var texture := character_viewport.get_texture()
	if texture == null:
		_fail_backend(&"SUBVIEWPORT_TEXTURE_MISSING")
		return
	rendered_sprite.texture = texture
	_visual.set_facing_label(_facing)
	_warmup_generation += 1
	character_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_complete_warmup_after_frames(_warmup_generation)


func _complete_warmup_after_frames(generation: int) -> void:
	var tree := get_tree()
	if tree == null:
		_fail_backend(&"SUBVIEWPORT_WARMUP_UNAVAILABLE")
		return
	for _frame in range(WARMUP_FRAME_COUNT):
		await tree.process_frame
		if _shutdown or generation != _warmup_generation \
				or not is_instance_valid(_visual):
			return
	_ready_for_render = true
	character_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_realign_foot_deferred()
	backend_ready.emit()


func _on_visual_setup_failed(error_code: StringName) -> void:
	_fail_backend(error_code)


func _on_visual_action_started(action_name: StringName) -> void:
	action_started.emit(action_name)


func _on_visual_action_release() -> void:
	action_release_reached.emit()


func _on_visual_action_finished(action_name: StringName) -> void:
	action_finished.emit(action_name)


func _realign_foot_deferred() -> void:
	if not is_inside_tree() or not _ready_for_render or _foot_realign_pending:
		return
	var tree := get_tree()
	if tree == null:
		return
	_foot_realign_pending = true
	tree.process_frame.connect(_realign_foot_after_frame, CONNECT_ONE_SHOT)


func _realign_foot_after_frame() -> void:
	_foot_realign_pending = false
	if _shutdown or not is_instance_valid(_visual):
		return
	_foot_pixel = camera.unproject_position(_visual.foot_marker.global_position)
	rendered_sprite.position = -_foot_pixel * rendered_sprite.scale


func _fail_backend(error_code: StringName) -> void:
	_warmup_generation += 1
	_last_error_code = error_code
	_ready_for_render = false
	_active = false
	visible = false
	if is_instance_valid(character_viewport):
		character_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if is_instance_valid(rendered_sprite):
		rendered_sprite.texture = null
	if is_instance_valid(_visual):
		if _visual.get_parent() != null:
			_visual.get_parent().remove_child(_visual)
		_visual.queue_free()
	_visual = null
	backend_failed.emit(error_code)
