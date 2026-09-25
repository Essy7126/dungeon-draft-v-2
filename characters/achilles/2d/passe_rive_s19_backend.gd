extends PasseRiveAutoSpriteBackend
## Keeps the established action owner, cancellation and once-only release signal.
const Catalog := preload("passe_rive_s19_catalog.gd")
const Body := preload("passe_rive_s19_body.gd")
var cards_mode := false
var body: Node2D
const HEIGHT := 108.0


func configure(profile: AchillesSpriteVisualProfile) -> bool:
	if not super.configure(profile):
		return false
	body = Body.new()
	body.name = "PaintedS18Body"
	body.scale = Vector2.ONE * HEIGHT / 330.0
	add_child(body)
	body.hide()
	return true


func set_cards_mode(enabled: bool) -> void:
	if cards_mode == enabled or not is_instance_valid(body):
		return
	cancel_action()
	cards_mode = enabled
	animated_sprite.visible = not enabled
	body.visible = enabled
	_hold_idle_pose()


func _action_spec(action_id: StringName, presentation: Dictionary) -> Dictionary:
	if not cards_mode:
		return super._action_spec(action_id, presentation)
	var id := str(presentation.get("spell_id", str(action_id).trim_prefix("cast:")))
	var card := Catalog.card(id)
	if card.is_empty():
		card = Catalog.fallback(id)
	return {
		"stem": card.clip, "duration": card.body_duration_ms / 1000.0,
		"release_seconds": card.confirm_ms / 1000.0,
		"release_frame": int(card.confirm_frame), "legacy_loop": false, "speed": 1.0,
	}


func _show(clip: String, frame: int) -> void:
	if not is_instance_valid(body):
		return
	body.scale.x = (-1.0 if _facing in ["W", "NW", "SW"] else 1.0) * HEIGHT / 330.0
	body.modulate = Color.WHITE
	body.show_frame(clip, frame)


func _select_clip(stem: String) -> void:
	if not cards_mode:
		super._select_clip(stem)
		return
	_show(stem if Catalog.Data.CLIPS.has(stem) else "PR_IDLE", 0)


func _sample_action_at(seconds: float) -> void:
	if not cards_mode:
		super._sample_action_at(seconds)
		return
	_show(_stem, Catalog.frame_at(_stem, seconds))
	body.card = Catalog.card(str(_presentation.get("spell_id", "")))
	body.action_time = seconds * 1000.0
	body.queue_redraw()


func _sample_idle() -> void:
	if not cards_mode:
		super._sample_idle()
		return
	body.card = {}
	_show("PR_IDLE", Catalog.frame_at("PR_IDLE", fposmod(_idle_elapsed, Catalog.duration("PR_IDLE"))))


func _sample_walk() -> void:
	if not cards_mode:
		super._sample_walk()
		return
	body.card = {}
	var segment := _profile.run_segment_duration_seconds if _running else _profile.walk_segment_duration_seconds
	_show("PR_WALK", Catalog.frame_at("PR_WALK", fposmod(_walk_elapsed / (2.0 * segment), 1.0) * Catalog.duration("PR_WALK")))


func advance_ground_distance(distance: float) -> void:
	if not cards_mode:
		super.advance_ground_distance(distance)
		return
	if not _can_play_loop() or _stem not in ["walk", "run"]:
		return
	_distance_driven_move = true
	_ground_phase = fposmod(_ground_phase + maxf(distance, 0.0) / 82.0, 1.0)
	body.card = {}
	_show("PR_WALK", Catalog.frame_at("PR_WALK", _ground_phase * Catalog.duration("PR_WALK")))


func update_movement_stride(step_index: int, progress: float) -> void:
	if not cards_mode:
		super.update_movement_stride(step_index, progress)
	elif _can_play_loop() and _stem in ["walk", "run"]:
		_distance_driven_move = true
		_show("PR_WALK", Catalog.frame_at("PR_WALK", fposmod((step_index + progress) * 0.5, 1.0) * Catalog.duration("PR_WALK")))


func _sample_normalized(stem: String, progress: float) -> void:
	if not cards_mode:
		super._sample_normalized(stem, progress)
		return
	# No new hit/death drawings were approved: keep the same identity and use a
	# short hit tint / death fade until dedicated poses are authored.
	body.card = {}
	_show("PR_IDLE", 0)
	if stem == "death":
		body.modulate.a = 1.0 - clampf(progress, 0.0, 1.0)
	else:
		body.modulate = Color.WHITE.lerp(Color(1.0, 0.55, 0.5), sin(clampf(progress, 0.0, 1.0) * PI) * 0.6)


func cancel_action() -> void:
	super.cancel_action()
	if is_instance_valid(body):
		body.card = {}
		body.queue_redraw()


func get_vfx_origin() -> Vector2:
	if not cards_mode:
		return super.get_vfx_origin()
	return Vector2(-23 if _facing in ["W", "NW", "SW"] else 23, -65)


func get_runtime_state() -> Dictionary:
	var state := super.get_runtime_state()
	state["s19_enabled"] = cards_mode
	if cards_mode and is_instance_valid(body):
		state["animation"] = body.current_clip
		state["frame"] = body.current_frame
		state["mirrored"] = body.scale.x < 0
	return state
