extends "res://tools/paris_sprite_validation/combat_probe.gd"

const FINAL_TERRAIN_PLAN := "res://data/arenas/black_oath_temple_v1/terrain_plan.json"
const FINAL_ROOM: ArenaDefinition = preload("res://data/rooms/odyssey/room_05.tres")
var _production_initial: Array[Dictionary] = []
var _production_turn_order: Array[Dictionary] = []


func _run() -> void:
	var deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline and not _finished:
		await get_tree().process_frame
		var candidate := get_tree().current_scene
		if candidate != null and _inherits(candidate, REGISTERED_SCRIPT) and bool(candidate.get("runtime_ready_state")) and bool(candidate.get("registered_terrain_ready")):
			_battle = candidate
			break
	if _finished:
		return
	if _battle == null or not await _wait_for_real_deployment(_battle, 15000):
		_errors.append("real_final_battle_or_deployment_timeout")
		_finish({})
		return
	_interaction = INTERACTIONS.new()
	add_child(_interaction)
	if not await _wait_for_input():
		_errors.append("final_player_input_timeout")
		_finish({})
		return
	var roster: Array[StringName] = []
	for unit: Unit in _battle.get("units"):
		_production_initial.append(_snapshot(unit))
		if unit.team == 0 and unit.unit_id == &"achilles":
			_hero = unit
		elif unit.unit_id == &"catabase_shadow_paris":
			_paris = unit
		if unit.team == 1:
			roster.append(unit.unit_id)
	roster.sort()
	if roster != [&"catabase_shadow_paris", &"spectre_greatsword", &"spectre_greatsword"] or _hero == null or _paris == null:
		_errors.append("actual_final_roster_not_paris_and_two_spectres")
		_finish({"actual_roster": roster})
		return
	if str(_battle.get("registered_terrain_plan_path")) != FINAL_TERRAIN_PLAN:
		_errors.append("actual_final_terrain_is_not_black_oath_temple")
	if _paris.current_hp != _paris.max_hp.get_int() or _paris.current_shield != 0 or _paris.combat_form_id != &"spectral":
		_errors.append("production_boss_did_not_start_uninjured_in_spectral_form")
	_observed_unit_view = (_battle.get("_unit_views") as Dictionary).get(_paris) as Node2D
	_observed_visual = _observed_unit_view.get_optional_visual() if _observed_unit_view != null else null
	if _observed_visual == null:
		_errors.append("canonical_final_boss_visual_missing")
		_finish({})
		return
	var sprites := _observed_visual.find_children("*", "AnimatedSprite2D", true, false)
	if sprites.size() != 1 or not _observed_visual.find_children("*", "Node3D", true, false).is_empty() or not _observed_visual.find_children("*", "SubViewport", true, false).is_empty():
		_errors.append("final_boss_not_exclusively_sprite_2d")
		_finish({})
		return
	_sprite = sprites[0] as AnimatedSprite2D
	_observed_frames_path = _sprite.sprite_frames.resource_path
	if _observed_frames_path != FRAMES:
		_errors.append("final_boss_not_using_canonical_spectral_atlas")
	configuration.direction = str(_sprite.animation).get_slice("_", 1)
	_observed_visual.cast_release_reached.connect(_on_release)
	_observed_visual.animation_finished.connect(_on_finish)
	_observed_visual.death_animation_finished.connect(_on_death_finish)
	_observed_visual.transformation_finished.connect(_on_transformation_finished)
	_sprite.animation_changed.connect(_on_animation)
	_paris.died.connect(_on_death)
	_battle.grid.occupancy_changed.connect(_on_occupancy)
	EventBus.turn_started.connect(_on_turn)
	EventBus.spell_cast.connect(_on_spell_cast)
	EventBus.health_damage_taken.connect(_on_damage)
	EventBus.status_applied.connect(_on_status)
	EventBus.unit_pushed.connect(_on_push)
	EventBus.voluntary_movement_prepared.connect(_on_move_prepared)
	EventBus.voluntary_movement_resolved.connect(_on_move_resolved)
	_initial_local_position = _observed_visual.position
	_running = true
	var initial_rest := await _verify_stable_rest(_observed_visual, _observed_unit_view, "final_boss_spawn")
	if _capture_enabled:
		await _capture_current_state("idle", "final_boss_production_deployment")
	if _clip_enabled:
		_begin_clip()
	await _advance_hero_toward_boss()
	for round_index in 3:
		if not _hero.is_alive or not _errors.is_empty():
			break
		await _pass_real_turn()
		if not _casts.is_empty():
			break
	await get_tree().create_timer(0.8).timeout
	var final_rest := await _verify_stable_rest(_observed_visual, _observed_unit_view, "final_boss_after_natural_turn")
	_clip_active = false
	_clip_end = Time.get_ticks_usec()
	_running = false
	deadline = Time.get_ticks_msec() + 3000
	while (_clip_pending or _capture_jobs > 0) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_flush_deferred_captures()
	_flush_clip()
	_validate_production()
	_finish({"actual_scene": _battle.scene_file_path, "actual_terrain_plan": _battle.get("registered_terrain_plan_path"),
		"actual_sprite_frames": _observed_frames_path, "actual_roster": roster,
		"initial_units": _production_initial, "final_paris": _snapshot(_paris), "final_hero": _snapshot(_hero),
		"production_encounter": FINAL_ROOM.encounter_definition.resource_path,
		"production_hero_spawn_zone": FINAL_ROOM.hero_spawn_zone, "production_enemy_spawn_zone": FINAL_ROOM.enemy_spawn_zone,
		"stable_rest_before": initial_rest, "stable_rest_after": final_rest,
		"runtime_state": _runtime, "enemy_turns": _paris_turns, "turn_order": _production_turn_order,
		"real_hero_actions": _hero_actions, "real_ai_casts": _casts, "real_ai_movements": _moves,
		"combat_facts": _facts, "grid_occupancy_events": _occupancy,
		"maximum_local_ground_anchor_error_px": _max_ground_error,
		"maximum_completed_movement_error_px": _max_destination_error,
		"screenshots": _captures, "capture_clip": _clip_report, "effects": _effects,
		"observed_poses": _poses, "states_seen": _states_seen.keys(),
		"capture_work_intervals": _capture_work_intervals, "clean_timing_run": not _capture_enabled,
		"scope": "The canonical Catabase room V, Black Oath Temple, with its untouched Paris-and-two-spectres roster and production formation. Only the start room and legal level-6 progression are declared precombat fixtures. Deployment, movement, enemy decisions, damage and End Turn are real. No previous campaign rooms were simulated or claimed."})


