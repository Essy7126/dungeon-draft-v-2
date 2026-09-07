extends "res://tools/achilles_sprite_validation/courtyard_sprite_probe.gd"

## A real production encounter. The probe only places Achilles legally and
## uses the normal End Turn entrypoints; the enemy AI owns movement and damage.
const SPECTRE_DATA := "res://data/units/enemies/spectre_greatsword.tres"
const SPECTRE_FRAMES := "res://assets/characters/spectre_greatsword/sprites_v1/spectre_sprite_frames.tres"

const REGISTERED_BATTLE_SCRIPT := "res://battle/painted/registered_terrain/registered_terrain_battle.gd"

var requested_room_path := ""
var _battle: Node
var _hero: Unit
var _enemy: Unit
var _enemy_view: Node2D
var _enemy_visual: Node2D
var _enemy_observing := false
var _enemy_turns := 0
var _player_turns := 0
var _timeline: Array[Dictionary] = []
var _enemy_moves: Array[Dictionary] = []
var _enemy_casts: Array[Dictionary] = []
var _enemy_damages: Array[Dictionary] = []
var _hero_approaches: Array[Dictionary] = []
var _current_cast: Dictionary = {}
var _cast_started_usec := 0
var _last_frame_key := ""
var _max_local_anchor_error := 0.0
var _initial_visual_position := Vector2.ZERO
var _clip_enabled := false
var _clip_active := false
var _clip_pending := false
var _clip_last_capture := 0
var _clip_started := 0
var _clip_ended := 0
var _clip_stop_after := 0
var _clip_rect := Rect2i()
var _clip_images: Array[Image] = []
var _clip_frames: Array[Dictionary] = []
var _clip_report: Dictionary = {"enabled": false}
const CLIP_MAX_FRAMES := 240


func _ready() -> void:
	_output = ProjectSettings.globalize_path("res://artifacts/spectre_sprite_validation_v1")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--artifact-dir="):
			_output = ProjectSettings.globalize_path(argument.trim_prefix("--artifact-dir="))
	_capture_enabled = DisplayServer.get_name() != "headless" \
		and not OS.get_cmdline_user_args().has("--no-screenshots")
	_clip_enabled = _capture_enabled and OS.get_cmdline_user_args().has("--capture-clip")
	DirAccess.make_dir_recursive_absolute(_output)
	_run.call_deferred()


func _process(_delta: float) -> void:
	if not _enemy_observing or not is_instance_valid(_sprite):
		return
	var clip := str(_sprite.animation)
	var action := clip.get_slice("_", 0)
	_states_seen[clip] = true
	var key := "%s:%d" % [clip, _sprite.frame]
	if key != _last_frame_key:
		_last_frame_key = key
		_motion_samples.append({"time_usec": Time.get_ticks_usec(), "clip": clip,
			"frame": _sprite.frame, "frame_progress": _sprite.frame_progress,
			"enemy_cell": _cell_array(_enemy.grid_pos), "enemy_ap": _enemy.current_ap,
			"hero_hp": _hero.current_hp, "unit_position": [_enemy_view.position.x, _enemy_view.position.y]})
	var profile := _enemy_visual.get("sprite_profile") as Resource
	var ground := _sprite.offset + Vector2(profile.get("foot_anchor"))
	if _sprite.centered:
		ground -= Vector2(profile.get("frame_canvas_size")) * 0.5
	_max_local_anchor_error = maxf(_max_local_anchor_error,
		(_sprite.transform * ground).length())
	if _capture_enabled and not _captures.has(action) and not _pending_captures.has(action):
		if action == "idle" or (action == "walk" and _sprite.frame >= 1) \
				or (action == "attack" and _sprite.frame >= 3):
			_capture_current_state(action)
	if _clip_active and _clip_stop_after > 0 and Time.get_ticks_usec() >= _clip_stop_after:
		_clip_active = false
		_clip_ended = Time.get_ticks_usec()
	if _clip_active and not _clip_pending and _clip_images.size() < CLIP_MAX_FRAMES \
			and Time.get_ticks_usec() - _clip_last_capture >= 33333:
		_capture_clip_frame()


