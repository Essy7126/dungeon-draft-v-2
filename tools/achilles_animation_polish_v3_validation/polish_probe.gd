extends "res://tools/achilles_kit_sprite_validation/kit_sprite_probe.gd"

const CANVAS_STABILITY := preload("res://tools/paris_sprite_validation/canvas_stability.gd")
const FOOT_EPSILON_PX := 0.01
const POLISH_CASES := preload("res://tools/achilles_animation_polish_v3_validation/cases.gd")

var _walking := false
var _walk_samples: Array[Dictionary] = []
var _foot_metrics: Dictionary = {}
var _rest_samples: Array[Dictionary] = []
var _walking_started_usec := 0
var _walking_expected_seconds := 0.0


func _ready() -> void:
	_output = ProjectSettings.globalize_path("res://artifacts/achilles_animation_polish_v3_validation")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--artifact-dir="):
			_output = ProjectSettings.globalize_path(argument.trim_prefix("--artifact-dir="))
	_capture_enabled = DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().has("--no-screenshots")
	_clip_enabled = _capture_enabled and OS.get_cmdline_user_args().has("--capture-clip")
	DirAccess.make_dir_recursive_absolute(_output)
	_run.call_deferred()


func _verify_stable_rest(visual: Node2D, unit_view: Node2D, phase: String) -> Dictionary:
	var settled := await CANVAS_STABILITY.wait_for_settled_canvas(self, _battle, visual, unit_view, _sprite)
	if not bool(settled.get("ok", false)):
		_errors.append("camera_or_model_unstable_before_rest:" + phase)
	var result: Dictionary = await super._verify_stable_rest(visual, unit_view, phase)
	result["canvas_settling"] = settled
	_rest_samples.append(result)
	return result