func _advance_hero_toward_boss() -> void:
	var grid := _battle.get("grid") as GridData
	var finder := _battle.get("pathfinder") as Pathfinder
	var best := Vector2i(-1, -1)
	var distance := grid.manhattan(_hero.grid_pos, _paris.grid_pos)
	for y in grid.rows:
		for x in grid.cols:
			var candidate := Vector2i(x, y)
			var next_distance := grid.manhattan(candidate, _paris.grid_pos)
			if next_distance >= distance or not grid.is_walkable(candidate, _hero):
				continue
			var path := finder.find_path(_hero.grid_pos, candidate, _hero)
			if path.size() < 2 or int(finder.path_cost_breakdown(path, _hero).get("total", 999)) > _hero.current_mp:
				continue
			best = candidate
			distance = next_distance
	if best != Vector2i(-1, -1):
		await _hero_walk(best)


func _on_turn(unit: Unit) -> void:
	super._on_turn(unit)
	_production_turn_order.append({"unit_id": str(unit.unit_id), "time_usec": Time.get_ticks_usec(), "cell": unit.grid_pos})


func _validate_production() -> void:
	if _casts.is_empty() or _paris_turns < 1:
		_errors.append("production_boss_never_took_a_real_offensive_turn")
	if _moves.is_empty() and not _has_action("cast") and not _has_action("attack"):
		_errors.append("production_boss_never_animated_in_combat")
	if _max_ground_error > 0.01 or _max_destination_error > 0.01:
		_errors.append("production_boss_anchor_or_arrival_drift")
	for cast: Dictionary in _casts:
		if int(cast.release_count) != 1 or int(cast.finish_count) != 1 or int(cast.spell_count) != 1:
			_errors.append("production_boss_cast_markers_not_once")
		if int(cast.get("resolved_usec", 0)) < int(cast.release_usec) or int(cast.get("ap_after", -1)) != int(cast.ap_before) - int(cast.get("ap_cost", -100)):
			_errors.append("production_boss_spell_timing_or_ap_failure")
		if not bool(cast.get("returned_idle", false)):
			_errors.append("production_boss_cast_did_not_return_idle")
		if not _capture_enabled:
			var expected := float(cast.get("expected_duration", 0.0))
			if expected <= 0.0 or absf(float(cast.get("duration_seconds", 0.0)) - expected) > 0.18:
				_errors.append("production_boss_cast_duration_outside_budget")
			if absf(float(cast.get("release_seconds", 0.0)) - expected * 0.5) > 0.16:
				_errors.append("production_boss_release_outside_budget")
	for movement: Dictionary in _moves:
		if not movement.has("finished_usec") or int(movement.get("mp_after", -1)) != int(movement.mp_before) - int(movement.cost):
			_errors.append("production_boss_movement_budget_or_completion_failed")
	if not _has_fact("hp_damage", _hero, true):
		_errors.append("production_boss_encounter_never_damaged_the_real_hero")
	if _effects.is_empty():
		_errors.append("production_boss_spell_sprites_not_observed")
	for effect: Dictionary in _effects:
		if not bool(effect.canonical_atlas_observed) or int(effect.maximum_sprite_count) <= 0:
			_errors.append("production_boss_effect_not_using_canonical_sprite_atlas")