func _run() -> void:
	var deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		var candidate := get_tree().current_scene
		if _uses_supported_battle_script(candidate) \
				and bool(candidate.get("runtime_ready_state")) \
				and bool(candidate.get("registered_terrain_ready")):
			_battle = candidate
			break
	if _battle == null:
		_errors.append("real_battle_timeout")
		await _finish_startup_failure(_battle, "runtime_ready")
		return
	if not await _wait_for_real_deployment(_battle, 15000):
		_errors.append("real_hero_deployment_timeout")
		await _finish_startup_failure(_battle, "deployment")
		return
	var interaction := INTERACTIONS.new()
	add_child(interaction)
	if not await interaction._wait_for_player(_battle, 10000):
		_errors.append("initial_player_intent_timeout")
		_finish({})
		return
	for unit: Unit in _battle.get("units"):
		if unit.team == 0:
			_hero = unit
		if unit.unit_id == &"spectre_greatsword":
			_enemy = unit
	if _hero == null or _enemy == null:
		_errors.append("canonical_hero_or_spectre_missing")
		_finish({})
		return
	var views: Dictionary = _battle.get("_unit_views")
	_enemy_view = views.get(_enemy) as Node2D
	_enemy_visual = _enemy_view.get_optional_visual() if _enemy_view != null else null
	if _enemy_visual == null:
		_errors.append("canonical_spectre_visual_missing")
		_finish({})
		return
	var sprites := _enemy_visual.find_children("*", "AnimatedSprite2D", true, false)
	if sprites.size() != 1 or not _enemy_visual.find_children("*", "Node3D", true, false).is_empty() \
			or not _enemy_visual.find_children("*", "SubViewport", true, false).is_empty():
		_errors.append("spectre_is_not_exclusively_sprite_2d")
		_finish({})
		return
	_sprite = sprites[0] as AnimatedSprite2D
	if _sprite.sprite_frames.resource_path != SPECTRE_FRAMES:
		_errors.append("unexpected_spectre_sprite_frames")
	_enemy_visual.cast_release_reached.connect(_record_release)
	_enemy_visual.animation_finished.connect(_record_finish)
	_sprite.animation_changed.connect(_record_animation)
	EventBus.turn_started.connect(_record_turn_started)
	EventBus.voluntary_movement_prepared.connect(_record_move_prepared)
	EventBus.voluntary_movement_resolved.connect(_record_move_resolved)
	EventBus.health_damage_taken.connect(_record_health_damage)
	EventBus.spell_cast.connect(_record_spell_cast)
	_initial_visual_position = _enemy_visual.position
	_enemy_observing = true
	var initial_rest := await _verify_stable_rest(_enemy_visual, _enemy_view, "spectre_initial")
	var initial_hero_hp := _hero.current_hp
	var initial_enemy_cell := _enemy.grid_pos
	# Achilles approaches legally if the larger arena separates the actors
	# too far. EnemyAI still owns its approach and strike.
	var pass_inputs: Array[Dictionary] = []
	for _attempt in 4:
		if not await interaction._wait_for_player(_battle, 12000):
			_errors.append("player_not_ready_for_end_turn")
			break
		await _approach_enemy_if_needed(interaction)
		var before_enemy_turn := _enemy_turns
		var before_player_turn := _player_turns
		var pass_input := {"time_usec": Time.get_ticks_usec(), "hero_hp": _hero.current_hp,
			"hero_cell": _cell_array(_hero.grid_pos), "enemy_cell": _cell_array(_enemy.grid_pos)}
		_battle._on_end_turn_pressed()
		# This is the same confirm callback as the end-turn UI, not a turn
		# queue mutation. Leftover AP/MP intentionally require confirmation.
		if is_instance_valid(_battle.get("_end_turn_confirmation")) \
				and bool(_battle.get("_end_turn_confirmation").is_open()):
			_battle.get("_end_turn_confirmation")._on_confirmed()
			pass_input["confirmation_used"] = true
		pass_inputs.append(pass_input)
		deadline = Time.get_ticks_msec() + 18000
		while Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
			if _enemy_turns > before_enemy_turn and _player_turns > before_player_turn \
					and bool(_battle._can_accept_player_intent()):
				break
		if not _enemy_damages.is_empty() and not _enemy_casts.is_empty():
			break
		if not _hero.is_alive:
			_errors.append("hero_died_before_spectre_validation")
			break
	await get_tree().create_timer(0.25).timeout
	_clip_active = false
	if _clip_ended == 0:
		_clip_ended = Time.get_ticks_usec()
	var returned_rest := await _verify_stable_rest(_enemy_visual, _enemy_view, "spectre_after_enemy_turn")
	_enemy_observing = false
	deadline = Time.get_ticks_msec() + 2000
	while (_capture_jobs > 0 or _clip_pending) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_flush_deferred_captures()
	_flush_clip()
	_validate_enemy_actions()
	for action: String in ["idle", "walk", "attack"]:
		var observed := false
		for animation: String in _states_seen:
			observed = observed or animation.begins_with(action + "_")
		if not observed:
			_errors.append("real_enemy_did_not_play_%s" % action)
		if _capture_enabled and not _captures.has(action):
			_errors.append("real_enemy_screenshot_missing_%s" % action)
	_finish({"actual_scene": _battle.scene_file_path,
		"requested_room_path": requested_room_path,
		"actual_room_name": (_battle.get("room_data") as RoomData).room_name,
		"actual_encounter_id": str((_battle.get("room_data") as RoomData).encounter_definition.encounter_id),
		"actual_terrain_plan": str(_battle.get("registered_terrain_plan_path")),
		"actual_enemy_data": _enemy.character_data.resource_path,
		"actual_visual_scene": _enemy_visual.scene_file_path,
		"actual_sprite_frames": _sprite.sprite_frames.resource_path,
		"runtime_state": _enemy_visual.get_visual_runtime_state(),
		"end_turn_inputs": pass_inputs, "enemy_turn_count": _enemy_turns,
		"real_hero_approaches": _hero_approaches,
		"initial_enemy_cell": _cell_array(initial_enemy_cell), "final_enemy_cell": _cell_array(_enemy.grid_pos),
		"hero_hp_before_all_enemy_turns": initial_hero_hp, "hero_hp_after_all_enemy_turns": _hero.current_hp,
		"real_enemy_movements": _enemy_moves, "real_enemy_casts": _enemy_casts,
		"real_spectre_damage_events": _enemy_damages, "timeline": _timeline,
		"visual_release_and_finish_counts": _action_events,
		"stable_rest_before_actions": initial_rest, "stable_rest_after_actions": returned_rest,
		"maximum_local_ground_anchor_error_px": _max_local_anchor_error,
		"visual_local_position_unchanged": _enemy_visual.position == _initial_visual_position,
		"motion_frame_samples": _motion_samples,
		"screenshots": _captures, "capture_clip": _clip_report,
		"screenshot_capture_enabled": _capture_enabled,
		"capture_work_intervals": _capture_work_intervals,
		"scope": "Canonical registered-terrain encounter (Cour des Sources by default, or requested_room_path) and real legal deployment. Achilles approaches with legal GridView movement if needed, then uses normal End Turn and confirmation. EnemyAI chooses all enemy movement and the canonical spectre_heavy_cleave spell. No artificial damage, enemy relocation, substituted visual, or direct playback calls. Damage attribution filters the real spectre, since another canonical enemy also acts. GPU readback may perturb capture runs; use --no-screenshots without --capture-clip for timing."})


