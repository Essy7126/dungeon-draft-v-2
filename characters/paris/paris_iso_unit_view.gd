class_name ParisIsoUnitView
extends PhilosopherMageIsoUnitView

signal transformation_finished

const TRANSFORMATION_FX := preload("res://vfx/paris/paris_spell_sprite_vfx.gd")
const EFFECTS_PATH := "res://assets/vfx/paris/sprites_v1/effects.tres"
const PARIS_CAST_SPELLS := [&"paris_vortex_arrow", &"paris_vortex_step", &"paris_infernal_sweep", &"paris_infernal_pull"]

var _spectral_frames: SpriteFrames
var _infernal_frames: SpriteFrames
var _transformation_frames: SpriteFrames
var _combat_form: StringName = &"spectral"
var _requested_form: StringName = &""
var _transformation_pending := false
var _transformation_elapsed := 0.0
var _transformation_count := 0
var _transformation_fx: Node


func configure_profile(profile: PhilosopherSpriteVisualProfile) -> bool:
	var paris_profile := profile as ParisSpriteVisualProfile
	if paris_profile == null:
		return false
	_infernal_frames = _load_frames(paris_profile.infernal_frames, paris_profile.infernal_frames_path)
	_transformation_frames = _load_frames(paris_profile.transformation_frames, paris_profile.transformation_frames_path)
	if not super.configure_profile(profile):
		return false
	_spectral_frames = _frames
	_last_error = paris_profile.validation_error(_infernal_frames)
	if _last_error == &"":
		_last_error = paris_profile.transformation_validation_error(_transformation_frames)
	_configured = _last_error == &""
	animated_sprite.visible = _configured
	if _configured:
		_select_form_frames(_authoritative_form())
	return _configured


func bind_unit(unit: Unit) -> void:
	super.bind_unit(unit)
	_transformation_count = 0
	_combat_form = _authoritative_form()
	if is_instance_valid(_unit):
		_unit.combat_form_changed.connect(_on_combat_form_changed)
	if _configured:
		_select_form_frames(_combat_form)


func advance_simulation(seconds: float) -> void:
	if _closing:
		return
	if _dead:
		super.advance_simulation(seconds)
		return
	if _transformation_pending:
		_advance_transformation(maxf(0, seconds))
		return
	if _requested_form != &"" and not _action_pending:
		_begin_transformation()
		return
	super.advance_simulation(seconds)
	if _requested_form != &"" and not _action_pending and not _dead:
		_begin_transformation()


func set_facing_label(direction: String) -> void:
	if _transformation_pending:
		if direction.to_upper() in DIRECTIONS:
			_queued_facing = direction.to_upper()
		return
	super.set_facing_label(direction)


func get_spell_animation_stem(spell: Spell) -> String:
	return "cast" if spell != null and spell.get_effective_spell_id() in PARIS_CAST_SPELLS else "attack"


func play_cast() -> bool:
	return _begin_action(&"cast", "cast")


func is_transformation_pending() -> bool:
	return _transformation_pending or _requested_form != &""


func get_default_cast_effect_origin() -> Vector2:
	var profile := sprite_profile as ParisSpriteVisualProfile
	if profile != null:
		return profile.release_origin(_combat_form, _facing, _stem, _pending_action_id)
	return super.get_default_cast_effect_origin()


func get_visual_runtime_state() -> Dictionary:
	var state := super.get_visual_runtime_state()
	var profile := sprite_profile as ParisSpriteVisualProfile
	if profile != null:
		state["frames_path"] = profile.transformation_frames_path if _transformation_pending \
			else profile.infernal_frames_path if _combat_form == &"infernal" else profile.sprite_frames_path
	state.merge({
		"combat_form": String(_combat_form), "pending_combat_form": String(_requested_form),
		"transformation_pending": is_transformation_pending(),
		"transformation_elapsed": _transformation_elapsed,
		"transformation_count": _transformation_count,
		"authored_view": "E" if _facing in ["E", "S"] else "N",
		"mirrored_view": _facing in ["S", "W"],
	})
	return state


func cancel_pending_visual_actions() -> void:
	var was_transforming := is_transformation_pending()
	_clear_transformation_effect()
	_transformation_pending = false
	_requested_form = &""
	_transformation_elapsed = 0.0
	if _configured and is_instance_valid(animated_sprite):
		_select_form_frames(_authoritative_form())
	super.cancel_pending_visual_actions()
	if was_transforming:
		transformation_finished.emit()


