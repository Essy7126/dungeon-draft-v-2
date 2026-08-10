extends "res://tools/labs/vfx_lab/components/vfx_lab_effect.gd"

const Factory = preload("res://tools/labs/vfx_lab/components/vfx_component_factory.gd")
const FireballTrail = preload("res://tools/labs/vfx_lab/effects/fireball/fireball_trail.gd")
const FireballParticleField = preload("res://tools/labs/vfx_lab/effects/fireball/fireball_particle_field.gd")
const FireballImpactShape = preload("res://tools/labs/vfx_lab/effects/fireball/fireball_impact_shape.gd")
const VOLUME_SHADER = preload("res://tools/labs/vfx_lab/effects/fireball/fireball_volume.gdshader")
const BLAST_SHADER = preload("res://tools/labs/vfx_lab/effects/fireball/fireball_blast.gdshader")
const AFTERMATH_SHADER = preload("res://tools/labs/vfx_lab/effects/fireball/fireball_aftermath.gdshader")

const CAST_END := 0.22
const CONTACT_TIME := 1.02
const DEFAULT_DURATION := 2.18

var variant_id := &"A"
var _spec: Dictionary = {}
var _start := Vector2.ZERO
var _target := Vector2(260.0, 0.0)
var _orb_position := Vector2.ZERO
var _previous_orb_position := Vector2.ZERO
var _outer_volume: ColorRect = null
var _body_volume: ColorRect = null
var _core_volume: ColorRect = null
var _blast_volume: ColorRect = null
var _aftermath: ColorRect = null
var _trail: Node2D = null
var _particles: Node2D = null
var _impact_shape: Node2D = null
var _impact_started := false
var _stream_accumulator := 0.0
var _aftermath_accumulator := 0.0


func _build_effect(parameters: Dictionary) -> void:
	duration = float(parameters.get("duration", DEFAULT_DURATION))
	variant_id = StringName(String(parameters.get("variant", "A")).to_upper())
	if variant_id not in [&"A", &"B", &"C"]:
		variant_id = &"A"
	_spec = _variant_spec(variant_id)
	_start = parameters.get("start", Vector2.ZERO) as Vector2
	_target = parameters.get("target", Vector2(260.0, 0.0)) as Vector2
	_orb_position = _start
	_previous_orb_position = _start
	_stream_accumulator = 0.0
	_aftermath_accumulator = 0.0
	_impact_started = false

	_trail = FireballTrail.new() as Node2D
	_visual_root.add_child(_trail)
	_trail.call("configure", {
		"seed": visual_seed + 31,
		"lifetime": _spec["trail_lifetime"],
		"width": _spec["trail_width"],
		"fragment_chance": _spec["fragment_chance"],
		"strand_offset": _spec["strand_offset"],
		"edge_color": _spec["edge_color"],
		"body_color": _spec["body_color"],
		"core_color": _spec["core_color"],
	})

	_particles = FireballParticleField.new() as Node2D
	_visual_root.add_child(_particles)
	_particles.call("configure", visual_seed + 73, _spec["palette"])
	_particles.call("emit_burst", _start, {
		"count": _spec["cast_count"],
		"speed_min": 38.0,
		"speed_max": 92.0,
		"size_min": 1.1,
		"size_max": 3.1,
		"lifetime_min": 0.18,
		"lifetime_max": 0.38,
		"radius_min": 15.0,
		"radius_max": 30.0,
		"delay_max": 0.06,
		"inward": true,
	})

	_impact_shape = FireballImpactShape.new() as Node2D
	_impact_shape.position = _target
	_visual_root.add_child(_impact_shape)
	_impact_shape.call("configure", {
		"seed": visual_seed + 151,
		"radius": _spec["impact_radius"],
		"lobe_count": _spec["lobe_count"],
		"edge_color": _spec["edge_color"],
		"body_color": _spec["body_color"],
		"core_color": _spec["core_color"],
		"smoke_color": _spec["smoke_color"],
		"arc_color": _spec["accent_color"],
	})

	_outer_volume = _add_volume(float(_spec["outer_size"]), 0.64, 1.28)
	_body_volume = _add_volume(float(_spec["body_size"]), 1.05, 1.0)
	_core_volume = _add_volume(float(_spec["core_size"]), 1.42, 0.64)
	_outer_volume.z_index = 1
	_body_volume.z_index = 2
	_core_volume.z_index = 3

	_blast_volume = Factory.add_shader_rect(
		_visual_root,
		_target,
		Vector2.ONE * float(_spec["impact_radius"]) * 2.75,
		BLAST_SHADER,
		{
			"core_color": _spec["core_color"],
			"body_color": _spec["body_color"],
			"edge_color": _spec["edge_color"],
			"seed_value": float(visual_seed % 997),
			"turbulence": _spec["turbulence"],
			"asymmetry": _spec["asymmetry"],
			"intensity": float(_spec["blast_intensity"]) * intensity,
			"progress": 0.0,
			"fade": 0.0,
		}
	)
	_blast_volume.z_index = 5
	_blast_volume.visible = false

	_aftermath = Factory.add_shader_rect(
		_visual_root,
		_target + Vector2(0.0, 3.0),
		Vector2(float(_spec["impact_radius"]) * 1.72, float(_spec["impact_radius"]) * 0.82),
		AFTERMATH_SHADER,
		{
			"ember_color": _spec["body_color"],
			"coal_color": _spec["coal_color"],
			"seed_value": float(visual_seed % 997),
			"effect_time": 0.0,
			"fade": 0.0,
		}
	)
	_aftermath.z_index = -1
	_aftermath.visible = false
	_update_volume_centers(_start)
	_set_volume_time(0.0)


