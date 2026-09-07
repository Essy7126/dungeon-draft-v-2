extends "res://tools/achilles_sprite_validation/courtyard_sprite_probe.gd"

const VISUAL_RESOLVER := preload("res://data/visuals/achilles/achilles_spell_visual_resolver.gd")
const REGISTERED_SCRIPT := "res://battle/painted/registered_terrain/registered_terrain_battle.gd"
const STRIKE := &"achilles_peleid_strike"
const DASH := &"achilles_fulminant_dash"
const SHOT := &"achilles_pelion_shot"
const GUARD := &"achilles_bronze_guard"
const COMPASS := {"N": &"north", "E": &"east", "S": &"south", "W": &"west"}

var configuration: Dictionary = {}
var placement: Dictionary = {}
var progression: Dictionary = {}
var _battle: Node
var _hero: Unit
var _interaction: Node
var _actions: Array[Dictionary] = []
var _active: Dictionary = {}
var _events: Array[Dictionary] = []
var _poses: Array[Dictionary] = []
var _effects: Array[Dictionary] = []
var _effect_keys: Dictionary = {}
var _effect_validation: Dictionary = {}
var _last_pose := ""
var _finished := false
var _guard_seen := false
var _guard_phases: Array[String] = []
var _guard_follow_error := 0.0
var _barrier_events: Array[Dictionary] = []
var _clip_enabled := false
var _clip_pending := false
var _clip_started := 0
var _clip_last := 0
var _clip_ended := 0
var _clip_rect := Rect2i()
var _clip_images: Array[Image] = []
var _clip_frames: Array[Dictionary] = []
var _clip_report: Dictionary = {"enabled": false}
var _source_sprite_frames := ""
var _actual_scene_path := ""
var _actual_hero_data_path := ""
var _latest_runtime: Dictionary = {}
var _reaction_observing := false
var _reaction_origin := Vector2.ZERO
var _reaction_maximum_travel := 0.0
var _hit_spans: Array[Dictionary] = []
var _open_hit: Dictionary = {}
var _death_evidence := {"unit_deaths": 0, "visual_finishes": 0, "clip_started_usec": 0, "finished_usec": 0, "alpha_at_finish": 1.0}
const CLIP_MAX_FRAMES := 360
const CLIP_INTERVAL_USEC := 50000


func _ready() -> void:
	_output = ProjectSettings.globalize_path("res://artifacts/achilles_kit_sprite_validation_v2")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--artifact-dir="):
			_output = ProjectSettings.globalize_path(argument.trim_prefix("--artifact-dir="))
	_capture_enabled = DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().has("--no-screenshots")
	_clip_enabled = _capture_enabled and OS.get_cmdline_user_args().has("--capture-clip")
	DirAccess.make_dir_recursive_absolute(_output)
	_run.call_deferred()


