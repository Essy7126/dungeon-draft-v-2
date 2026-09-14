class_name PasseRiveAutoSpriteBackend
extends AchillesAutoSpriteBackend

const MANIFEST := "res://assets/characters/PasseRive/autosprite_v1/manifest.json"
const COMBAT_MANIFEST := "res://assets/characters/PasseRive/combat_v2/manifest.json"
const LANDING_SECONDS := 0.30
var _geometry: Dictionary = { }
var _dodging := false
var _ground_phase := 0.0
var _combat_mode := false


func configure(profile: AchillesSpriteVisualProfile) -> bool:
	var metadata: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if not metadata is Dictionary or not metadata.get("geometry") is Dictionary:
		_last_error = &"PASSE_RIVE_GEOMETRY_MISSING"
		return false
	_geometry = metadata.geometry
	var combat: Variant = JSON.parse_string(FileAccess.get_file_as_string(COMBAT_MANIFEST))
	if not combat is Dictionary or not combat.get("geometry") is Dictionary:
		_last_error = &"PASSE_RIVE_COMBAT_GEOMETRY_MISSING"
		return false
	_geometry.merge(combat.geometry, true)
	return super.configure(profile)


func set_combat_mode(enabled: bool) -> void:
	_combat_mode = enabled
	if _active and _can_play_loop() and _stem == "idle":
		_sample_idle()


func _sample_idle() -> void:
	if _combat_mode:
		_sample_weighted_clip(StringName("combat_idle_" + _facing), 0.0)
	else:
		super._sample_idle()


func _select_clip(stem: String) -> void:
	super._select_clip(stem)
	_apply_contact()


func _sample_weighted_clip(clip: StringName, phase: float) -> void:
	super._sample_weighted_clip(clip, phase)
	_apply_contact()


func _apply_contact() -> void:
	if _profile == null or not is_instance_valid(animated_sprite):
		return
	var geometry: Dictionary = _geometry.get(String(animated_sprite.animation), { })
	if geometry.is_empty():
		return
	animated_sprite.offset = -Vector2(geometry.anchor[0], geometry.anchor[1])
	animated_sprite.scale = Vector2.ONE * _profile.display_scale * float(geometry.scale)


static func action_for(action_id: StringName, presentation: Dictionary) -> String:
	var id := String(presentation.get("spell_id", String(action_id).trim_prefix("cast:")))
	var stem := String(presentation.get("animation_stem", "attack"))
	if String(action_id).begins_with("preview:"):
		stem = String(action_id).trim_prefix("preview:")
	if stem == "dash" or id in ["achilles_advance", "achilles_fulminant_dash"]:
		return "dash"
	if stem == "guard" or id in ["achilles_guard", "achilles_bronze_guard"]:
		return "dodge"
	if stem == "sweep" or id.begins_with("exp_moisson") or id.begins_with("exp_fauchage"):
		return "jump"
	if stem in ["jump", "dodge", "bow_quick", "bow_charged", "bow_air"]:
		return stem
	if stem == "volley":
		return "bow_air"
	if stem in ["bow_piercing", "bow_death"]:
		return "bow_charged"
	return "bow_quick"


func _action_spec(action_id: StringName, presentation: Dictionary) -> Dictionary:
	var stem := action_for(action_id, presentation)
	if stem not in ["bow_quick", "bow_charged", "bow_air", "jump", "dodge", "dash"]:
		stem = "bow_quick"
	var settings := _profile.get_action_clip_settings(stem)
	return {
		"stem": stem,
		"duration": settings.duration_seconds,
		"release_seconds": settings.release_seconds,
		"release_frame": settings.release_frame,
		"legacy_loop": false,
		"speed": 1.0,
	}


func _sample_action_at(seconds: float) -> void:
	if _stem == "dash":
		var phase := 2.0 * seconds / maxf(_release_time, 0.0001)
		if seconds >= _release_time:
			# Native charge loop; grounded recovery belongs to actual arrival.
			phase = 2.0 + fposmod((seconds - _release_time) * 25.0, 12.0)
		_sample_weighted_clip(StringName("dash_" + _facing), phase)
	else:
		# Shared weighted sampling publishes the exact release drawing even when
		# one busy frame crosses the complete anticipation and recovery.
		super._sample_action_at(seconds)


func finish_dash_landing(direction := "S") -> bool:
	var accepted := super.finish_dash_landing(direction)
	if accepted:
		_sample_weighted_clip(StringName("dash_" + _facing), 14.0)
	return accepted


func advance_simulation(seconds: float) -> void:
	if _active and not _shutdown and _dash_landing_pending:
		_dash_landing_elapsed += maxf(seconds, 0.0)
		_sample_weighted_clip(
			StringName("dash_" + _facing),
			14.0 + 11.0 * _dash_landing_elapsed / LANDING_SECONDS,
		)
		if _dash_landing_elapsed >= LANDING_SECONDS:
			_cancel_dash_landing()
			_hold_idle_pose()
		return
	super.advance_simulation(seconds)


func play_hit(direction := "S") -> bool:
	if _stem == "run":
		return false
	_dodging = false
	return super.play_hit(direction)


func play_dodge(direction := "S") -> bool:
	var accepted := play_hit(direction)
	if accepted and _reaction_pending:
		_dodging = true
		_stem = "dodge"
		_sample_normalized("hit", 0.0)
	return accepted


func _sample_normalized(stem: String, progress: float) -> void:
	super._sample_normalized("dodge" if stem == "hit" and _dodging else stem, progress)


func play_move(direction := "S", running := false) -> bool:
	var was_moving := _stem in ["walk", "run"]
	var accepted := super.play_move(direction, running)
	if accepted and not was_moving:
		_ground_phase = 0.0
	return accepted


func advance_ground_distance(distance: float) -> void:
	if not _can_play_loop() or _stem not in ["walk", "run"]:
		return
	_distance_driven_move = true
	# Source stride in the unprojected floor plane, scaled with the actor.
	var cycle := (300.0 if _running else 180.0) * _profile.display_scale
	_ground_phase = fposmod(_ground_phase + maxf(distance, 0.0) / cycle, 1.0)
	var clip := StringName(_stem + "_" + _facing)
	_sample_weighted_clip(clip, _ground_phase * _clip_weight(clip))


func set_facing_label(direction: String) -> void:
	super.set_facing_label(direction)
	if _distance_driven_move and _stem in ["walk", "run"]:
		advance_ground_distance(0.0)