func _walk_to_scenario_start() -> Dictionary:
	# Decode authored foot bounds before starting the timing interval. Runtime
	# observations below never call get_image or mutate animation/position.
	_cache_drawn_feet()
	var destination := Vector2i(placement.hero_cell)
	var before := _unit_snapshot(_hero)
	var finder := _battle.get("pathfinder") as Pathfinder
	var path: Array = finder.find_path(_hero.grid_pos, destination, _hero)
	var cost := int(finder.path_cost_breakdown(path, _hero).get("total", 0))
	var steps := int(placement.get("walk_cells", 3))
	if path.size() != steps + 1 or cost <= 0 or cost > _hero.current_mp:
		_errors.append("real_walk_fixture_not_legal")
		return {"ok": false, "path": path, "cost": cost, "requested_steps": steps}
	_walking_expected_seconds = float(_observed_visual.get_movement_segment_duration(path)) * float(steps)
	_walking_started_usec = Time.get_ticks_usec()
	_walking = true
	_battle._on_move_pressed()
	var route := _click(destination)
	var deadline := Time.get_ticks_msec() + 7000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if _hero.grid_pos == destination and bool(_battle._can_accept_player_intent()):
			break
	_walking = false
	var ended_usec := Time.get_ticks_usec()
	var okay: bool = _hero.grid_pos == destination and _hero.current_mp == int(before.mp) - cost \
		and _hero.current_ap == int(before.ap) and _view_destination_error(destination) <= FOOT_EPSILON_PX
	if not okay:
		_errors.append("real_paid_walk_failed")
	var walked: Array[Dictionary] = []
	var poses: Dictionary = {}
	var textures: Dictionary = {}
	var maximum_anchor_error := 0.0
	var minimum_drawn_ground := INF
	var maximum_drawn_ground := -INF
	var spans: Array[Dictionary] = []
	var last_step := -1
	var monotonic_distance := true
	var previous_distance := -1.0
	var starting_position: Vector2 = _battle.grid_cell_to_parent_local(path[0], _observed_unit_view.get_parent())
	for sample: Dictionary in _walk_samples:
		if not str(sample.clip).begins_with("walk_"):
			continue
		walked.append(sample)
		poses[sample.frame] = true
		textures[sample.pixel_sha256] = true
		maximum_anchor_error = maxf(maximum_anchor_error, float(sample.anchor_error_px))
		minimum_drawn_ground = minf(minimum_drawn_ground, float(sample.drawn_ground_offset_px))
		maximum_drawn_ground = maxf(maximum_drawn_ground, float(sample.drawn_ground_offset_px))
		var distance: float = starting_position.distance_to(Vector2(sample.unit_view_position))
		if distance + FOOT_EPSILON_PX < previous_distance:
			monotonic_distance = false
		previous_distance = distance
		var step: int = int(sample.runtime.get("walk_step_index", -1))
		if step < 0:
			continue
		if step != last_step:
			if not spans.is_empty():
				spans[-1]["ended_usec"] = sample.time_usec
			spans.append({"step_index": step, "started_usec": sample.time_usec,
				"first_frame": sample.frame, "last_frame": sample.frame})
			last_step = step
		if not spans.is_empty():
			spans[-1]["last_frame"] = sample.frame
			spans[-1]["last_progress"] = sample.runtime.get("walk_step_progress", -1)
	if not spans.is_empty():
		spans[-1]["ended_usec"] = ended_usec
	if walked.size() < 3 or poses.size() < 3 or textures.size() < 3:
		_errors.append("walk_did_not_render_multiple_authored_poses")
	if walked.any(func(sample: Dictionary) -> bool: return bool(sample.playing)):
		_errors.append("walk_autoplay_desynchronized_from_actual_distance")
	if maximum_anchor_error > FOOT_EPSILON_PX:
		_errors.append("walk_sprite_ground_anchor_detached_from_unit_view")
	if not monotonic_distance:
		_errors.append("walk_unit_view_reversed_during_straight_path")
	# Missing distance telemetry fails explicitly instead of inferring a pass
	# from time-based animation. Every paid tile must actually be observed.
	if spans.is_empty() or spans.size() != steps or int(spans[0].step_index) != 0:
		_errors.append("walk_distance_owned_steps_not_all_observed")
	return {"ok": okay, "before": before, "after": _unit_snapshot(_hero), "route": route,
		"cost": cost, "path": path, "steps": steps, "samples": _walk_samples,
		"authored_frames_seen": poses.keys(), "distinct_drawn_textures": textures.size(),
		"maximum_anchor_error_px": maximum_anchor_error, "monotonic_straight_travel": monotonic_distance,
		"minimum_drawn_ground_offset_px": minimum_drawn_ground, "maximum_drawn_ground_offset_px": maximum_drawn_ground,
		"observed_stride_steps": spans, "expected_travel_seconds": _walking_expected_seconds,
		"input_to_idle_seconds": float(ended_usec - _walking_started_usec) / 1000000.0,
		"pixel_decode_scope": "Foot alpha bounds decoded before input. No image readback during timing samples."}


func _process(delta: float) -> void:
	super._process(delta)
	if _walking and is_instance_valid(_sprite) and is_instance_valid(_observed_unit_view):
		_sample_walk("process")


func _on_sprite_frame_changed() -> void:
	super._on_sprite_frame_changed()
	if _walking:
		_sample_walk("frame_changed")