func _update_effect(time: float, delta: float) -> void:
	if is_instance_valid(_particles):
		_particles.call("advance", delta)
	if is_instance_valid(_trail):
		_trail.call("advance", delta)
	_set_volume_time(time)
	if time < CAST_END:
		_update_cast(time)
	elif time < CONTACT_TIME:
		_update_projectile(time, delta)
	else:
		_start_impact_once()
		_update_impact(time, delta)


func _update_cast(time: float) -> void:
	var t := clampf(time / CAST_END, 0.0, 1.0)
	var compression := 1.0 - pow(1.0 - t, 3.0)
	var direction := (_target - _start).normalized()
	_orb_position = _start + direction * lerpf(-7.0, 3.0, compression)
	_update_volume_centers(_orb_position)
	_outer_volume.scale = Vector2(
		lerpf(1.22, 0.68, compression),
		lerpf(0.38, 0.86, compression)
	)
	_body_volume.scale = Vector2.ONE * lerpf(0.34, 0.82, compression)
	_core_volume.scale = Vector2.ONE * lerpf(0.12, 0.72, compression)
	_outer_volume.rotation = sin(time * 31.0 + float(visual_seed % 13)) * 0.12
	_body_volume.rotation = -sin(time * 24.0 + 1.7) * 0.08
	_set_volume_opacity(0.28 + compression * 0.72)


func _update_projectile(time: float, delta: float) -> void:
	var flight_t := clampf((time - CAST_END) / (CONTACT_TIME - CAST_END), 0.0, 1.0)
	var eased := flight_t * flight_t * (3.0 - 2.0 * flight_t)
	var direction := (_target - _start).normalized()
	var normal := direction.orthogonal()
	var arc := -sin(flight_t * PI) * float(_spec["path_height"])
	var wobble := sin(flight_t * TAU * float(_spec["wobble_cycles"]) + float(visual_seed % 19)) \
		* float(_spec["path_wobble"]) * sin(flight_t * PI)
	_previous_orb_position = _orb_position
	_orb_position = _start.lerp(_target, eased) + Vector2(0.0, arc) + normal * wobble
	_update_volume_centers(_orb_position)
	var pulse := sin(time * 39.0 + float(visual_seed % 23))
	_outer_volume.scale = Vector2(1.08 + pulse * 0.09, 0.86 - pulse * 0.055)
	_body_volume.scale = Vector2(1.0 - pulse * 0.045, 0.92 + pulse * 0.06)
	_core_volume.scale = Vector2.ONE * (0.72 + pulse * 0.045)
	_outer_volume.rotation = sin(time * 17.0) * 0.16
	_body_volume.rotation = -sin(time * 23.0 + 1.2) * 0.09
	_set_volume_opacity(1.0)
	_trail.call("push_point", _orb_position - direction * 4.0)
	_stream_accumulator += delta
	var interval := float(_spec["ember_interval"])
	while _stream_accumulator >= interval:
		_stream_accumulator -= interval
		_particles.call("emit_burst", _orb_position - direction * 10.0, {
			"count": 1 if variant_id == &"A" else 2,
			"direction": -direction + Vector2(0.0, 0.38),
			"spread_degrees": 88.0,
			"speed_min": 22.0,
			"speed_max": 66.0,
			"size_min": 0.9,
			"size_max": 2.8 if variant_id != &"B" else 3.7,
			"lifetime_min": 0.24,
			"lifetime_max": 0.56,
			"radius_min": 1.0,
			"radius_max": 8.0,
			"gravity": Vector2(0.0, 48.0),
		})