func play_death() -> bool:
	if _dead or _closing:
		return false
	# The surviving phase is authoritative, even if death interrupts its reveal.
	# No transformation callback may resurrect the sprite after this point.
	cancel_pending_visual_actions()
	return super.play_death()


func _can_act() -> bool:
	return super._can_act() and not is_transformation_pending()


func _on_combat_form_changed(unit: Unit, _old_form: StringName, new_form: StringName) -> void:
	if unit != _unit or _closing or _dead or not unit.is_alive \
			or new_form == _combat_form or new_form == _requested_form:
		return
	_requested_form = new_form
	if not _action_pending:
		_begin_transformation()


func _begin_transformation() -> void:
	if _requested_form == &"" or _dead or _closing or not _configured:
		return
	_reaction_pending = false
	_movement_active = false
	_movement_feedback_owned = false
	_apply_queued_facing()
	_record_parent_position()
	_transformation_pending = true
	_transformation_elapsed = 0.0
	_transformation_count += 1
	_frames = _transformation_frames
	animated_sprite.sprite_frames = _frames
	_stem = "transform"
	_sample_normalized("transform", 0)
	_reset_clock()
	_play_transformation_effect()


func _advance_transformation(delta: float) -> void:
	_transformation_elapsed += delta
	var profile := sprite_profile as ParisSpriteVisualProfile
	var duration := profile.transformation_duration_seconds
	_sample_normalized("transform", _transformation_elapsed / duration)
	if _transformation_elapsed + 0.0000001 < duration:
		return
	_clear_transformation_effect()
	var target := _requested_form
	_transformation_pending = false
	_requested_form = &""
	_apply_queued_facing()
	_select_form_frames(target)
	_record_parent_position()
	transformation_finished.emit()


func _select_form_frames(form: StringName) -> void:
	_combat_form = &"infernal" if form == &"infernal" else &"spectral"
	var bank := _infernal_frames if _combat_form == &"infernal" else _spectral_frames
	if bank == null or not is_instance_valid(animated_sprite):
		return
	_frames = bank
	animated_sprite.sprite_frames = bank
	if not _dead:
		_hold_idle_pose()


func _authoritative_form() -> StringName:
	return _unit.combat_form_id if is_instance_valid(_unit) else _combat_form


func _load_frames(candidate: SpriteFrames, path: String) -> SpriteFrames:
	if candidate != null:
		return candidate
	return load(path) as SpriteFrames if ResourceLoader.exists(path) else null


func _disconnect_unit() -> void:
	if is_instance_valid(_unit) and _unit.combat_form_changed.is_connected(_on_combat_form_changed):
		_unit.combat_form_changed.disconnect(_on_combat_form_changed)
	super._disconnect_unit()


func _play_transformation_effect() -> void:
	_clear_transformation_effect()
	if not is_instance_valid(_unit) or not ResourceLoader.exists(EFFECTS_PATH):
		return
	var frames := load(EFFECTS_PATH) as SpriteFrames
	if frames == null:
		return
	var effect := TRANSFORMATION_FX.new()
	add_child(effect)
	_transformation_fx = effect
	var targets: Array[Vector2] = [global_position]
	effect.configure(frames, &"paris_infernal_form", global_position, targets, 112.0 * absf(global_scale.x))
	effect.start_transformation(_unit, self, (sprite_profile as ParisSpriteVisualProfile).transformation_duration_seconds)


func _clear_transformation_effect() -> void:
	if is_instance_valid(_transformation_fx):
		_transformation_fx.cancel()
	_transformation_fx = null


func _sample_weighted_clip(clip: StringName, phase: float) -> void:
	super._sample_weighted_clip(clip, phase)
	_apply_authored_view_mirror()


func _hold_idle_pose() -> void:
	super._hold_idle_pose()
	_apply_authored_view_mirror()


func _apply_authored_view_mirror() -> void:
	if is_instance_valid(animated_sprite):
		# S reuses the authored E view; W reuses N. The centered horizontal
		# ground anchor keeps the same map cell while the texture is flipped.
		animated_sprite.flip_h = _facing in ["S", "W"]
		animated_sprite.flip_v = false