func _sample_walk(kind: String) -> void:
	if _walk_samples.size() >= 1800 or not is_instance_valid(_sprite):
		return
	var profile: Resource = _observed_visual.get("sprite_profile")
	var root: Vector2 = _sprite.offset + Vector2(profile.get("foot_anchor"))
	if _sprite.centered:
		root -= Vector2(profile.get("frame_canvas_size")) * 0.5
	var screen_root: Vector2 = _sprite.get_global_transform_with_canvas() * root
	var metric: Dictionary = _foot_metrics.get("%s:%d" % [_sprite.animation, _sprite.frame], {})
	var state: Dictionary = _observed_visual.get_visual_runtime_state()
	_walk_samples.append({"kind": kind, "time_usec": Time.get_ticks_usec(), "engine_frame": Engine.get_process_frames(),
		"clip": str(_sprite.animation), "frame": _sprite.frame, "frame_progress": _sprite.frame_progress,
		"playing": _sprite.is_playing(), "unit_view_position": _observed_unit_view.position,
		"sprite_transform": _sprite.transform, "screen_root": screen_root,
		"anchor_error_px": screen_root.distance_to(_observed_unit_view.get_global_transform_with_canvas().origin),
		"drawn_ground_offset_px": float(metric.get("bottom", -1000)) - float(Vector2(profile.get("foot_anchor")).y),
		"texture_signature": metric.get("signature", "missing"), "pixel_sha256": metric.get("pixel_sha256", "missing"),
		"runtime": state.get("ACHILLES_SPRITE_RUNTIME", {})})


func _cache_drawn_feet() -> void:
	for stem: String in ["idle", "walk"]:
		var clip := StringName("%s_%s" % [stem, configuration.direction])
		if not _sprite.sprite_frames.has_animation(clip):
			_errors.append("required_body_clip_missing:" + str(clip))
			continue
		for frame in _sprite.sprite_frames.get_frame_count(clip):
			var texture: Texture2D = _sprite.sprite_frames.get_frame_texture(clip, frame)
			var pixels: Image = texture.get_image()
			if pixels.is_compressed():
				pixels.decompress()
			var bottom := -1
			for y in range(pixels.get_height() - 1, -1, -1):
				for x in pixels.get_width():
					if pixels.get_pixel(x, y).a > 0.13:
						bottom = y + 1
						break
				if bottom >= 0:
					break
			if bottom < 0:
				_errors.append("empty_drawn_pose:%s:%d" % [clip, frame])
			var hash := HashingContext.new()
			hash.start(HashingContext.HASH_SHA256)
			hash.update(pixels.get_data())
			_foot_metrics["%s:%d" % [clip, frame]] = {"bottom": bottom,
				"signature": _texture_signature(texture), "pixel_sha256": hash.finish().hex_encode()}
	var idle: Dictionary = _foot_metrics.get("idle_%s:0" % configuration.direction, {})
	for contact in [3, 7]:
		var planted: Dictionary = _foot_metrics.get("walk_%s:%d" % [configuration.direction, contact], {})
		if idle.is_empty() or planted.is_empty() or absf(float(planted.bottom) - float(idle.bottom)) > 3.0:
			_errors.append("authored_walk_contact_not_aligned_with_drawn_idle:%d" % contact)


func _texture_signature(texture: Texture2D) -> String:
	if texture is AtlasTexture:
		var atlas_texture := texture as AtlasTexture
		return "%s:%s" % [atlas_texture.atlas.resource_path, atlas_texture.region]
	return texture.resource_path


func _effect_draw_snapshot(effect: Node) -> Dictionary:
	var result: Dictionary = super._effect_draw_snapshot(effect)
	result["texture_signatures"] = []
	result["global_centers"] = []
	for child in effect.get_children():
		var drawn_sprite := child as Sprite2D
		if drawn_sprite != null and drawn_sprite.texture != null and drawn_sprite.is_visible_in_tree():
			(result.texture_signatures as Array).append(_texture_signature(drawn_sprite.texture))
			(result.global_centers as Array).append(drawn_sprite.global_position)
	return result


