class_name AchillesAutoSpriteBackend
extends AchillesSprite2DBackend

## Same action owner and combat markers; only supplied poses and clocks differ.
var _idle_elapsed := 0.0
var _running := false


func set_facing_label(direction: String) -> void:
	var next := direction.to_upper()
	if (
		next not in AchillesAutoSpriteProfile.DIRECTIONS or _action_pending
		or _dead or _reaction_pending or _dash_landing_pending
	):
		return
	if next == _facing:
		return
	_facing = next
	if not _active:
		return
	if _stem in ["walk", "run"]:
		_select_clip(_stem)
		if _distance_driven_move:
			update_movement_stride(_walk_step_index, _walk_step_progress)
		else:
			_sample_walk()
	else:
		_hold_idle_pose()


func advance_simulation(seconds: float) -> void:
	if (
		_active and not _shutdown and not _dead and not _action_pending
		and not _reaction_pending and not _dash_landing_pending
	):
		if _stem == "idle":
			_idle_elapsed += maxf(seconds, 0.0)
			_sample_idle()
		elif _stem == "run" and not _distance_driven_move:
			_walk_elapsed += maxf(seconds, 0.0) * _walk_speed_scale
			_sample_walk()
	super.advance_simulation(seconds)


func play_move(direction := "S", running := false) -> bool:
	if not _can_play_loop():
		return false
	_cancel_dash_landing()
	_cancel_reaction()
	set_facing_label(direction)
	var next := "run" if running else "walk"
	_running = running
	if _stem == next:
		return true
	_stem = next
	_distance_driven_move = false
	_walk_elapsed = 0.0
	_walk_speed_scale = 1.0
	_walk_step_index = 0
	_walk_step_progress = 0.0
	animated_sprite.speed_scale = 1.0
	_select_clip(_stem)
	_sample_walk()
	_reset_clock()
	return true


func update_movement_stride(step_index: int, progress: float) -> void:
	if not _can_play_loop() or _stem not in ["walk", "run"]:
		return
	_distance_driven_move = true
	_walk_step_index = step_index
	_walk_step_progress = clampf(progress, 0.0, 1.0)
	var clip := StringName(_stem + "_" + _facing)
	# Half a cycle per cell, including odd frame counts in the native sprint.
	var phase := fposmod((float(step_index) + _walk_step_progress) * 0.5, 1.0)
	_sample_weighted_clip(clip, phase * _clip_weight(clip))


func _sample_walk() -> void:
	var clip := StringName(_stem + "_" + _facing)
	var segment := _profile.run_segment_duration_seconds if _running else _profile.walk_segment_duration_seconds
	_sample_weighted_clip(clip, fposmod(_walk_elapsed / (2.0 * segment), 1.0) * _clip_weight(clip))


func _hold_idle_pose() -> void:
	if _stem != "idle":
		_idle_elapsed = 0.0
	_distance_driven_move = false
	_stem = "idle"
	animated_sprite.speed_scale = 1.0
	_sample_idle()


func _sample_idle() -> void:
	var clip := StringName("idle_" + _facing)
	_sample_weighted_clip(
		clip,
		fposmod(_idle_elapsed * _frames.get_animation_speed(clip), _clip_weight(clip)),
	)


func _action_spec(action_id: StringName, presentation: Dictionary) -> Dictionary:
	var local := presentation.duplicate(true)
	var id := String(local.get("spell_id", String(action_id).trim_prefix("cast:")))
	if id in ["exp_crochet", "exp_crochet_mutation", "exp_crochet_legend"]:
		local["animation_stem"] = &"hook"
	return super._action_spec(action_id, local)


func _sample_action_at(seconds: float) -> void:
	if _stem == "dash" and seconds >= _release_time:
		var clip := StringName("run_" + _facing)
		var phase := fposmod(
			(seconds - _release_time) / (2.0 * _profile.run_segment_duration_seconds),
			1.0,
		)
		_sample_weighted_clip(clip, phase * _clip_weight(clip))
	else:
		super._sample_action_at(seconds)