func _start_impact_once() -> void:
	if _impact_started:
		return
	_impact_started = true
	_outer_volume.visible = false
	_body_volume.visible = false
	_core_volume.visible = false
	_blast_volume.visible = true
	_aftermath.visible = true
	_impact_shape.call("start")
	_particles.call("emit_burst", _target, {
		"count": _spec["impact_particle_count"],
		"direction": Vector2.UP,
		"spread_degrees": 255.0,
		"speed_min": 58.0,
		"speed_max": _spec["impact_particle_speed"],
		"size_min": 1.3,
		"size_max": 5.0,
		"lifetime_min": 0.34,
		"lifetime_max": 0.92,
		"radius_min": 1.0,
		"radius_max": 11.0,
		"delay_max": 0.08,
		"gravity": Vector2(0.0, 132.0),
	})


func _update_impact(time: float, delta: float) -> void:
	var age := time - CONTACT_TIME
	_impact_shape.call("advance", delta)
	var blast_material := _blast_volume.material as ShaderMaterial
	var expansion := clampf(age / float(_spec["blast_expansion_time"]), 0.0, 1.0)
	var blast_fade := 1.0
	if age > 0.30:
		blast_fade = clampf(1.0 - (age - 0.30) / 0.48, 0.0, 1.0)
	blast_material.set_shader_parameter("effect_time", time)
	blast_material.set_shader_parameter("progress", expansion)
	blast_material.set_shader_parameter("fade", blast_fade)
	var residue_fade := clampf(age / 0.20, 0.0, 1.0) \
		* clampf((duration - time) / 0.48, 0.0, 1.0)
	var residue_material := _aftermath.material as ShaderMaterial
	residue_material.set_shader_parameter("effect_time", time)
	residue_material.set_shader_parameter("fade", residue_fade)
	if age > 0.24 and age < 0.82:
		_aftermath_accumulator += delta
		var interval := 0.085 if variant_id == &"A" else 0.065
		while _aftermath_accumulator >= interval:
			_aftermath_accumulator -= interval
			_particles.call("emit_burst", _target + Vector2(_rng.randf_range(-36.0, 36.0), 2.0), {
				"count": 1,
				"direction": Vector2.UP,
				"spread_degrees": 36.0,
				"speed_min": 24.0,
				"speed_max": 58.0,
				"size_min": 1.0,
				"size_max": 2.6,
				"lifetime_min": 0.24,
				"lifetime_max": 0.48,
				"gravity": Vector2(0.0, 54.0),
			})


func _add_volume(size: float, layer_intensity: float, stretch: float) -> ColorRect:
	return Factory.add_shader_rect(
		_visual_root,
		_start,
		Vector2.ONE * size,
		VOLUME_SHADER,
		{
			"core_color": _spec["core_color"],
			"body_color": _spec["body_color"],
			"edge_color": _spec["edge_color"],
			"intensity": layer_intensity * intensity,
			"opacity": 1.0,
			"seed_value": float((visual_seed + int(size)) % 997),
			"turbulence": _spec["turbulence"],
			"distortion": _spec["distortion"],
			"stretch": stretch,
			"tail_bias": _spec["tail_bias"],
		}
	)


func _update_volume_centers(center: Vector2) -> void:
	for rect in [_outer_volume, _body_volume, _core_volume]:
		if is_instance_valid(rect):
			rect.position = center - rect.size * 0.5
			rect.pivot_offset = rect.size * 0.5


func _set_volume_time(time: float) -> void:
	for rect in [_outer_volume, _body_volume, _core_volume]:
		if is_instance_valid(rect):
			(rect.material as ShaderMaterial).set_shader_parameter("effect_time", time)


func _set_volume_opacity(value: float) -> void:
	for rect in [_outer_volume, _body_volume, _core_volume]:
		if is_instance_valid(rect):
			(rect.material as ShaderMaterial).set_shader_parameter("opacity", value)


func _clear_effect_state() -> void:
	_outer_volume = null
	_body_volume = null
	_core_volume = null
	_blast_volume = null
	_aftermath = null
	_trail = null
	_particles = null
	_impact_shape = null
	_impact_started = false
	_stream_accumulator = 0.0
	_aftermath_accumulator = 0.0
	_spec.clear()