func _run() -> void:
	var deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline and not _finished:
		await get_tree().process_frame
		var candidate := get_tree().current_scene
		if candidate != null and _script_inherits(candidate, REGISTERED_SCRIPT) \
				and bool(candidate.get("runtime_ready_state")) and bool(candidate.get("registered_terrain_ready")):
			_battle = candidate
			_actual_scene_path = candidate.scene_file_path
			break
	if _finished:
		return
	if _battle == null:
		_errors.append("registered_terrain_battle_timeout")
		await _finish_startup_failure(_battle, "runtime_ready")
		return
	if not await _wait_for_real_deployment(_battle, 15000):
		_errors.append("real_deployment_timeout")
		await _finish_startup_failure(_battle, "deployment")
		return
	_interaction = INTERACTIONS.new()
	add_child(_interaction)
	if not await _wait_for_input(10000):
		_errors.append("real_player_intent_timeout")
		await _finish_startup_failure(_battle, "player_intent")
		return
	for unit: Unit in _battle.get("units"):
		if unit.team == 0:
			_hero = unit
	if _hero == null:
		_errors.append("canonical_hero_missing")
		_finish({})
		return
	_actual_hero_data_path = _hero.character_data.resource_path
	_observed_unit_view = (_battle.get("_unit_views") as Dictionary).get(_hero) as Node2D
	_observed_visual = _observed_unit_view.get_optional_visual() if _observed_unit_view != null else null
	if _observed_visual == null or not _observed_visual.has_method("get_visual_runtime_state"):
		_errors.append("canonical_visual_facade_missing")
		_finish({})
		return
	var sprites := _observed_visual.find_children("*", "AnimatedSprite2D", true, false)
	var state: Dictionary = _observed_visual.get_visual_runtime_state()
	if sprites.size() != 1 or str(state.get("ACHILLES_VISUAL_BACKEND_ACTIVE", "")) != "SPRITE_2D" \
			or not _observed_visual.find_children("*", "Node3D", true, false).is_empty() \
			or not _observed_visual.find_children("*", "SubViewport", true, false).is_empty():
		_errors.append("canonical_hero_not_exclusively_sprite_2d")
		_finish({"runtime_state": state})
		return
	_sprite = sprites[0] as AnimatedSprite2D
	_source_sprite_frames = _sprite.sprite_frames.resource_path
	_latest_runtime = state
	_hero.died.connect(_on_observed_hero_died)
	_observed_visual.death_animation_finished.connect(_on_observed_death_finished)
	_observed_visual.cast_release_reached.connect(_on_visual_release)
	_observed_visual.animation_finished.connect(_on_visual_finished)
	_sprite.animation_changed.connect(_on_sprite_animation_changed)
	_sprite.frame_changed.connect(_on_sprite_frame_changed)
	EventBus.spell_cast.connect(_on_spell_cast)
	EventBus.spell_visual_resolved.connect(_on_spell_visual_resolved)
	EventBus.unit_visual_movement_finished.connect(_on_actual_movement_arrived)
	EventBus.health_damage_taken.connect(_on_health_damage)
	EventBus.unit_pushed.connect(_on_pushed)
	var adapter := _battle.get("_mastery_adapter") as MasteryCombatAdapter
	if adapter != null:
		adapter.barrier_changed.connect(_on_barrier_changed)
	_observe = true
	var initial_rest := await _verify_stable_rest(_observed_visual, _observed_unit_view, "initial")
	if _clip_enabled:
		_begin_clip()
	var walk := await _walk_to_scenario_start()
	var facing_rest := await _verify_stable_rest(_observed_visual, _observed_unit_view, "after_real_walk")
	if _hero.facing_dir != Vector2i(placement.direction_vector):
		_errors.append("real_walk_did_not_set_requested_facing")
	var scenario := str(configuration.scenario)
	if scenario in ["combo", "bastion", "counter", "hit_death"]:
		await _cast(GUARD, _hero.grid_pos)
		if not _guard_seen:
			_errors.append("bronze_guard_effect_not_observed_on_real_unit_view")
	if scenario in ["combo", "bastion"] and _errors.is_empty():
		await _cast(DASH, Vector2i(placement.dash_cell))
	if scenario == "combo" and _errors.is_empty():
		await _cast(STRIKE, _hero.grid_pos + Vector2i(placement.direction_vector))
	if scenario == "shot" and _errors.is_empty():
		await _cast(SHOT, Vector2i(placement.shot_cell))
	var counter: Dictionary = {}
	if scenario == "counter" and _errors.is_empty():
		counter = await _counter_turn()
	var damage_death: Dictionary = {}
	if scenario == "hit_death" and _errors.is_empty():
		damage_death = await _run_damage_death_turns()
	var final_rest: Dictionary = {"not_applicable": "Hero died through real enemy attacks"}
	if _hero.is_alive and is_instance_valid(_observed_visual):
		await get_tree().create_timer(0.2).timeout
		final_rest = await _verify_stable_rest(_observed_visual, _observed_unit_view, "after_actions")
		if _capture_enabled:
			await _capture_current_state("idle", "final_rest")
	_check_actual_effects(counter)
	_clip_ended = Time.get_ticks_usec()
	_observe = false
	deadline = Time.get_ticks_msec() + 2000
	while (_capture_jobs > 0 or _clip_pending) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if _clip_enabled:
		# End only after the last queued readback has completed; leave its
		# final real frame on screen long enough for a positive GIF interval.
		await get_tree().create_timer(0.06).timeout
		_clip_ended = Time.get_ticks_usec()
	_flush_deferred_captures()
	_flush_clip()
	if _guard_follow_error > 0.01:
		_errors.append("guard_effect_drifted_from_unit_anchor")
	_finish({"actual_scene": _actual_scene_path, "actual_hero_data": _actual_hero_data_path,
		"actual_sprite_frames": _source_sprite_frames,
		"startup_observations": _startup_observations, "deployment_clicks": _deployment_clicks,
		"stable_rest_before": initial_rest, "real_walk": walk, "stable_rest_after_walk": facing_rest,
		"actions": _actions, "counter_turn": counter, "real_hit_and_death": damage_death, "stable_rest_after": final_rest,
		"runtime_state": _latest_runtime,
		"poses": _poses, "events": _events, "effects": _effects, "effect_validation": _effect_validation,
		"barrier_events": _barrier_events,
		"guard_phases": _guard_phases, "maximum_guard_anchor_error_px": _guard_follow_error,
		"screenshots": _captures, "capture_clip": _clip_report,
		"capture_work_intervals": _capture_work_intervals,
		"clean_timing_run": not _capture_enabled and not _clip_enabled})


func _script_inherits(node: Node, path: String) -> bool:
	var script := node.get_script() as Script
	while script != null:
		if script.resource_path == path:
			return true
		script = script.get_base_script()
	return false


func _wait_for_input(timeout_ms: int) -> bool:
	if not await _interaction._wait_for_player(_battle, timeout_ms):
		return false
	var hud = _battle.get("_hud_port")
	var banner: Control = hud.get_turn_intro_banner() as Control if hud != null else null
	var deadline := Time.get_ticks_msec() + 5000
	while is_instance_valid(banner) and banner.visible and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	return bool(_battle._can_accept_player_intent())


func _walk_to_scenario_start() -> Dictionary:
	var destination := Vector2i(placement.hero_cell)
	var before := _unit_snapshot(_hero)
	var finder := _battle.get("pathfinder") as Pathfinder
	var path := finder.find_path(_hero.grid_pos, destination, _hero)
	var cost := int(finder.path_cost_breakdown(path, _hero).get("total", 0))
	if path.size() != 2 or cost <= 0:
		_errors.append("one_cell_facing_walk_not_legal")
		return {"path": path}
	_battle._on_move_pressed()
	var route := _click(destination)
	var deadline := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if _hero.grid_pos == destination and bool(_battle._can_accept_player_intent()):
			break
	var okay: bool = _hero.grid_pos == destination and _hero.current_mp == int(before.mp) - cost \
		and _hero.current_ap == int(before.ap) and _view_destination_error(destination) <= 0.01
	if not okay:
		_errors.append("real_facing_walk_failed")
	return {"ok": okay, "before": before, "after": _unit_snapshot(_hero), "route": route, "cost": cost}


