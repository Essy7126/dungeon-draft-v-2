class_name PasseRiveIsoUnitView
extends AchillesIsoUnitView

const PASSE_BACKEND := preload("res://characters/achilles/2d/passe_rive_sprite_backend.gd")


func _initialize_sprite_backend() -> void:
	if is_instance_valid(sprite_backend) or _closing:
		return
	sprite_backend = PASSE_BACKEND.new() as AchillesSprite2DBackend
	sprite_backend.name = "Sprite2DBackend"
	add_child(sprite_backend)
	_connect_backend_signals(sprite_backend)
	sprite_backend.death_pose_finished.connect(_on_sprite_death_pose_finished)
	if not sprite_backend.configure(sprite_profile):
		_record_backend_error(sprite_backend.get_last_error())
		if _action_pending:
			_complete_action_once(ACTION_FALLBACK)
		return
	sprite_backend.set_backend_active(true)
	_active_backend = sprite_backend
	sprite_backend.set_facing_label(_facing)
	if _queued_action_for_backend:
		_queued_action_for_backend = false
		_action_elapsed = 0.0
		if not _play_active_action():
			_complete_action_once(ACTION_FALLBACK)
	elif _movement_active:
		_play_active_movement()
	else:
		_play_active_idle()
	_emit_runtime_state(&"ACHILLES_VISUAL_BACKEND_READY")