func _on_visual_release() -> void:
	super._on_visual_release()
	if _active.is_empty():
		return
	_active["release_origin_global"] = _observed_unit_view.get_cast_effect_origin_global()
	var spell: Spell = _spell(StringName(_active.spell_id))
	var adapter: MasteryCombatAdapter = _battle.get("_mastery_adapter") as MasteryCombatAdapter
	var origin_cell: Vector2i = adapter.projectile_origin(_hero, spell)
	var cell_delta: Vector2 = _battle.grid_cell_to_parent_local(origin_cell, _observed_unit_view.get_parent()) \
		- _battle.grid_cell_to_parent_local(_hero.grid_pos, _observed_unit_view.get_parent())
	var parent_view: Node2D = _observed_unit_view.get_parent() as Node2D
	_active["projectile_origin_cell"] = origin_cell
	_active["expected_projectile_origin_global"] = Vector2(_active.release_origin_global) \
		+ parent_view.to_global(cell_delta) - parent_view.to_global(Vector2.ZERO)
	_active["release_runtime"] = _observed_visual.get_visual_runtime_state()
	_active["release_texture_signature"] = _texture_signature(_sprite.sprite_frames.get_frame_texture(_sprite.animation, _sprite.frame))


func _cast(spell_id: StringName, target: Vector2i) -> void:
	var kit: Dictionary = POLISH_CASES.KITS.get(str(configuration.kit), {})
	if spell_id == SHOT and kit.has("exp_spell"):
		spell_id = StringName(kit.exp_spell)
	await super._cast(spell_id, target)


func _is_probe_shot(spell_id: StringName) -> bool:
	var kit: Dictionary = POLISH_CASES.KITS.get(str(configuration.kit), {})
	return spell_id == SHOT or str(spell_id) == str(kit.get("exp_spell", ""))


func _expected_hit_count(spell_id: StringName) -> int:
	if _is_probe_shot(spell_id) and str(configuration.kit).begins_with("exp_"):
		return 3 if str(configuration.kit) in ["exp_traverse", "exp_horizon", "exp_foudre"] else 1
	if spell_id == SHOT and str(configuration.kit) == "piercing":
		return 2
	return super._expected_hit_count(spell_id)



func _unit_snapshot(unit: Unit) -> Dictionary:
	var result: Dictionary = super._unit_snapshot(unit)
	result["next_turn_ap_modifier"] = unit.next_turn_ap_modifier
	result["statuses"] = []
	for entry: Dictionary in unit.get_active_statuses():
		var data := entry.get("data") as StatusData
		var source := entry.get("source") as Unit
		if data != null:
			(result.statuses as Array).append({"status_id": str(data.get_effective_status_id()),
				"remaining": int(entry.get("remaining", 0)), "mp_reduction": data.mp_reduction,
				"source_instance_id": source.get_instance_id() if source != null else 0})
	return result


func _check_action(spell_id: StringName, expected_hits: int) -> void:
	super._check_action(spell_id, expected_hits)
	var facts := {}
	if spell_id == &"exp_braise":
		var target := Vector2i(int(_active.target[0]), int(_active.target[1]))
		var terrain := _battle.get("terrain_effects") as TerrainEffects
		var effect: TerrainEffectData = terrain.get_effect_data(target) if terrain != null else null
		if effect == null:
			_errors.append("exp_braise:actual_fire_surface_missing")
		else:
			facts = {"cell": target, "surface_id": str(effect.surface_id), "damage": effect.damage,
				"element": effect.element, "remaining_duration": terrain.runtime_service.get_remaining_duration(target)}
			if effect.surface_id != &"expedition_braise" or effect.damage != 3 or effect.element != Spell.Element.FIRE or int(facts.remaining_duration) != 2:
				_errors.append("exp_braise:actual_fire_surface_contract_mismatch")
	elif spell_id == &"exp_givre":
		var statuses: Array[Dictionary] = []
		var target := Vector2i(int(_active.target[0]), int(_active.target[1]))
		var scoped := _spell(spell_id).status_source_scoped
		var expected_source := _hero.get_instance_id() if scoped else 0
		var preexisting := false
		for enemy: Dictionary in _active.enemies_before:
			for status: Dictionary in enemy.statuses:
				preexisting = preexisting or str(status.status_id) == "exp_givre"
		for enemy: Dictionary in _active.enemies_after:
			for status: Dictionary in enemy.statuses:
				if str(status.status_id) == "exp_givre" and Vector2i(enemy.cell) == target and int(status.source_instance_id) == expected_source:
					statuses.append(status)
		facts = {"actual_target_statuses": statuses, "target": target, "status_source_scoped": scoped,
			"scope": "Newly resolved pending next-activation movement penalty on the actual target, before an enemy turn"}
		if preexisting or statuses.size() != 1 or int(statuses[0].mp_reduction) != 1 or int(statuses[0].remaining) != 1:
			_errors.append("exp_givre:actual_target_movement_penalty_missing")
	elif spell_id == &"exp_foudre":
		var penalties: Array[Dictionary] = []
		for after: Dictionary in _active.enemies_after:
			for before: Dictionary in _active.enemies_before:
				if int(after.instance_id) == int(before.instance_id):
					var change := int(after.next_turn_ap_modifier) - int(before.next_turn_ap_modifier)
					if change != 0:
						penalties.append({"instance_id": after.instance_id, "delta": change})
		facts = {"next_activation_ap_penalties": penalties}
		if penalties.size() != 3 or penalties.any(func(item: Dictionary) -> bool: return int(item.delta) != -1):
			_errors.append("exp_foudre:three_real_next_activation_ap_penalties_missing")
	if not facts.is_empty():
		_active["post_resolution_effects"] = facts