func _uses_supported_battle_script(candidate: Node) -> bool:
	if candidate == null:
		return false
	var candidate_script := candidate.get_script() as Script
	while candidate_script != null:
		if candidate_script.resource_path in [BATTLE_SCRIPT, REGISTERED_BATTLE_SCRIPT]:
			return true
		candidate_script = candidate_script.get_base_script()
	return false

func _approach_enemy_if_needed(interaction: Node) -> void:
	var grid := _battle.get("grid") as GridData
	var pathfinder := _battle.get("pathfinder") as Pathfinder
	if grid.manhattan(_hero.grid_pos, _enemy.grid_pos) <= 4:
		return
	var target := _hero.grid_pos
	var best_distance := 99999
	var best_cost := 0
	var start := _hero.grid_pos
	for candidate: Vector2i in pathfinder.get_reachable(start, _hero.current_mp, _hero):
		if grid.manhattan(candidate, _enemy.grid_pos) < 2:
			continue
		var enemy_path := pathfinder.find_path(_enemy.grid_pos, candidate, _enemy)
		var hero_path := pathfinder.find_path(start, candidate, _hero)
		if enemy_path.size() < 3 or hero_path.size() < 2:
			continue
		var cost := int(pathfinder.path_cost_breakdown(hero_path, _hero).get("total", 0))
		if cost <= 0 or cost > _hero.current_mp:
			continue
		if enemy_path.size() < best_distance:
			best_distance = enemy_path.size()
			target = candidate
			best_cost = cost
	if target == start:
		return
	var renderer := (_battle.get("arena_assembly") as Dictionary).get("renderer") as ArenaTerrainVisualRenderer
	var floor_root := renderer.node_for_cell(target)
	var floor_sprite := floor_root.get_node_or_null("Visual") as Sprite2D if floor_root != null else null
	if floor_sprite == null:
		_errors.append("hero_approach_target_floor_missing")
		return
	var polygon := GEOMETRY.sprite_polygon(floor_sprite)
	var before_mp := _hero.current_mp
	var before_ap := _hero.current_ap
	_battle._on_move_pressed()
	var route: Dictionary = interaction._route_local_pointer(_battle.grid_view,
		(polygon[0] + polygon[2]) * 0.5, true)
	var deadline := Time.get_ticks_msec() + 7000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if _hero.grid_pos == target and bool(_battle._can_accept_player_intent()) \
				and (_battle.get("turn_state") as TurnState).current == TurnState.State.IDLE:
			break
	var okay: bool = _hero.grid_pos == target and grid.get_unit(target) == _hero \
		and _hero.current_mp == before_mp - best_cost and _hero.current_ap == before_ap
	_hero_approaches.append({"ok": okay, "from": _cell_array(start), "target": _cell_array(target),
		"route": route, "mp_before": before_mp, "mp_after": _hero.current_mp,
		"expected_cost": best_cost, "ap_before": before_ap, "ap_after": _hero.current_ap})
	if not okay:
		_errors.append("legal_hero_approach_failed")