func _cast(spell_id: StringName, target: Vector2i) -> void:
	if not await _wait_for_input(5000):
		_errors.append("player_not_ready_for:%s" % spell_id)
		return
	var spell := _spell(spell_id)
	var caster := _battle.get("spell_caster") as SpellCaster
	var reason: StringName = caster.get_cast_failure_reason(_hero, spell, target)
	if reason != &"":
		_errors.append("illegal_scenario_cast:%s:%s" % [spell_id, reason])
		return
	var adapter := _battle.get("_mastery_adapter") as MasteryCombatAdapter
	var profile: Dictionary = adapter.spell_profile(_hero, spell)
	var presentation := VISUAL_RESOLVER.resolve(spell, _hero, profile)
	var preview: Array = adapter.preview_target_cells(_hero, spell, target)
	var expected_hits := _expected_hit_count(spell_id)
	_active = {"spell_id": str(spell_id), "target": [target.x, target.y],
		"before": _unit_snapshot(_hero), "enemies_before": _enemy_snapshots(),
		"expected_ap_cost": _hero.get_spell_ap_cost(spell), "uses_before": _hero.get_spell_uses(spell),
		"presentation": presentation, "gameplay_profile": profile, "preview_cells": preview,
		"expected_damaged_enemies": expected_hits, "input_usec": Time.get_ticks_usec(),
		"animation_started_usec": 0, "release_usec": 0, "release_engine_frame": -1,
		"finish_usec": 0, "releases": 0, "finishes": 0, "events": [],
		"clips": [], "max_view_travel_px": 0.0, "view_start": _observed_unit_view.position,
		"view_arrival_usec": 0, "movement_arrival_usec": 0, "movement_arrival_count": 0,
		"non_charge_samples_during_dash": 0}
	_battle._on_spell_pressed(spell)
	_active["input_route"] = _click(target)
	var facing_request: Dictionary = _battle.get("_mastery_facing_cast")
	if not facing_request.is_empty():
		_active["facing_prompt_before_costs"] = _hero.current_ap == int(_active.before.ap)
		_battle._on_mastery_option(COMPASS[str(configuration.direction)])
	var deadline := Time.get_ticks_msec() + 9000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		_resolve_optional_choice()
		var resolved: bool = _hero.current_ap == int(_active.before.ap) - int(_active.expected_ap_cost) \
			and not bool(_battle.get("_spell_resolution_pending"))
		var at_rest := str(_sprite.animation).begins_with("idle_")
		var at_destination: bool = spell_id != DASH or (_hero.grid_pos == target and _view_destination_error(target) < 0.01)
		if resolved and at_rest and at_destination and bool(_battle._can_accept_player_intent()):
			break
	await get_tree().create_timer(0.15).timeout
	_active["after"] = _unit_snapshot(_hero)
	_active["enemies_after"] = _enemy_snapshots()
	_active["uses_after"] = _hero.get_spell_uses(spell)
	_active["controller_returned_idle"] = ( _battle.get("turn_state") as TurnState).current == TurnState.State.IDLE
	_active["sprite_returned_idle"] = str(_sprite.animation) == "idle_%s" % configuration.direction and _sprite.frame == 0
	_active["view_destination_error_px"] = _view_destination_error(_hero.grid_pos)
	_active["barrier_cells_after"] = adapter.barrier_cells()
	_active["observation_end_usec"] = Time.get_ticks_usec()
	_check_action(spell_id, expected_hits)
	_active.erase("view_start")
	_actions.append(_active.duplicate(true))
	_active = {}


func _check_action(spell_id: StringName, expected_hits: int) -> void:
	var prefix := "action_%s:" % spell_id
	if _hero.current_ap != int(_active.before.ap) - int(_active.expected_ap_cost) \
			or int(_active.uses_after) != int(_active.uses_before) + 1:
		_errors.append(prefix + "cost_or_manual_use_not_once")
	if int(_active.releases) != 1 or (spell_id != DASH and int(_active.finishes) != 1) \
			or (spell_id == DASH and int(_active.finishes) > 1):
		_errors.append(prefix + "visual_marker_or_finish_not_unique")
	if not bool(_active.controller_returned_idle) or not bool(_active.sprite_returned_idle):
		_errors.append(prefix + "did_not_return_to_correct_idle")
	var expected_clip := "%s_%s" % [_active.presentation.animation_stem, configuration.direction]
	if not (_active.clips as Array).has(expected_clip):
		_errors.append(prefix + "expected_family_direction_not_played:" + expected_clip)
	var hits: Dictionary = {}
	var cast_events := 0
	for event: Dictionary in _active.events:
		if event.kind == "spell_cast" and event.actor_id == _hero.get_instance_id():
			cast_events += 1
		if event.kind != "health_damage" or event.actor_id != _hero.get_instance_id():
			continue
		hits[event.target_id] = int(hits.get(event.target_id, 0)) + 1
		# Battle's release subscriber may resolve damage before this probe's
		# subscriber is called, within the same signal stack and engine frame.
		if int(event.engine_frame) < int(_active.release_engine_frame):
			_errors.append(prefix + "health_damage_before_visual_release_frame")
		if spell_id == DASH and configuration.kit == "aeacus" and (int(_active.movement_arrival_usec) == 0 \
				or int(event.time_usec) < int(_active.movement_arrival_usec)):
			_errors.append(prefix + "bastion_damage_before_actual_view_arrival")
	for count: int in hits.values():
		if count != 1:
			_errors.append(prefix + "duplicate_target_damage")
	_active["damaged_enemy_count"] = hits.size()
	if hits.size() != expected_hits or cast_events != 1:
		_errors.append(prefix + "unexpected_damage_geometry_or_cast_count")
	if spell_id == GUARD:
		if _hero.get_shield_value(GUARD) <= 0:
			_errors.append(prefix + "canonical_sourced_shield_missing")
		if configuration.kit == "aeacus" and (_active.barrier_cells_after as Array).size() != 3:
			_errors.append(prefix + "three_cell_rampart_missing")
	if spell_id == DASH:
		if float(_active.view_destination_error_px) > 0.01 or float(_active.max_view_travel_px) <= 1.0 \
				or int(_active.view_arrival_usec) <= int(_active.release_usec):
			_errors.append(prefix + "real_view_did_not_travel_after_release")
		if _hero.current_mp != int(_active.before.mp):
			_errors.append(prefix + "dash_spent_movement_points")
		if int(_active.non_charge_samples_during_dash) > 0:
			_errors.append(prefix + "charge_pose_ended_before_real_arrival")
		if configuration.kit == "aeacus" and _hero.current_shield >= int(_active.before.shield):
			_errors.append(prefix + "bastion_did_not_consume_guard")
		if int(_active.movement_arrival_count) != 1:
			_errors.append(prefix + "actual_movement_arrival_not_unique")