func _finish(details: Dictionary) -> void:
	details["schema"] = "dd.achilles.animation-polish-validation.v3"
	if is_instance_valid(_observed_visual):
		var expected_scene := "res://characters/achilles/AchillesPaintedGUnitView.tscn" \
			if str(configuration.get("appearance", "classic")) == "painted_g" \
			else "res://characters/achilles/AchillesIsoUnitView.tscn"
		details["actual_visual_scene"] = _observed_visual.scene_file_path
		details["actual_visual_profile"] = (_observed_visual.get("sprite_profile") as Resource).resource_path
		if str(configuration.get("appearance", "classic")) == "classic" and _source_sprite_frames != "res://assets/characters/Achilles/sprites_polish_v3/achilles_sprite_frames.tres":
			_errors.append("classic_body_not_rendering_promoted_v3_frames")
		if _observed_visual.scene_file_path != expected_scene:
			_errors.append("selected_appearance_not_rendered_by_actual_unit_view")
	details["polish_validation"] = {"version": 3, "foot_metrics": _foot_metrics,
		"rest_samples": _rest_samples, "source_scope": "Inherited real combat harness with independent v3 movement, anchor, release-origin and actual textured-effect observations."}
	super._finish(details)


func _check_actual_effects(counter: Dictionary) -> void:
	var action_checks: Array[Dictionary] = []
	var instances: Dictionary = {}
	for entry: Dictionary in _effects:
		var state: Dictionary = entry.state
		instances[entry.effect_id] = true
		if str(state.get("phase", "")).is_empty():
			_errors.append("effect_published_without_phase:%s" % entry.effect_id)
		if bool(state.get("closed", false)):
			continue
		if int(entry.drawn.sprite_count) <= 0 or str(entry.drawn.frames_path) not in [
				"res://assets/vfx/achilles_kit_v2/effects.tres",
				"res://assets/vfx/achilles_polish_v3/effects.tres",
				"res://assets/vfx/paris/sprites_v1/effects.tres",
				"res://assets/vfx/achilles_polish_v3/lightning.tres"]:
			_errors.append("effect_missing_canonical_drawn_sprites:%s" % entry.effect_id)
	for action: Dictionary in _actions:
		var entries: Array[Dictionary] = []
		for entry: Dictionary in _effects:
			if str(entry.state.spell_id) == str(action.spell_id) and int(entry.time_usec) >= int(action.input_usec) \
					and int(entry.time_usec) <= int(action.observation_end_usec):
				entries.append(entry)
		var prefix := "effect_%s:" % action.spell_id
		var spell_id := StringName(action.spell_id)
		var checks := {"spell_id": action.spell_id, "observations": entries.size(), "required": []}
		if spell_id == GUARD:
			_require_effect(entries, &"guard", &"impact", prefix, checks)
			if configuration.kit == "aeacus":
				var barriers := _require_effect(entries, &"barrier", &"hold", prefix, checks)
				if _effect_instance_count(barriers) != 3:
					_errors.append(prefix + "rampart_not_three_drawn_barriers")
		elif spell_id == DASH:
			var dust := _require_effect(entries, &"dust", &"impact", prefix, checks)
			if _effect_instance_count(dust) != 2:
				_errors.append(prefix + "departure_and_arrival_dust_not_both_drawn")
			var before_arrival := false
			var after_arrival := false
			for entry: Dictionary in dust:
				before_arrival = before_arrival or int(entry.time_usec) < int(action.movement_arrival_usec)
				after_arrival = after_arrival or int(entry.time_usec) >= int(action.movement_arrival_usec)
			if not before_arrival or not after_arrival:
				_errors.append(prefix + "dust_does_not_cover_both_sides_of_actual_arrival")
			if int(action.expected_damaged_enemies) == 2:
				var pulse := _require_effect(entries, &"guard", &"impact", prefix, checks)
				var impacts := _require_effect(entries, &"impact", &"impact", prefix, checks)
				for entry: Dictionary in pulse + impacts:
					if int(entry.time_usec) < int(action.movement_arrival_usec) or not bool(entry.state.impact_reached):
						_errors.append(prefix + "bastion_effect_before_actual_arrival")
				_require_target_count(impacts, 2, prefix)
		elif _is_probe_shot(spell_id):
			var expected: Dictionary = _expected_projectile_contract()
			var flight := _require_effect(entries, StringName(expected.projectile), &"flight", prefix, checks)
			var impact := _require_effect(entries, StringName(expected.impact), &"impact", prefix, checks)
			_check_projectile_origin_and_art(action, flight, impact, expected)
			var first_damage := 0
			var last_damage := 0
			for event: Dictionary in action.events:
				if event.kind == "health_damage" and event.actor_id == _hero.get_instance_id():
					if first_damage == 0:
						first_damage = int(event.time_usec)
					last_damage = maxi(last_damage, int(event.time_usec))
			if flight.is_empty() or first_damage == 0 or int(flight[0].time_usec) >= first_damage:
				_errors.append(prefix + "projectile_not_visible_before_hp_loss")
			for entry: Dictionary in impact:
				if int(entry.time_usec) < last_damage or not bool(entry.state.impact_reached):
					_errors.append(prefix + "projectile_impact_not_acknowledged_after_real_damage")
			_require_target_count(impact, int(action.expected_damaged_enemies), prefix)
		elif spell_id == STRIKE:
			if configuration.kit == "wrath":
				_require_effect(entries, &"sweep", &"impact", prefix, checks)
			var impacts := _require_effect(entries, &"impact", &"impact", prefix, checks)
			_require_target_count(impacts, int(action.expected_damaged_enemies), prefix)
		action_checks.append(checks)
	var automatic_effects: Array[Dictionary] = []
	for entry: Dictionary in _effects:
		if bool(entry.state.get("automatic", false)):
			automatic_effects.append(entry)
	if configuration.scenario == "counter" and not counter.is_empty():
		var checks := {"required": []}
		var impacts := _require_effect(automatic_effects, &"impact", &"impact", "counter_effect:", checks)
		if _effect_instance_count(impacts) != 1:
			_errors.append("counter_effect:not_one_automatic_impact")
		var automatic: Array = counter.get("automatic_strikes", [])
		if automatic.size() == 1:
			for entry: Dictionary in impacts:
				if int(entry.time_usec) < int(automatic[0].time_usec) or not bool(entry.state.impact_reached):
					_errors.append("counter_effect:feedback_before_resolved_automatic_action")
		for event: Dictionary in _events:
			if event.kind == "unowned_visual_release":
				_errors.append("counter_effect:automatic_replayed_a_manual_body_action")
	_effect_validation = {"instance_count": instances.size(), "observation_count": _effects.size(),
		"actions": action_checks, "automatic_effect_instances": _effect_instance_count(automatic_effects),
		"required_atlas": "Published canonical v2/v3 SpriteFrames, checked on every real effect", "screenshots_enabled": _capture_enabled}