func _record_turn_started(unit: Unit) -> void:
	if unit == _enemy:
		_enemy_turns += 1
		_timeline.append({"kind": "spectre_turn_started", "time_usec": Time.get_ticks_usec(),
			"activation": _enemy_turns, "ap": unit.current_ap, "mp": unit.current_mp})
	elif unit == _hero:
		_player_turns += 1


func _record_move_prepared(unit: Unit, path: Array, _base: int, cost: int, action_id: StringName) -> void:
	if unit != _enemy:
		return
	var cells: Array = []
	for cell: Vector2i in path:
		cells.append(_cell_array(cell))
	_enemy_moves.append({"action_id": str(action_id), "activation": _enemy_turns,
		"started_usec": Time.get_ticks_usec(), "path": cells, "paid_mp": cost,
		"ap_before": unit.current_ap, "mp_before": unit.current_mp})
	if not path.is_empty() and _battle.grid.are_adjacent(path.back(), _hero.grid_pos):
		_begin_clip(path)


func _record_move_resolved(unit: Unit, path: Array, cost: int, action_id: StringName) -> void:
	if unit != _enemy:
		return
	for movement: Dictionary in _enemy_moves:
		if str(movement.action_id) == str(action_id):
			movement["finished_usec"] = Time.get_ticks_usec()
			movement["elapsed_ms"] = float(int(movement.finished_usec) - int(movement.started_usec)) / 1000.0
			movement["actual_end_cell"] = _cell_array(path.back())
			movement["actual_mp_after"] = unit.current_mp
			movement["actual_paid_mp"] = cost
			movement["ap_after"] = unit.current_ap


func _record_animation() -> void:
	if not str(_sprite.animation).begins_with("attack_"):
		return
	_cast_started_usec = Time.get_ticks_usec()
	_current_cast = {"started_usec": _cast_started_usec, "activation": _enemy_turns,
		"animation": str(_sprite.animation), "ap_before": _enemy.current_ap,
		"hero_hp_before": _hero.current_hp, "release_usec": 0, "finish_usec": 0,
		"release_count": 0, "finish_count": 0, "damage_event_count": 0}
	_enemy_casts.append(_current_cast)
	_timeline.append({"kind": "attack_started", "time_usec": _cast_started_usec,
		"animation": str(_sprite.animation), "hero_hp": _hero.current_hp})
	_begin_clip([])


func _record_release() -> void:
	_action_events.releases += 1
	if _current_cast.is_empty():
		_errors.append("release_without_attack")
		return
	var now := Time.get_ticks_usec()
	_current_cast.release_count += 1
	_current_cast.release_usec = now
	_current_cast["release_after_start_ms"] = float(now - _cast_started_usec) / 1000.0
	_current_cast["release_frame"] = _sprite.frame
	_current_cast["hero_hp_at_release"] = _hero.current_hp
	_current_cast["ap_at_release"] = _enemy.current_ap
	_timeline.append({"kind": "visual_release", "time_usec": now,
		"frame": _sprite.frame, "hero_hp": _hero.current_hp})