func _expected_hit_count(spell_id: StringName) -> int:
	if spell_id == SHOT:
		return 3 if configuration.kit in ["chiron", "volley"] else 1
	if spell_id == STRIKE:
		return 2 if configuration.kit == "wrath" else 1
	if spell_id == DASH and configuration.kit == "aeacus":
		return 2
	return 0


func _counter_turn() -> Dictionary:
	var before := _unit_snapshot(_hero)
	var strike := _spell(STRIKE)
	var uses := _hero.get_spell_uses(strike)
	var event_start := _events.size()
	_battle._on_end_turn_pressed()
	var confirmation: Node = _battle.get("_end_turn_confirmation")
	if confirmation != null and confirmation.is_open():
		confirmation._on_confirmed()
	var left_player_turn := false
	var deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		_resolve_optional_choice()
		if _battle.get_active_unit() != _hero:
			left_player_turn = true
		if left_player_turn and _battle.get_active_unit() == _hero and bool(_battle._can_accept_player_intent()):
			break
	var automatic: Array[Dictionary] = []
	var enemy_casts := 0
	for event: Dictionary in _events.slice(event_start):
		if event.kind == "spell_cast" and event.actor_id != _hero.get_instance_id():
			enemy_casts += 1
		if event.kind == "spell_visual_resolved" and event.actor_id == _hero.get_instance_id() \
				and event.spell_id == str(STRIKE) and bool(event.automatic):
			automatic.append(event)
	if not left_player_turn or enemy_casts == 0 or automatic.size() != 1:
		_errors.append("real_enemy_turn_counter_not_exactly_once")
	if automatic.size() == 1 and int(automatic[0].hero_strike_uses) != uses:
		_errors.append("automatic_counter_consumed_manual_strike_use")
	if automatic.size() == 1 and int(automatic[0].hero_ap) != int(before.ap):
		_errors.append("automatic_counter_spent_action_points")
	return {"source": "Normal end-turn confirmation and real enemy AI; no forced damage or automatic cast invocation",
		"before": before, "after_next_activation": _unit_snapshot(_hero), "enemy_casts": enemy_casts,
		"automatic_strikes": automatic, "strike_uses_before": uses, "strike_uses_after": _hero.get_spell_uses(strike),
		"reaction_telemetry": _hero.mastery_runtime.telemetry_reports()}


func _resolve_optional_choice() -> void:
	if _battle.get("_mastery_choice") != null:
		# These cases exercise equipped mechanics, not optional free moves or
		# follow-up decisions. Decline via the same callback as the visible UI.
		_battle._on_mastery_decline()


func _process(_delta: float) -> void:
	if not _observe or not is_instance_valid(_sprite):
		return
	_latest_runtime = _observed_visual.get_visual_runtime_state()
	if _reaction_observing:
		_reaction_maximum_travel = maxf(_reaction_maximum_travel, _reaction_origin.distance_to(_observed_unit_view.position))
		var reaction_stem := str(_sprite.animation).get_slice("_", 0)
		var reaction_label := "real_%s_%s_%d" % [reaction_stem, configuration.direction, _sprite.frame]
		if _capture_enabled and reaction_stem in ["hit", "death"] and _sprite.frame >= 1 \
				and not _captures.has(reaction_label) and not _pending_captures.has(reaction_label):
			_capture_current_state(reaction_stem, reaction_label)
	var key := "%s:%d" % [_sprite.animation, _sprite.frame]
	if key != _last_pose:
		_last_pose = key
		_record_pose("process")
	if not _active.is_empty():
		var initial: Vector2 = _active.view_start
		_active.max_view_travel_px = maxf(float(_active.max_view_travel_px), initial.distance_to(_observed_unit_view.position))
		if _active.spell_id == str(DASH) and int(_active.release_usec) > 0:
			var destination := Vector2i(placement.dash_cell)
			if _view_destination_error(destination) < 0.01 and int(_active.view_arrival_usec) == 0:
				_active.view_arrival_usec = Time.get_ticks_usec()
			elif _view_destination_error(destination) >= 0.01 and not str(_sprite.animation).begins_with("dash_"):
				_active.non_charge_samples_during_dash += 1
		var stem := str(_sprite.animation).get_slice("_", 0)
		var label := "%s_%s_%d" % [_active.spell_id, stem, _sprite.frame]
		if _capture_enabled and stem != "idle" and _sprite.frame >= 1 \
				and not _captures.has(label) and not _pending_captures.has(label):
			_capture_current_state(stem, label)
	_observe_effects()
	if _clip_enabled and not _clip_pending and _clip_started > 0 \
			and _clip_frames.size() < CLIP_MAX_FRAMES and Time.get_ticks_usec() - _clip_last >= CLIP_INTERVAL_USEC:
		_capture_clip_frame()