func get_procedural_signature() -> String:
	var particle_signature := ""
	var impact_signature := ""
	if is_instance_valid(_particles):
		particle_signature = str(_particles.call("get_signature"))
	if is_instance_valid(_impact_shape):
		impact_signature = str(_impact_shape.call("get_signature"))
	return "fireball:%s:%d:%s:%s" % [variant_id, visual_seed, particle_signature, impact_signature]


func get_phase() -> StringName:
	if elapsed < CAST_END:
		return &"cast"
	if elapsed < CONTACT_TIME:
		return &"projectile"
	if elapsed < CONTACT_TIME + 0.42:
		return &"impact"
	return &"aftermath"


func _variant_spec(id: StringName) -> Dictionary:
	match id:
		&"B":
			return {
				"label": "ORGANIC / TURBULENT",
				"core_color": Color("fff0a8"),
				"body_color": Color("ff8126"),
				"edge_color": Color("b91f14"),
				"accent_color": Color("ffb13f"),
				"smoke_color": Color(0.16, 0.035, 0.025, 0.82),
				"coal_color": Color(0.10, 0.012, 0.009, 0.0),
				"palette": [Color("fff0a8"), Color("ff9b35"), Color("e73516"), Color("8f1715")],
				"outer_size": 72.0, "body_size": 53.0, "core_size": 31.0,
				"turbulence": 1.08, "distortion": 0.19, "tail_bias": 0.14,
				"trail_width": 24.0, "trail_lifetime": 0.52, "fragment_chance": 0.20, "strand_offset": 0.0,
				"path_height": 39.0, "path_wobble": 8.5, "wobble_cycles": 2.25,
				"ember_interval": 0.052, "cast_count": 21,
				"impact_radius": 72.0, "lobe_count": 9, "asymmetry": 0.82,
				"blast_intensity": 0.86, "blast_expansion_time": 0.25,
				"impact_particle_count": 34, "impact_particle_speed": 188.0,
			}
		&"C":
			return {
				"label": "MAGICAL / STYLIZED",
				"core_color": Color("fffbd2"),
				"body_color": Color("ffb43f"),
				"edge_color": Color("8c35db"),
				"accent_color": Color("d989ff"),
				"smoke_color": Color(0.09, 0.025, 0.18, 0.80),
				"coal_color": Color(0.055, 0.012, 0.11, 0.0),
				"palette": [Color("fffbd2"), Color("ffc24c"), Color("da6dff"), Color("7135cc")],
				"outer_size": 68.0, "body_size": 49.0, "core_size": 28.0,
				"turbulence": 0.72, "distortion": 0.145, "tail_bias": 0.10,
				"trail_width": 17.0, "trail_lifetime": 0.48, "fragment_chance": 0.11, "strand_offset": 3.4,
				"path_height": 35.0, "path_wobble": 5.2, "wobble_cycles": 1.65,
				"ember_interval": 0.060, "cast_count": 18,
				"impact_radius": 68.0, "lobe_count": 7, "asymmetry": 0.63,
				"blast_intensity": 0.92, "blast_expansion_time": 0.27,
				"impact_particle_count": 30, "impact_particle_speed": 172.0,
			}
		_:
			return {
				"label": "COMPACT / NERVOUS",
				"core_color": Color("fff7ca"),
				"body_color": Color("ffad32"),
				"edge_color": Color("ed3210"),
				"accent_color": Color("ffc35b"),
				"smoke_color": Color(0.18, 0.028, 0.018, 0.78),
				"coal_color": Color(0.11, 0.012, 0.008, 0.0),
				"palette": [Color("fff7ca"), Color("ffb43a"), Color("f04413")],
				"outer_size": 57.0, "body_size": 42.0, "core_size": 24.0,
				"turbulence": 0.52, "distortion": 0.105, "tail_bias": 0.075,
				"trail_width": 13.0, "trail_lifetime": 0.34, "fragment_chance": 0.17, "strand_offset": 0.0,
				"path_height": 30.0, "path_wobble": 3.2, "wobble_cycles": 2.8,
				"ember_interval": 0.070, "cast_count": 15,
				"impact_radius": 58.0, "lobe_count": 6, "asymmetry": 0.66,
				"blast_intensity": 0.98, "blast_expansion_time": 0.19,
				"impact_particle_count": 25, "impact_particle_speed": 218.0,
			}