func _expected_projectile_contract() -> Dictionary:
	# Independent expected contract: equipped masteries and drawn art must agree.
	match str(configuration.kit):
		"exp_braise":
			return {"projectile": "fire", "impact": "hellfire", "body": "bow", "effects_source": "paris"}
		"exp_givre":
			return {"projectile": "frost", "impact": "frost", "body": "bow", "effects_source": "paris"}
		"exp_foudre":
			return {"projectile": "arrow_lightning", "impact": "impact_lightning", "body": "bow_death", "effects_source": "lightning"}
		"exp_rupture":
			return {"projectile": "arrow_heavy", "impact": "impact_heavy", "body": "bow"}
		"exp_traverse":
			return {"projectile": "arrow_piercing", "impact": "impact_piercing", "body": "bow_piercing"}
		"exp_horizon":
			return {"projectile": "arrow_death_line", "impact": "impact_death_line", "body": "bow_death"}
		"stopping":
			return {"projectile": "arrow_reach", "impact": "impact_reach", "body": "bow"}
		"piercing":
			return {"projectile": "arrow_piercing", "impact": "impact_piercing", "body": "bow_piercing"}
		"chiron":
			return {"projectile": "arrow_death_line", "impact": "impact_death_line", "body": "bow_death"}
		"volley":
			return {"projectile": "arrow_volley", "impact": "impact_volley", "body": "volley"}
	return {"projectile": "arrow", "impact": "impact", "body": "bow"}