func _observe_effects() -> void:
	for child: Node in _observed_unit_view.get_children():
		if child is VFXShieldSpriteEffect and not child.is_queued_for_deletion():
			_guard_seen = true
			var phase := str(child.get_phase_id())
			if not _guard_phases.has(phase):
				_guard_phases.append(phase)
			_guard_follow_error = maxf(_guard_follow_error, child.get_global_transform_with_canvas().origin.distance_to(
				_observed_unit_view.get_global_transform_with_canvas().origin))
	for effect: Node in get_tree().get_nodes_in_group("achilles_spell_sprite_vfx"):
		if not effect.has_method("get_visual_runtime_state"):
			continue
		var state: Dictionary = effect.get_visual_runtime_state()
		var drawn := _effect_draw_snapshot(effect)
		var key := "%d:%s:%s:%s" % [effect.get_instance_id(), state.get("phase", ""),
			state.get("impact_reached", false), str(drawn.texture_ids)]
		if not _effect_keys.has(key):
			_effect_keys[key] = true
			_effects.append({"time_usec": Time.get_ticks_usec(), "engine_frame": Engine.get_process_frames(),
				"effect_id": effect.get_instance_id(), "state": state, "drawn": drawn})
		var phase := str(state.get("phase", ""))
		if _capture_enabled and phase in ["flight", "impact", "hold"] and not bool(state.get("closed", false)) \
				and (float(state.get("elapsed", 0.0)) >= 0.035 or phase == "hold"):
			var label := "effect_%s_%s_%s_%s_%d" % [state.family, state.variant, state.animation, phase, effect.get_instance_id()]
			if not _captures.has(label) and not _pending_captures.has(label):
				_capture_effect_state(effect, phase, label)


func _on_sprite_animation_changed() -> void:
	_record_reaction_transition()
	_record_pose("animation_changed")
	if _active.is_empty():
		return
	var clip := str(_sprite.animation)
	if not (_active.clips as Array).has(clip):
		(_active.clips as Array).append(clip)
	if clip.begins_with(str(_active.presentation.animation_stem) + "_") and int(_active.animation_started_usec) == 0:
		_active.animation_started_usec = Time.get_ticks_usec()


func _on_sprite_frame_changed() -> void:
	_record_pose("frame_changed")


func _record_pose(kind: String) -> void:
	if not is_instance_valid(_sprite) or not is_instance_valid(_observed_unit_view):
		return
	if _poses.size() < 1200:
		_poses.append({"kind": kind, "time_usec": Time.get_ticks_usec(), "engine_frame": Engine.get_process_frames(),
			"clip": str(_sprite.animation), "frame": _sprite.frame, "playing": _sprite.is_playing(),
			"hero_cell": _hero.grid_pos, "unit_view_position": _observed_unit_view.position,
			"sprite_position": _sprite.position, "facade_position": _observed_visual.position,
			"runtime": _observed_visual.get_visual_runtime_state()})


func _on_visual_release() -> void:
	if _active.is_empty():
		_record_event({"kind": "unowned_visual_release"})
		return
	_active.releases += 1
	_active.release_usec = Time.get_ticks_usec()
	_active.release_engine_frame = Engine.get_process_frames()
	_active["release_frame"] = _sprite.frame
	_active["release_after_animation_ms"] = float(int(_active.release_usec) - int(_active.animation_started_usec)) / 1000.0
	_record_event({"kind": "visual_release"})


func _on_visual_finished(clip: StringName) -> void:
	if _active.is_empty():
		_record_event({"kind": "unowned_visual_finish", "finished_clip": str(clip)})
		return
	_active.finishes += 1
	_active.finish_usec = Time.get_ticks_usec()
	_active["duration_after_animation_ms"] = float(int(_active.finish_usec) - int(_active.animation_started_usec)) / 1000.0
	_record_event({"kind": "visual_finish", "finished_clip": str(clip)})


func _on_spell_cast(actor: Unit, spell: Spell, report: Dictionary) -> void:
	_record_event({"kind": "spell_cast", "actor_id": actor.get_instance_id(), "actor": actor.unit_name,
		"spell_id": str(spell.get_effective_spell_id()), "report": report.duplicate(true),
		"hero_ap": _hero.current_ap, "hero_hp": _hero.current_hp, "hero_shield": _hero.current_shield,
		"hero_strike_uses": _hero.get_spell_uses(_spell(STRIKE)),
		"attack_classification": (_battle.get("spell_caster") as SpellCaster).get_action_classification(spell),
		"hero_facing": _hero.facing_dir, "actor_cell": actor.grid_pos,
		"sector_from_hero": DirectionalSectorResolver.classify(_hero.grid_pos, _hero.facing_dir, actor.grid_pos)})


func _on_spell_visual_resolved(actor: Unit, spell: Spell, report: Dictionary, presentation: Dictionary) -> void:
	_record_event({"kind": "spell_visual_resolved", "actor_id": actor.get_instance_id(),
		"spell_id": str(spell.get_effective_spell_id()), "report": report.duplicate(true),
		"presentation": presentation.duplicate(true), "automatic": bool(presentation.get("automatic", false)),
		"hero_ap": _hero.current_ap, "hero_strike_uses": _hero.get_spell_uses(_spell(STRIKE))})


func _on_actual_movement_arrived(unit: Unit) -> void:
	if unit != _hero or _active.is_empty() or _active.spell_id != str(DASH):
		return
	_active.movement_arrival_count += 1
	_active.movement_arrival_usec = Time.get_ticks_usec()
	_active["movement_arrival_position_error_px"] = _view_destination_error(unit.grid_pos)
	if float(_active.movement_arrival_position_error_px) > 0.01:
		_errors.append("movement_arrival_signal_before_unit_view_contact")
	_record_event({"kind": "actual_movement_arrival", "cell": unit.grid_pos})


