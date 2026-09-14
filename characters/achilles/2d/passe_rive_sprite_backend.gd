class_name PasseRiveSpriteBackend
extends AchillesSprite2DBackend

## Presentation-only adapter: reuse combat's release/cancel and distance-driven walk.
const MANIFEST_PATH := "res://assets/characters/Achilles/passe_rive_iso_v1/manifest.json"
const EFFECT_SCRIPT := preload("res://characters/achilles/2d/passe_rive_motion_effects.gd")
var motion_data: Dictionary = {}
var motion_actions: Dictionary = {}
var rear_effects: Node2D
var front_effects: Node2D
var rest_action: String = ""
var charge_material: ShaderMaterial


func configure(profile: AchillesSpriteVisualProfile) -> bool:
	if not super.configure(profile):
		return false
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not raw is Dictionary:
		_last_error = &"PASSE_RIVE_MANIFEST_INVALID"
		return false
	motion_data = raw
	for definition: Dictionary in motion_data.actions:
		motion_actions[String(definition.id)] = definition
	rear_effects = _add_effect_layer(false)
	move_child(rear_effects, animated_sprite.get_index())
	front_effects = _add_effect_layer(true)
	charge_material = ShaderMaterial.new()
	charge_material.shader = load("res://characters/achilles/2d/passe_rive_charge.gdshader") as Shader
	animated_sprite.material = charge_material
	return true


func _add_effect_layer(front: bool) -> Node2D:
	var layer := Node2D.new()
	layer.set_script(EFFECT_SCRIPT)
	layer.set("backend", self)
	layer.set("front", front)
	add_child(layer)
	return layer


func _action_spec(action_id: StringName, presentation: Dictionary) -> Dictionary:
	var chosen := action_for(action_id, presentation)
	var definition: Dictionary = motion_actions.get(chosen, {})
	if definition.is_empty():
		return super._action_spec(action_id, presentation)
	var release_frame := 0
	var cursor := 0.0
	for frame: Dictionary in definition.frames:
		if cursor + 0.0001 >= float(definition.event_ms):
			break
		cursor += float(frame.duration_ms)
		release_frame += 1
	return {
		"stem": chosen,
		"duration": 1.2 if chosen == "dash" else float(definition.total_ms) / 1000.0,
		"release_seconds": float(definition.event_ms) / 1000.0,
		"release_frame": release_frame,
		"legacy_loop": false,
		"speed": 1.0,
	}


static func action_for(action_id: StringName, presentation: Dictionary) -> String:
	var id := String(presentation.get("spell_id", String(action_id).trim_prefix("cast:")))
	if String(action_id).begins_with("preview:"):
		return String(action_id).trim_prefix("preview:")
	if id.begins_with("exp_moisson"):
		return "vital_harvest"
	if id.begins_with("exp_fauchage"):
		return "fauche"
	if id.begins_with("exp_heurt"):
		return "bash"
	if id.begins_with("exp_rupture"):
		return "ivory_bow"
	if id.begins_with("exp_marque") or id == "exp_tir_de_guet":
		return "sky_bow"
	var requested := String(presentation.get("animation_stem", "attack"))
	if requested == "volley":
		return "sky_bow"
	if requested in ["bow_piercing", "bow_death"]:
		return "ivory_bow"
	if requested == "bow" or id == "achilles_pelion_shot":
		return "shot"
	if requested in ["dash", "guard", "sweep"]:
		return requested
	if id in ["achilles_fulminant_dash", "achilles_advance"]:
		return "dash"
	if id in ["achilles_bronze_guard", "achilles_guard"]:
		return "guard"
	return "strike"


func play_action(direction := "S", action_id: StringName = &"cast", presentation: Dictionary = {}) -> bool:
	var accepted := super.play_action(direction, action_id, presentation)
	if accepted:
		rest_action = _stem if _stem in ["sky_bow", "ivory_bow", "vital_harvest", "fauche"] else ""
	return accepted


func play_move(direction := "S", running := false) -> bool:
	if _can_play_loop():
		rest_action = ""
	return super.play_move(direction, running)


func _sample_action_at(seconds: float) -> void:
	if _stem == "dash":
		animated_sprite.animation = StringName("dash_" + _facing)
		animated_sprite.set_frame_and_progress(0 if seconds < _release_time else 1, 0.0)
	else:
		super._sample_action_at(seconds)
	_refresh_motion()


func finish_dash_landing(direction := "S") -> bool:
	var accepted := super.finish_dash_landing(direction)
	if accepted:
		animated_sprite.set_frame_and_progress(2, 0.0)
	return accepted


func _hold_idle_pose() -> void:
	super._hold_idle_pose()
	var clip := StringName(rest_action + "_rest_" + _facing)
	if rest_action != "" and _frames.has_animation(clip):
		animated_sprite.animation = clip
		animated_sprite.set_frame_and_progress(0, 0.0)
	_refresh_motion()


func cancel_action() -> void:
	rest_action = ""
	super.cancel_action()
	_refresh_motion()


func get_motion_state() -> Dictionary:
	if not _action_pending or not motion_actions.has(_stem):
		return {}
	return {
		"definition": motion_actions[_stem], "time": _action_elapsed,
		"frame": animated_sprite.frame, "facing": _facing,
		"scale": _profile.display_scale,
		"effects": motion_data.get("effects", {}).get(_stem + "_" + _facing, {}),
	}


func _refresh_motion() -> void:
	if not is_instance_valid(animated_sprite):
		return
	animated_sprite.position = Vector2.ZERO
	if is_instance_valid(charge_material):
		charge_material.set_shader_parameter("tremor_pixels", 0.0)
	var state := get_motion_state()
	if not state.is_empty():
		if _stem == "vital_harvest":
			animated_sprite.position.y = -lift_at(_action_elapsed) * _profile.display_scale
		if _stem == "ivory_bow" and _action_elapsed >= 0.62 and _action_elapsed < 1.62 and charge_material != null:
			var config: Dictionary = state.effects.get("tremor", {})
			if not config.is_empty():
				var texture := _frames.get_frame_texture(animated_sprite.animation, animated_sprite.frame) as AtlasTexture
				charge_material.set_shader_parameter("frame_origin", texture.region.position - texture.margin.position)
				charge_material.set_shader_parameter("arm_center", Vector2(config.center[0], config.center[1]))
				charge_material.set_shader_parameter("arm_radius", Vector2(config.radius[0], config.radius[1]))
				charge_material.set_shader_parameter("tremor_pixels", (0.25 + 0.75 * (_action_elapsed - 0.62)) * 1.7 * (0.72 * sin(_action_elapsed * 73) + 0.28 * sin(_action_elapsed * 109)))
	if is_instance_valid(rear_effects):
		rear_effects.queue_redraw()
		front_effects.queue_redraw()


static func lift_at(time: float) -> float:
	var keys := [[0,0],[140,0],[320,18],[620,34],[780,36],[975,16],[1200,0]]
	var ms := time * 1000.0
	for i in range(1, keys.size()):
		if ms <= float(keys[i][0]):
			var u := clampf((ms - float(keys[i-1][0])) / (float(keys[i][0]) - float(keys[i-1][0])),0,1)
			return lerpf(float(keys[i-1][1]),float(keys[i][1]),u*u*(3-2*u))
	return 0.0