func _check_projectile_origin_and_art(action: Dictionary, flight: Array[Dictionary],
		impact: Array[Dictionary], expected: Dictionary) -> void:
	var prefix := "projectile_%s:" % configuration.kit
	var signature: Dictionary = {}
	var impact_signature: Dictionary = {}
	var maximum_origin_error := 0.0
	var origin: Vector2 = action.get("expected_projectile_origin_global", Vector2(INF, INF))
	for entry: Dictionary in flight + impact:
		if bool(entry.state.get("used_source_fallback", false)) or str(entry.state.get("effects_source", "achilles")) != str(expected.get("effects_source", "achilles")):
			_errors.append(prefix + "wrong_or_fallback_effects_source")
	for entry: Dictionary in flight:
		maximum_origin_error = maxf(maximum_origin_error, origin.distance_to(Vector2(entry.state.origin)))
		for item: String in entry.drawn.texture_signatures:
			signature[item] = true
		if bool(entry.state.get("used_animation_fallback", false)):
			_errors.append(prefix + "specialized_projectile_fell_back_to_generic_art")
	for entry: Dictionary in impact:
		for item: String in entry.drawn.texture_signatures:
			impact_signature[item] = true
		if bool(entry.state.get("used_animation_fallback", false)):
			_errors.append(prefix + "specialized_impact_fell_back_to_generic_art")
	if maximum_origin_error > FOOT_EPSILON_PX or not origin.is_finite():
		_errors.append(prefix + "flight_origin_does_not_match_actual_release_origin")
	if signature.is_empty() or impact_signature.is_empty():
		_errors.append(prefix + "projectile_or_impact_art_never_drawn")
	if str(action.presentation.animation_stem) != str(expected.body):
		_errors.append(prefix + "dedicated_body_animation_not_selected:" + str(expected.body))
	action["projectile_observation"] = {"expected": expected,
		"drawn_flight_textures": signature.keys(), "drawn_impact_textures": impact_signature.keys(),
		"maximum_release_origin_error_px": maximum_origin_error,
		"origin_cell": action.get("projectile_origin_cell"), "expected_origin_global": origin,
		"origin_rule": "Actual release body origin plus legal projectile_origin cell offset; preserves Trait du destin."}