func _on_health_damage(target: Unit, attacker: Unit, amount: int, category: Variant, element: Variant, critical: bool) -> void:
	_record_event({"kind": "health_damage", "actor_id": attacker.get_instance_id() if attacker != null else 0,
		"target_id": target.get_instance_id(), "target": target.unit_name, "amount": amount,
		"category": category, "element": element, "critical": critical, "hp_after": target.current_hp})


func _on_pushed(unit: Unit, from_cell: Vector2i, to_cell: Vector2i, collision: bool) -> void:
	_record_event({"kind": "unit_pushed", "unit_id": unit.get_instance_id(), "unit": unit.unit_name,
		"from": from_cell, "to": to_cell, "collision": collision})


func _on_barrier_changed(cells: Array) -> void:
	_barrier_events.append({"time_usec": Time.get_ticks_usec(), "cells": cells.duplicate()})


func _record_event(event: Dictionary) -> void:
	event["time_usec"] = Time.get_ticks_usec()
	event["engine_frame"] = Engine.get_process_frames()
	event["hero_clip"] = str(_sprite.animation) if is_instance_valid(_sprite) else ""
	event["hero_frame"] = _sprite.frame if is_instance_valid(_sprite) else -1
	_events.append(event)
	if not _active.is_empty():
		(_active.events as Array).append(event)


func _spell(spell_id: StringName) -> Spell:
	for spell: Spell in _hero.spells:
		if spell.get_effective_spell_id() == spell_id:
			return spell
	return null


func _unit_snapshot(unit: Unit) -> Dictionary:
	return {"instance_id": unit.get_instance_id(), "name": unit.unit_name, "cell": unit.grid_pos,
		"hp": unit.current_hp, "ap": unit.current_ap, "mp": unit.current_mp,
		"shield": unit.current_shield, "guard": unit.get_shield_value(GUARD), "alive": unit.is_alive}


func _enemy_snapshots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for unit: Unit in _battle.get("units"):
		if unit.team != _hero.team:
			result.append(_unit_snapshot(unit))
	return result


func _view_destination_error(cell: Vector2i) -> float:
	var destination: Vector2 = _battle.grid_cell_to_parent_local(cell, _observed_unit_view.get_parent())
	return _observed_unit_view.position.distance_to(destination)


func _click(cell: Vector2i) -> Dictionary:
	var renderer := (_battle.get("arena_assembly") as Dictionary).get("renderer") as ArenaTerrainVisualRenderer
	var root := renderer.node_for_cell(cell)
	var floor_sprite := root.get_node_or_null("Visual") as Sprite2D if root != null else null
	if floor_sprite == null:
		_errors.append("real_target_floor_sprite_missing:%s" % cell)
		return {}
	var polygon := GEOMETRY.sprite_polygon(floor_sprite)
	return _interaction._route_local_pointer(_battle.get("grid_view"), (polygon[0] + polygon[2]) * 0.5, true)


func _begin_clip() -> void:
	var viewport_size := Vector2i(get_viewport().get_visible_rect().size)
	var bounds := Rect2(_observed_unit_view.get_global_transform_with_canvas().origin, Vector2.ONE)
	for view: Node2D in (_battle.get("_unit_views") as Dictionary).values():
		bounds = bounds.expand(view.get_global_transform_with_canvas().origin)
	bounds.position -= Vector2(90, 170)
	bounds.size += Vector2(180, 240)
	_clip_rect = Rect2i(bounds).intersection(Rect2i(Vector2i.ZERO, viewport_size))
	_clip_started = Time.get_ticks_usec()


func _capture_clip_frame() -> void:
	_clip_pending = true
	await RenderingServer.frame_post_draw
	var now := Time.get_ticks_usec()
	_clip_last = now
	var picture := get_viewport().get_texture().get_image()
	if picture != null and not picture.is_empty():
		_clip_images.append(picture.get_region(_clip_rect))
		_clip_frames.append({"index": _clip_frames.size(), "capture_usec": now,
			"hero_animation": str(_sprite.animation) if is_instance_valid(_sprite) else "removed",
			"hero_frame": _sprite.frame if is_instance_valid(_sprite) else -1,
			"active_spell": _active.get("spell_id", ""), "readback_ms": float(Time.get_ticks_usec() - now) / 1000.0})
	_clip_pending = false