func _record_health_damage(target: Unit, attacker: Unit, amount: int,
		_category: int, _element: int, _critical: bool) -> void:
	if attacker != _enemy or target != _hero:
		return
	var now := Time.get_ticks_usec()
	var fact := {"time_usec": now, "amount": amount, "hero_hp_after": target.current_hp,
		"enemy_ap_after": _enemy.current_ap, "animation": str(_sprite.animation),
		"frame": _sprite.frame, "activation": _enemy_turns}
	_enemy_damages.append(fact)
	_timeline.append({"kind": "real_spectre_health_damage", "time_usec": now, "amount": amount})
	if not _current_cast.is_empty():
		_current_cast.damage_event_count += 1
		_current_cast["damage_usec"] = now
		_current_cast["damage_after_release_ms"] = float(now - int(_current_cast.release_usec)) / 1000.0
		_current_cast["damage_amount"] = amount
		_current_cast["hero_hp_after_damage"] = target.current_hp
		_current_cast["ap_after_damage"] = _enemy.current_ap


func _record_spell_cast(caster: Unit, spell: Spell, _report: Dictionary) -> void:
	if caster == _enemy and not _current_cast.is_empty():
		_current_cast["spell_id"] = str(spell.get_effective_spell_id())
		_current_cast["spell_ap_cost"] = spell.ap_cost
		_current_cast["uses_after"] = caster.get_spell_uses(spell)


func _record_finish(_clip: StringName) -> void:
	_action_events.finishes += 1
	if _current_cast.is_empty():
		_errors.append("finish_without_attack")
		return
	var now := Time.get_ticks_usec()
	_current_cast.finish_count += 1
	_current_cast.finish_usec = now
	if _clip_active:
		_clip_stop_after = now + 250000
	_current_cast["duration_ms"] = float(now - _cast_started_usec) / 1000.0
	_current_cast["final_animation"] = str(_sprite.animation)
	_current_cast["ap_after"] = _enemy.current_ap
	_current_cast["hero_hp_after"] = _hero.current_hp
	_timeline.append({"kind": "visual_finish", "time_usec": now,
		"animation": str(_sprite.animation), "hero_hp": _hero.current_hp})


func _validate_enemy_actions() -> void:
	if _enemy_moves.is_empty() or _enemy_casts.is_empty() or _enemy_damages.is_empty():
		_errors.append("real_ai_movement_cast_or_damage_missing")
	var moved_then_cast := false
	for cast: Dictionary in _enemy_casts:
		for movement: Dictionary in _enemy_moves:
			if int(movement.activation) == int(cast.activation) and movement.has("finished_usec"):
				moved_then_cast = true
		if int(cast.release_count) != 1 or int(cast.finish_count) != 1 or int(cast.damage_event_count) != 1:
			_errors.append("enemy_cast_release_finish_damage_not_once")
		if str(cast.get("spell_id", "")) != "spectre_heavy_cleave":
			_errors.append("enemy_did_not_cast_canonical_cleave")
		if int(cast.get("damage_usec", 0)) < int(cast.release_usec) or int(cast.release_usec) <= int(cast.started_usec):
			_errors.append("enemy_damage_precedes_visual_release")
		if int(cast.get("ap_after", -1)) != int(cast.ap_before) - 2:
			_errors.append("enemy_cleave_ap_spent_more_than_once")
		if int(cast.get("hero_hp_at_release", -1)) != int(cast.hero_hp_before):
			_errors.append("hero_hp_changed_before_spectre_release")
		if not str(cast.get("final_animation", "")).begins_with("idle_"):
			_errors.append("enemy_cleave_did_not_return_to_idle")
		if not _capture_enabled:
			if float(cast.get("release_after_start_ms", 0.0)) < 270.0 \
					or float(cast.get("release_after_start_ms", 0.0)) > 460.0:
				_errors.append("enemy_release_timing_outside_graphical_budget")
			if float(cast.get("duration_ms", 0.0)) < 770.0 or float(cast.get("duration_ms", 0.0)) > 1030.0:
				_errors.append("enemy_attack_timing_outside_graphical_budget")
	if not moved_then_cast:
		_errors.append("spectre_never_moved_and_cast_in_same_activation")
	if _max_local_anchor_error > 0.01 or _enemy_visual.position != _initial_visual_position:
		_errors.append("enemy_visual_root_or_anchor_drift")