func _flush_clip() -> void:
	if not _clip_enabled:
		return
	var directory := _output.path_join("clip")
	DirAccess.make_dir_recursive_absolute(directory)
	for index in _clip_images.size():
		var path := directory.path_join("frame_%04d.png" % index)
		if _clip_images[index].save_png(path) != OK:
			_errors.append("clip_frame_save_failed:%d" % index)
		_clip_frames[index]["path"] = path
	_clip_report = {"enabled": true, "schema": "dd.achilles.kit-gameplay-clip.v2",
		"source": "Real viewport after frame_post_draw, fixed crop, deferred PNG compression",
		"target_fps": 20, "maximum_frames": CLIP_MAX_FRAMES, "frame_count": _clip_frames.size(),
		"frame_limit_reached": _clip_frames.size() >= CLIP_MAX_FRAMES,
		"rectangle_px": [_clip_rect.position.x, _clip_rect.position.y, _clip_rect.size.x, _clip_rect.size.y],
		"started_usec": _clip_started, "ended_usec": _clip_ended, "frames": _clip_frames,
		"timing_note": "GPU readback perturbs this presentation run. Use --no-screenshots separately for cadence."}
	var file := FileAccess.open(directory.path_join("clip_manifest.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_clip_report, "  "))
		file.close()
	_clip_images.clear()


func _finish(details: Dictionary) -> void:
	if _finished:
		return
	_finished = true
	_observe = false
	var report := {"schema": "dd.achilles.kit-sprite-validation.v2", "ok": _errors.is_empty(), "errors": _errors,
		"configuration": configuration, "placement_fixture": placement, "progression_fixture": progression,
		"godot_version": Engine.get_version_info().get("string", ""),
		"renderer": RenderingServer.get_current_rendering_method(),
		"scope": "Real registered terrain and canonical actors. Memory-only authored spawns, legal XP/mastery preparation before battle. Native deployment and GridView click routing. No runtime stats, facing, occupancy, visual state or animation clock mutation. Counter uses real enemy turns."}
	report.merge(details)
	var file := FileAccess.open(_output.path_join("runtime_validation.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	else:
		report.ok = false
		push_error("Cannot write Achilles kit validation report: %s" % _output)
	print("ACHILLES_KIT_SPRITE_VALIDATION ", JSON.stringify(report))
	get_tree().quit(0 if bool(report.ok) else 1)


func _run_damage_death_turns() -> Dictionary:
	var before := _unit_snapshot(_hero)
	var first_event := _events.size()
	var rounds: Array[Dictionary] = []
	_reaction_observing = true
	_reaction_origin = _observed_unit_view.position
	# All damage comes from normal adjacent spectres with their canonical AI,
	# spells and AP. Guard was cast normally once; subsequent turns are passed.
	for round_index in 6:
		if not _hero.is_alive:
			break
		if not await _wait_for_input(7000):
			_errors.append("hit_death_player_turn_not_ready")
			break
		var entry := {"index": round_index + 1, "before": _unit_snapshot(_hero),
			"started_usec": Time.get_ticks_usec(), "left_player_turn": false}
		_battle._on_end_turn_pressed()
		var confirmation: Node = _battle.get("_end_turn_confirmation")
		if confirmation != null and confirmation.is_open():
			confirmation._on_confirmed()
		var deadline := Time.get_ticks_msec() + 20000
		while Time.get_ticks_msec() < deadline and _hero.is_alive and is_instance_valid(_battle):
			await get_tree().process_frame
			if not _hero.is_alive:
				break
			_resolve_optional_choice()
			if _battle.get_active_unit() != _hero:
				entry.left_player_turn = true
			if bool(entry.left_player_turn) and _battle.get_active_unit() == _hero \
					and bool(_battle._can_accept_player_intent()):
				break
		entry["after"] = _unit_snapshot(_hero)
		entry["ended_usec"] = Time.get_ticks_usec()
		rounds.append(entry)
		if _hero.is_alive and Time.get_ticks_msec() >= deadline:
			_errors.append("hit_death_enemy_round_timeout")
			break
		if _hero.is_alive and _hero.current_hp >= int(entry.before.hp):
			_errors.append("hit_death_real_enemy_round_did_not_reduce_hp")
			break
	if _hero.is_alive:
		_errors.append("hit_death_canonical_enemies_did_not_kill_hero")
	else:
		var death_deadline := Time.get_ticks_msec() + 3500
		while int(_death_evidence.visual_finishes) == 0 and Time.get_ticks_msec() < death_deadline \
				and is_instance_valid(_observed_visual):
			await get_tree().process_frame
		# Allow an erroneous late completion to be observed, without keeping
		# the actor alive, delaying the outcome or modifying its presentation.
		await get_tree().create_timer(0.18).timeout
	_reaction_observing = false
	var incoming_damage := 0
	var incoming_hits := 0
	var enemy_casts := 0
	var leaked_markers := 0
	for event: Dictionary in _events.slice(first_event):
		if event.kind == "health_damage" and int(event.target_id) == _hero.get_instance_id():
			incoming_damage += int(event.amount)
			incoming_hits += 1
		if event.kind == "spell_cast" and int(event.actor_id) != _hero.get_instance_id():
			enemy_casts += 1
		if event.kind in ["unowned_visual_release", "unowned_visual_finish"]:
			leaked_markers += 1
	var completed_hits := 0
	for span: Dictionary in _hit_spans:
		if str(span.get("next_clip", "")).begins_with("idle_"):
			completed_hits += 1
	if incoming_hits < 2 or enemy_casts < 2 or incoming_damage != int(before.hp) - _hero.current_hp:
		_errors.append("hit_death_incoming_damage_evidence_mismatch")
	if completed_hits < 1:
		_errors.append("real_nonlethal_hit_did_not_play_and_return_idle")
	if int(_death_evidence.unit_deaths) != 1 or int(_death_evidence.visual_finishes) != 1 \
			or int(_death_evidence.clip_started_usec) <= 0:
		_errors.append("real_death_clip_or_finish_missing_or_duplicate")
	if float(_death_evidence.alpha_at_finish) > 0.001:
		_errors.append("real_death_finished_before_fade_completed")
	if leaked_markers != 0:
		_errors.append("hit_or_death_published_attack_marker")
	if _reaction_maximum_travel > 0.01:
		_errors.append("hit_or_death_moved_unit_ground_anchor")
	return {"source": "Normal end-turn UI callbacks and actual canonical enemy turns; no HP edits or forced damage",
		"before": before, "after": _unit_snapshot(_hero), "rounds": rounds,
		"incoming_health_damage": incoming_damage, "incoming_health_hits": incoming_hits,
		"enemy_casts": enemy_casts, "completed_nonlethal_hit_clips": completed_hits,
		"hit_spans": _hit_spans, "death": _death_evidence,
		"unexpected_action_markers": leaked_markers, "maximum_unit_anchor_travel_px": _reaction_maximum_travel,
		"view_removed_after_death": not is_instance_valid(_observed_unit_view)}


func _record_reaction_transition() -> void:
	if not _reaction_observing or not is_instance_valid(_sprite):
		return
	var clip := str(_sprite.animation)
	var now := Time.get_ticks_usec()
	if not _open_hit.is_empty() and not clip.begins_with("hit_"):
		_open_hit["ended_usec"] = now
		_open_hit["duration_ms"] = float(now - int(_open_hit.started_usec)) / 1000.0
		_open_hit["next_clip"] = clip
		_hit_spans.append(_open_hit.duplicate(true))
		_open_hit = {}
	if clip.begins_with("hit_") and _open_hit.is_empty():
		_open_hit = {"clip": clip, "started_usec": now, "hp": _hero.current_hp,
			"unit_view_position": _observed_unit_view.position}
	if clip.begins_with("death_") and int(_death_evidence.clip_started_usec) == 0:
		_death_evidence.clip_started_usec = now
		_death_evidence["clip"] = clip
		_death_evidence["unit_view_position"] = _observed_unit_view.position


func _on_observed_hero_died(_unit: Unit) -> void:
	_death_evidence.unit_deaths += 1
	_death_evidence["unit_died_usec"] = Time.get_ticks_usec()
	_record_event({"kind": "hero_died", "hp": _hero.current_hp})


func _on_observed_death_finished() -> void:
	_death_evidence.visual_finishes += 1
	_death_evidence.finished_usec = Time.get_ticks_usec()
	_death_evidence.alpha_at_finish = _observed_visual.modulate.a
	_death_evidence["duration_ms"] = float(int(_death_evidence.finished_usec) - int(_death_evidence.clip_started_usec)) / 1000.0
	_latest_runtime = _observed_visual.get_visual_runtime_state()
	_record_event({"kind": "hero_death_visual_finished", "alpha": _observed_visual.modulate.a})


func _effect_draw_snapshot(effect: Node) -> Dictionary:
	var result := {"sprite_count": 0, "texture_ids": [], "screen_centers": [], "frames_path": ""}
	var frames := effect.get("_frames") as SpriteFrames
	if frames != null:
		result.frames_path = frames.resource_path
	for child in effect.get_children():
		var sprite := child as Sprite2D
		if sprite != null and sprite.texture != null and sprite.is_visible_in_tree():
			result.sprite_count += 1
			(result.texture_ids as Array).append(sprite.texture.get_instance_id())
			(result.screen_centers as Array).append(sprite.get_global_transform_with_canvas().origin)
	return result


func _capture_effect_state(effect: Node, phase: String, label: String) -> void:
	_pending_captures[label] = true
	_capture_jobs += 1
	await RenderingServer.frame_post_draw
	if not is_instance_valid(effect) or effect.is_queued_for_deletion():
		_pending_captures.erase(label)
		_capture_jobs -= 1
		return
	var state: Dictionary = effect.get_visual_runtime_state()
	if bool(state.get("closed", false)) or str(state.get("phase", "")) != phase:
		_pending_captures.erase(label)
		_capture_jobs -= 1
		return
	var sprite: Sprite2D = null
	for child in effect.get_children():
		if child is Sprite2D and child.texture != null and child.is_visible_in_tree():
			sprite = child
			break
	if sprite != null:
		var started := Time.get_ticks_usec()
		var picture := get_viewport().get_texture().get_image()
		var ended := Time.get_ticks_usec()
		_capture_work_intervals.append({"capture": label, "operation": "GPU_readback_during_playback",
			"started_usec": started, "ended_usec": ended, "duration_ms": float(ended - started) / 1000.0})
		if picture == null or picture.is_empty():
			_errors.append("empty_effect_screenshot:" + label)
		else:
			_captures[label] = {"path": _output.path_join(label + ".png"), "effect_id": effect.get_instance_id(),
				"effect_state": state, "effect_drawn": _effect_draw_snapshot(effect),
				"time_usec": started, "size": [picture.get_width(), picture.get_height()],
				"gpu_readback_ms": float(ended - started) / 1000.0, "compression_deferred_until_after_actions": true}
			_deferred_pngs[label] = {"image": picture, "texture": sprite.texture,
				"transform": sprite.get_global_transform_with_canvas(),
				"offset": sprite.offset - (sprite.texture.get_size() * 0.5 if sprite.centered else Vector2.ZERO)}
	_pending_captures.erase(label)
	_capture_jobs -= 1


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
		if int(entry.drawn.sprite_count) <= 0 or str(entry.drawn.frames_path) != "res://assets/vfx/achilles_kit_v2/effects.tres":
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
		elif spell_id == SHOT:
			var flight := _require_effect(entries, &"arrow", &"flight", prefix, checks)
			var impact := _require_effect(entries, &"impact", &"impact", prefix, checks)
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
		"required_atlas": "res://assets/vfx/achilles_kit_v2/effects.tres", "screenshots_enabled": _capture_enabled}


func _require_effect(entries: Array[Dictionary], animation: StringName, phase: StringName,
		prefix: String, checks: Dictionary) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for entry: Dictionary in entries:
		if StringName(entry.state.get("animation", &"")) == animation and StringName(entry.state.get("phase", &"")) == phase \
				and int(entry.drawn.sprite_count) > 0 and not bool(entry.state.get("closed", false)):
			found.append(entry)
	(checks.required as Array).append({"animation": animation, "phase": phase, "instances": _effect_instance_count(found)})
	if found.is_empty():
		_errors.append(prefix + "required_sprite_effect_missing:%s:%s" % [animation, phase])
	return found


func _effect_instance_count(entries: Array[Dictionary]) -> int:
	var ids: Dictionary = {}
	for entry: Dictionary in entries:
		ids[entry.effect_id] = true
	return ids.size()


func _require_target_count(entries: Array[Dictionary], expected: int, prefix: String) -> void:
	if not entries.any(func(entry): return (entry.state.targets as Array).size() == expected \
		and int(entry.drawn.sprite_count) == expected):
		_errors.append(prefix + "drawn_impact_target_count_mismatch:%d" % expected)