func _begin_clip(path: Array) -> void:
	if not _clip_enabled or _clip_started > 0:
		return
	var viewport_size := Vector2i(get_viewport().get_visible_rect().size)
	var hero_view: Node2D = (_battle.get("_unit_views") as Dictionary).get(_hero)
	var hero_point := hero_view.get_global_transform_with_canvas().origin
	var enemy_point := _enemy_view.get_global_transform_with_canvas().origin
	var bounds := Rect2(hero_point - Vector2(125, 180), Vector2(250, 225))
	bounds = bounds.expand(enemy_point - Vector2(125, 180)).expand(enemy_point + Vector2(125, 45))
	for cell: Vector2i in path:
		var point: Vector2 = _battle.grid_view.get_global_transform_with_canvas() \
			* _battle.grid_view.grid_to_world(cell)
		bounds = bounds.expand(point - Vector2(120, 180)).expand(point + Vector2(120, 50))
	_clip_rect = Rect2i(bounds).intersection(Rect2i(Vector2i.ZERO, viewport_size))
	_clip_started = Time.get_ticks_usec()
	_clip_active = true


func _capture_clip_frame() -> void:
	_clip_pending = true
	await RenderingServer.frame_post_draw
	var now := Time.get_ticks_usec()
	_clip_last_capture = now
	var source := get_viewport().get_texture().get_image()
	if source != null and not source.is_empty():
		_clip_images.append(source.get_region(_clip_rect))
		_clip_frames.append({"index": _clip_frames.size(), "capture_usec": now,
			"animation": str(_sprite.animation), "frame": _sprite.frame,
			"hero_hp": _hero.current_hp, "enemy_ap": _enemy.current_ap,
			"readback_and_crop_ms": float(Time.get_ticks_usec() - now) / 1000.0})
	_clip_pending = false


func _flush_clip() -> void:
	if not _clip_enabled:
		return
	var directory := _output.path_join("clip")
	DirAccess.make_dir_recursive_absolute(directory)
	for index in _clip_images.size():
		var path := directory.path_join("frame_%04d.png" % index)
		if _clip_images[index].save_png(path) == OK:
			_clip_frames[index]["path"] = path
		else:
			_errors.append("clip_frame_write_failed:%d" % index)
	_clip_report = {"enabled": true, "schema": "dd.spectre.real-enemy-gameplay-clip.v1",
		"source": "Real viewport screenshot after frame_post_draw; fixed crop only",
		"target_fps": 30, "maximum_frames": CLIP_MAX_FRAMES, "frame_count": _clip_frames.size(),
		"frame_limit_reached": _clip_frames.size() >= CLIP_MAX_FRAMES,
		"rectangle_px": [_clip_rect.position.x, _clip_rect.position.y, _clip_rect.size.x, _clip_rect.size.y],
		"started_usec": _clip_started, "ended_usec": _clip_ended, "frames": _clip_frames,
		"timing_note": "Presentation capture. GPU readback may perturb playback; PNG compression deferred after all enemy actions. Encode using recorded wall timestamps."}
	var path := directory.path_join("clip_manifest.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_clip_report, "  "))
		file.close()
		_clip_report["manifest_path"] = path
	else:
		_errors.append("clip_manifest_write_failed")
	_clip_images.clear()


func _cell_array(cell: Vector2i) -> Array[int]:
	return [cell.x, cell.y]


func _finish(details: Dictionary) -> void:
	_enemy_observing = false
	_clip_active = false
	var report := {"schema": "dd.spectre.sprite-courtyard-validation.v1", "ok": _errors.is_empty(),
		"errors": _errors, "godot_version": Engine.get_version_info().get("string", ""),
		"renderer": RenderingServer.get_current_rendering_method()}
	report.merge(details)
	var file := FileAccess.open(_output.path_join("runtime_validation.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	else:
		report["ok"] = false
		push_error("Cannot write Spectre sprite validation report: %s" % _output)
	print("SPECTRE_SPRITE_VALIDATION ", JSON.stringify(report))
	get_tree().quit(0 if bool(report.ok) else 1)
