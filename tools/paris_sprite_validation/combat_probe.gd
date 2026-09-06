extends "res://tools/achilles_sprite_validation/courtyard_sprite_probe.gd"

const CANVAS_STABILITY := preload("res://tools/paris_sprite_validation/canvas_stability.gd")
const REGISTERED_SCRIPT := "res://battle/painted/registered_terrain/registered_terrain_battle.gd"
const FRAMES := "res://assets/characters/paris/sprites_v1/frames_spectral.tres"
const CAST_ACTIONS := ["attack", "cast"]
const SHOT := &"achilles_pelion_shot"
const STRIKE := &"achilles_peleid_strike"

var configuration: Dictionary = {}
var placement: Dictionary = {}
var progression: Dictionary = {}
var _battle: Node
var _interaction: Node
var _hero: Unit
var _paris: Unit
var _ally: Unit
var _running := false
var _finished := false
var _paris_turns := 0
var _hero_turns := 0
var _hero_activation_before: Dictionary = {}
var _casts: Array[Dictionary] = []
var _active_cast: Dictionary = {}
var _facts: Array[Dictionary] = []
var _moves: Array[Dictionary] = []
var _hero_actions: Array[Dictionary] = []
var _poses: Array[Dictionary] = []
var _last_pose := ""
var _last_action := ""
var _reaction: Dictionary = {}
var _reactions: Array[Dictionary] = []
var _max_ground_error := 0.0
var _max_destination_error := 0.0
var _initial_local_position := Vector2.ZERO
var _runtime: Dictionary = {}
var _deaths := 0
var _death_finishes := 0
var _death_finish_alpha := 1.0
var _observed_frames_path := ""
var _effects: Array[Dictionary] = []
var _effect_by_id: Dictionary = {}
var _clip_enabled := false
var _clip_active := false
var _clip_pending := false
var _clip_start := 0
var _clip_last := 0
var _clip_end := 0
var _clip_rect := Rect2i()
var _clip_images: Array[Image] = []
var _clip_frames: Array[Dictionary] = []
var _clip_report := {"enabled": false}
var _clip_omitted_frames := 0
var _transformations: Array[Dictionary] = []
var _active_transform: Dictionary = {}
var _occupancy: Array[Dictionary] = []
var _form_atlases: Dictionary = {}


func _ready() -> void:
	_output = ProjectSettings.globalize_path("res://artifacts/paris_sprite_validation_v1")
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
		if candidate != null and _inherits(candidate, REGISTERED_SCRIPT) and bool(candidate.get("runtime_ready_state")) and bool(candidate.get("registered_terrain_ready")):
			_battle = candidate
			break
	if _finished:
		return
	if _battle == null or not await _wait_for_real_deployment(_battle, 15000):
		_errors.append("real_battle_or_deployment_timeout")
		_finish({})
		return
	_interaction = INTERACTIONS.new()
	add_child(_interaction)
	if not await _wait_for_input():
		_errors.append("real_player_intent_timeout")
		_finish({})
		return
	for unit: Unit in _battle.get("units"):
		if unit.team == 0:
			_hero = unit
		elif unit.unit_id == &"catabase_shadow_paris":
			_paris = unit
		else:
			_ally = unit
	if _hero == null or _paris == null:
		_errors.append("canonical_hero_or_paris_missing")
		_finish({})
		return
	if _paris.grid_pos != Vector2i(placement.paris_cell):
		_errors.append("real_initial_roles_do_not_match_authored_spawn_fixture")
		_finish({"actual_initial_paris": _snapshot(_paris), "actual_initial_ally": _snapshot(_ally) if _ally != null else {}})
		return
	_observed_unit_view = (_battle.get("_unit_views") as Dictionary).get(_paris) as Node2D
	_observed_visual = _observed_unit_view.get_optional_visual() if _observed_unit_view != null else null
	if _observed_visual == null:
		_errors.append("canonical_paris_visual_missing")
		_finish({})
		return
	var sprites := _observed_visual.find_children("*", "AnimatedSprite2D", true, false)
	if sprites.size() != 1 or not _observed_visual.find_children("*", "Node3D", true, false).is_empty() or not _observed_visual.find_children("*", "SubViewport", true, false).is_empty():
		_errors.append("paris_not_exclusively_sprite_2d")
		_finish({})
		return
	_sprite = sprites[0] as AnimatedSprite2D
	_observed_frames_path = _sprite.sprite_frames.resource_path
	if _observed_frames_path != FRAMES:
		_errors.append("unexpected_sprite_frames:" + _observed_frames_path)
	_observed_visual.cast_release_reached.connect(_on_release)
	_observed_visual.animation_finished.connect(_on_finish)
	_observed_visual.death_animation_finished.connect(_on_death_finish)
	_sprite.animation_changed.connect(_on_animation)
	_paris.died.connect(_on_death)
	_observed_visual.transformation_finished.connect(_on_transformation_finished)
	_battle.grid.occupancy_changed.connect(_on_occupancy)
	EventBus.turn_started.connect(_on_turn)
	EventBus.spell_cast.connect(_on_spell_cast)
	EventBus.health_damage_taken.connect(_on_damage)
	EventBus.healing_applied.connect(_on_heal)
	EventBus.shield_applied.connect(_on_shield)
	EventBus.shield_absorbed.connect(_on_shield_absorbed)
	EventBus.status_applied.connect(_on_status)
	EventBus.unit_pushed.connect(_on_push)
	EventBus.voluntary_movement_prepared.connect(_on_move_prepared)
	EventBus.voluntary_movement_resolved.connect(_on_move_resolved)
	_initial_local_position = _observed_visual.position
	_running = true
	var initial := _snapshot(_paris)
	var initial_ally := _snapshot(_ally) if _ally != null else {}
	var initial_rest := await _verify_stable_rest(_observed_visual, _observed_unit_view, "paris_initial")
	if _clip_enabled:
		_begin_clip()
	var scenario := str(configuration.scenario)
	if scenario in ["transform", "defeat"]:
		for round_index in 12:
			if not _paris.is_alive or not _hero.is_alive or not _errors.is_empty() or _is_infernal():
				break
			await _wound_with_real_hero_combo(_paris)
			if _paris.is_alive:
				await _pass_real_turn()
		if _is_infernal() and _paris.is_alive:
			for round_index in 4:
				if _has_infernal_cast() or not _hero.is_alive:
					break
				await _pass_real_turn()
		if scenario == "defeat":
			for round_index in 12:
				if not _paris.is_alive or not _hero.is_alive or not _errors.is_empty():
					break
				await _wound_with_real_hero_combo(_paris)
				if _paris.is_alive:
					await _pass_real_turn()
	else:
		for round_index in 4:
			if not _hero.is_alive or not _errors.is_empty():
				break
			await _pass_real_turn()
			if _scenario_observed():
				break
	await get_tree().create_timer(0.8).timeout
	var final_rest := {"not_applicable": "Paris died from real Achilles spell damage"}
	if _paris.is_alive and is_instance_valid(_observed_visual):
		final_rest = await _verify_stable_rest(_observed_visual, _observed_unit_view, "paris_after_actions")
	_clip_active = false
	_clip_end = Time.get_ticks_usec()
	_running = false
	deadline = Time.get_ticks_msec() + 3000
	while (_clip_pending or _capture_jobs > 0) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if _clip_enabled:
		await get_tree().create_timer(0.06).timeout
		_clip_end = Time.get_ticks_usec()
	_flush_deferred_captures()
	_flush_clip()
	_validate()
	_finish({"actual_scene": _battle.scene_file_path, "actual_terrain_plan": _battle.get("registered_terrain_plan_path"),
		"actual_sprite_frames": _observed_frames_path, "initial_paris": initial, "initial_ally": initial_ally, "final_paris": _snapshot(_paris),
		"final_hero": _snapshot(_hero), "enemy_turns": _paris_turns, "hero_turns": _hero_turns,
		"stable_rest_before": initial_rest, "stable_rest_after": final_rest,
		"runtime_state": _runtime, "real_hero_actions": _hero_actions,
		"real_ai_casts": _casts, "transformations": _transformations, "grid_occupancy_events": _occupancy, "form_atlas_paths": _form_atlases, "real_ai_movements": _moves, "combat_facts": _facts,
		"observed_poses": _poses, "states_seen": _states_seen.keys(), "reactions": _reactions, "effects": _effects,
		"maximum_local_ground_anchor_error_px": _max_ground_error,
		"maximum_completed_movement_error_px": _max_destination_error,
		"death_events": _deaths, "death_visual_finishes": _death_finishes,
		"death_finish_alpha": _death_finish_alpha,
		"paris_view_removed": not is_instance_valid(_observed_unit_view),
		"screenshots": _captures, "capture_clip": _clip_report,
		"capture_work_intervals": _capture_work_intervals,
		"clean_timing_run": not _capture_enabled})


func _process(_delta: float) -> void:
	if not _running:
		return
	_observe_effects()
	if is_instance_valid(_sprite):
		var clip := str(_sprite.animation)
		var form := str(_observed_visual.get_visual_runtime_state().get("combat_form", ""))
		_form_atlases[form] = _sprite.sprite_frames.resource_path
		var action := clip.get_slice("_", 0)
		_states_seen[clip] = true
		var key := "%s:%d" % [clip, _sprite.frame]
		if key != _last_pose:
			_last_pose = key
			_poses.append({"time_usec": Time.get_ticks_usec(), "animation": clip, "frame": _sprite.frame,
				"paris_cell": _paris.grid_pos, "paris_hp": _paris.current_hp, "combat_form": form, "sprite_flip_h": _sprite.flip_h,
				"view_position": _observed_unit_view.position})
		var profile := _observed_visual.get("sprite_profile") as Resource
		var ground := _sprite.offset + Vector2(profile.get("foot_anchor"))
		if _sprite.centered:
			ground -= Vector2(profile.get("frame_canvas_size")) * 0.5
		_max_ground_error = maxf(_max_ground_error, (_sprite.transform * ground).length())
		_runtime = _observed_visual.get_visual_runtime_state()
		var expected_mirror := clip.ends_with("_S") or clip.ends_with("_W")
		if _sprite.flip_h != expected_mirror and not _errors.has("paris_runtime_mirror_does_not_match_direction"):
			_errors.append("paris_runtime_mirror_does_not_match_direction")
		if _capture_enabled and not _captures.has(action) and not _pending_captures.has(action) and (action == "idle" or _sprite.frame >= 1):
			_capture_current_state(action)
	if _clip_active and not _clip_pending and (_clip_images.size() < 600 or configuration.scenario in ["defeat", "transform"]) and Time.get_ticks_usec() - _clip_last >= 50000:
		_capture_clip_frame()


func _observe_effects() -> void:
	for effect: Node in get_tree().get_nodes_in_group("paris_spell_sprite_vfx"):
		if not effect.has_method("get_debug_state"):
			continue
		var state: Dictionary = effect.get_debug_state()
		var id := effect.get_instance_id()
		var record: Dictionary = _effect_by_id.get(id, {})
		if record.is_empty():
			record = {"instance_id": id, "first_seen_usec": Time.get_ticks_usec(),
				"spell_id": str(state.get("spell_id", "")), "animation": str(state.get("animation", "")),
				"phases": [], "maximum_sprite_count": 0, "canonical_atlas_observed": false}
			_effect_by_id[id] = record
			_effects.append(record)
		record.last_seen_usec = Time.get_ticks_usec()
		var phase := str(state.get("phase", ""))
		if not phase.is_empty() and not (record.phases as Array).has(phase):
			(record.phases as Array).append(phase)
		var sprites := effect.find_children("*", "Sprite2D", true, false)
		record.maximum_sprite_count = maxi(int(record.maximum_sprite_count), sprites.size())
		for sprite: Sprite2D in sprites:
			var texture := sprite.texture
			if texture is AtlasTexture:
				texture = (texture as AtlasTexture).atlas
			if texture != null and texture.resource_path == "res://assets/vfx/paris/sprites_v1/effects.png":
				record.canonical_atlas_observed = true



func _on_animation() -> void:
	var clip := str(_sprite.animation)
	var action := clip.get_slice("_", 0)
	var now := Time.get_ticks_usec()
	if action == "transform" and _active_transform.is_empty():
		_active_transform = {"started_usec": now, "hp": _paris.current_hp, "max_hp": _paris.max_hp.get_int(), "shield": _paris.current_shield, "form_before": str(_observed_visual.get_visual_runtime_state().get("combat_form", "")), "finish_count": 0}
		_transformations.append(_active_transform)
	if not _reaction.is_empty() and action != str(_reaction.action):
		_reaction.finished_usec = now
		_reaction.duration_seconds = float(now - int(_reaction.started_usec)) / 1000000.0
		_reaction = {}
	if action in ["hit", "death"] and action != _last_action:
		_reaction = {"action": action, "animation": clip, "started_usec": now, "finished_usec": 0}
		_reactions.append(_reaction)
	if action in CAST_ACTIONS:
		_active_cast = {"animation": clip, "action": action, "activation": _paris_turns,
			"started_usec": now, "release_usec": 0, "finished_usec": 0,
			"release_count": 0, "finish_count": 0, "spell_count": 0,
			"ap_before": _paris.current_ap, "facts": [], "combat_form": str(_observed_visual.get_visual_runtime_state().get("combat_form", "")), "expected_duration": _clip_duration(_sprite.animation)}
		_casts.append(_active_cast)
	_last_action = action


func _on_release() -> void:
	if _active_cast.is_empty():
		_errors.append("release_without_cast")
		return
	_active_cast.release_count += 1
	_active_cast.release_usec = Time.get_ticks_usec()
	_active_cast.release_frame = _sprite.frame
	_active_cast.release_seconds = float(int(_active_cast.release_usec) - int(_active_cast.started_usec)) / 1000000.0


func _on_finish(_clip: StringName) -> void:
	if _active_cast.is_empty():
		return
	_active_cast.finish_count += 1
	_active_cast.finished_usec = Time.get_ticks_usec()
	_active_cast.duration_seconds = float(int(_active_cast.finished_usec) - int(_active_cast.started_usec)) / 1000000.0
	_active_cast.ap_after = _paris.current_ap
	_active_cast.returned_idle = str(_sprite.animation).begins_with("idle_")
	_active_cast = {}


func _on_spell_cast(actor: Unit, spell: Spell, report: Dictionary) -> void:
	if actor != _paris:
		return
	if _active_cast.is_empty():
		_errors.append("paris_cast_without_body_animation")
		return
	_active_cast.spell_count += 1
	_active_cast.spell_id = str(spell.get_effective_spell_id())
	_active_cast.ap_cost = _paris.get_spell_ap_cost(spell)
	_active_cast.resolved_usec = Time.get_ticks_usec()
	_active_cast.report = report
	_active_cast.actual_caster_cell = actor.grid_pos
	_active_cast.terrain_after = []
	for cell: Vector2i in report.get("terrain_changed", []):
		(_active_cast.terrain_after as Array).append({"cell": cell, "properties": _battle.grid.get_terrain_properties(cell), "effect": _battle.grid.get_effect(cell)})


func _fact(kind: String, actor: Unit, target: Unit, amount: int, extra: Dictionary = {}) -> void:
	var fact := {"kind": kind, "time_usec": Time.get_ticks_usec(), "actor_id": str(actor.unit_id) if actor != null else "",
		"target_id": str(target.unit_id), "target_instance": target.get_instance_id(), "amount": amount,
		"target_hp": target.current_hp, "target_shield": target.current_shield, "target_cell": target.grid_pos}
	fact.merge(extra)
	_facts.append(fact)
	if actor == _paris and not _active_cast.is_empty():
		(_active_cast.facts as Array).append(fact)


func _on_damage(target: Unit, attacker: Unit, amount: int, _category: int, _element: int, _critical: bool) -> void:
	if target in [_paris, _hero] or attacker == _paris:
		_fact("hp_damage", attacker, target, amount, {"element": _element, "category": _category})


func _on_heal(target: Unit, source: Unit, amount: int) -> void:
	if source == _paris:
		_fact("heal", source, target, amount)


func _on_shield(target: Unit, source: Unit, amount: int) -> void:
	if source == _paris:
		_fact("shield", source, target, amount)


func _on_shield_absorbed(target: Unit, amount: int) -> void:
	if target == _paris or target == _ally:
		_fact("shield_absorbed", null, target, amount)


func _on_status(target: Unit, status: StatusData) -> void:
	if target == _hero:
		_fact("status", _paris, target, 0, {"status_id": str(status.status_id)})


func _on_push(target: Unit, from: Vector2i, to: Vector2i, _collision: bool) -> void:
	if target == _hero:
		_fact("push", _paris, target, 1, {"from": from, "to": to})


func _on_turn(unit: Unit) -> void:
	if unit == _paris:
		_paris_turns += 1
	elif unit == _hero:
		_hero_turns += 1
		# EventBus.turn_started is emitted by Unit.start_turn before Battle
		# processes turn-start statuses; retain this as the pre-effect budget.
		_hero_activation_before = {"mp": _hero.current_mp, "hero_action_count": _hero_actions.size(), "activation_index": _hero.activation_index}
		_fact("hero_activation_started", null, _hero, 0, {"mp": _hero.current_mp, "max_mp": _hero.max_mp.get_int(), "activation_index": _hero.activation_index, "phase": "before_turn_start_status_processing"})


func _on_move_prepared(unit: Unit, path: Array, _base: int, cost: int, action_id: StringName) -> void:
	if unit == _paris:
		_moves.append({"action_id": str(action_id), "path": path, "cost": cost, "started_usec": Time.get_ticks_usec(), "ap_before": unit.current_ap, "mp_before": unit.current_mp})


func _on_move_resolved(unit: Unit, _path: Array, cost: int, action_id: StringName) -> void:
	if unit != _paris:
		return
	var destination: Vector2 = _battle.grid_cell_to_parent_local(unit.grid_pos, _observed_unit_view.get_parent())
	var error := _observed_unit_view.position.distance_to(destination)
	_max_destination_error = maxf(_max_destination_error, error)
	for move: Dictionary in _moves:
		if str(move.action_id) == str(action_id):
			move.finished_usec = Time.get_ticks_usec()
			move.mp_after = unit.current_mp
			move.actual_cost = cost
			move.ap_after = unit.current_ap
			move.destination_error_px = error


func _on_death(_unit: Unit) -> void:
	_deaths += 1


func _on_death_finish() -> void:
	_death_finishes += 1
	_death_finish_alpha = _observed_visual.modulate.a
	if not _reaction.is_empty():
		_reaction.finished_usec = Time.get_ticks_usec()
		_reaction.duration_seconds = float(int(_reaction.finished_usec) - int(_reaction.started_usec)) / 1000000.0
		_reaction = {}


func _wait_for_input() -> bool:
	if not await _interaction._wait_for_player(_battle, 10000):
		return false
	var hud = _battle.get("_hud_port")
	var banner: Control = hud.get_turn_intro_banner() as Control if hud != null else null
	var deadline := Time.get_ticks_msec() + 5000
	while is_instance_valid(banner) and banner.visible and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	return bool(_battle._can_accept_player_intent())


func _pass_real_turn() -> void:
	if not await _wait_for_input():
		_errors.append("player_not_ready_to_end_turn")
		return
	var before := _hero_turns
	_battle._on_end_turn_pressed()
	var confirmation: Node = _battle.get("_end_turn_confirmation")
	if is_instance_valid(confirmation) and bool(confirmation.is_open()):
		confirmation._on_confirmed()
	var deadline := Time.get_ticks_msec() + 25000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if not _hero.is_alive:
			return
		if _hero_turns > before and bool(_battle._can_accept_player_intent()):
			# No player action has been submitted since this activation began.
			# Measure the budget actually available to the player, after Battle
			# finished applying Aporia and released its interaction lock.
			_fact("hero_activation", null, _hero, 0, {"mp": _hero.current_mp, "max_mp": _hero.max_mp.get_int(),
				"mp_before_statuses": int(_hero_activation_before.get("mp", -1)),
				"activation_index": _hero.activation_index,
				"player_actions_since_start": _hero_actions.size() - int(_hero_activation_before.get("hero_action_count", -1)),
				"phase": "first_interactive_frame_after_turn_start_status_processing"})
			return
	_errors.append("real_enemy_turn_timeout")


func _wound_with_real_hero_combo(target: Unit) -> void:
	if target == null or not target.is_alive or not await _wait_for_input():
		return
	var phase_before := _is_infernal()
	var caster := _battle.get("spell_caster") as SpellCaster
	var shot := _hero_spell(SHOT)
	var strike := _hero_spell(STRIKE)
	if caster.get_cast_failure_reason(_hero, shot, target.grid_pos) == &"":
		await _hero_cast(SHOT, target.grid_pos)
	if not target.is_alive or (not phase_before and _is_infernal()):
		return
	var grid := _battle.get("grid") as GridData
	if grid.manhattan(_hero.grid_pos, target.grid_pos) > 1:
		var finder := _battle.get("pathfinder") as Pathfinder
		var best := Vector2i(-1, -1)
		var best_distance := grid.manhattan(_hero.grid_pos, target.grid_pos)
		for y in grid.rows:
			for x in grid.cols:
				var candidate := Vector2i(x, y)
				var distance := grid.manhattan(candidate, target.grid_pos)
				if distance >= best_distance or not grid.is_walkable(candidate, _hero):
					continue
				var path := finder.find_path(_hero.grid_pos, candidate, _hero)
				if path.size() < 2 or int(finder.path_cost_breakdown(path, _hero).get("total", 999)) > _hero.current_mp:
					continue
				best = candidate
				best_distance = distance
		if best != Vector2i(-1, -1):
			await _hero_walk(best)
	if not target.is_alive or (not phase_before and _is_infernal()):
		return
	if caster.get_cast_failure_reason(_hero, strike, target.grid_pos) == &"":
		await _hero_cast(STRIKE, target.grid_pos)
	elif caster.get_cast_failure_reason(_hero, shot, target.grid_pos) == &"":
		await _hero_cast(SHOT, target.grid_pos)


func _hero_spell(id: StringName) -> Spell:
	for candidate: Spell in _hero.spells:
		if candidate.get_effective_spell_id() == id:
			return candidate
	return null


func _hero_cast(id: StringName, cell: Vector2i) -> void:
	var spell: Spell
	for candidate: Spell in _hero.spells:
		if candidate.get_effective_spell_id() == id:
			spell = candidate
	var caster := _battle.get("spell_caster") as SpellCaster
	var reason := caster.get_cast_failure_reason(_hero, spell, cell)
	if reason != &"":
		_errors.append("illegal_hero_preparation_cast:%s:%s" % [id, reason])
		return
	var before := _hero.current_ap
	var cost := _hero.get_spell_ap_cost(spell)
	_battle._on_spell_pressed(spell)
	var route := _click(cell)
	var deadline := Time.get_ticks_msec() + 9000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if _hero.current_ap == before - cost and not bool(_battle.get("_spell_resolution_pending")) and (bool(_battle._can_accept_player_intent()) or not _paris.is_alive):
			break
	var okay := _hero.current_ap == before - cost
	_hero_actions.append({"kind": "spell", "spell_id": str(id), "cell": cell, "ap_before": before, "ap_after": _hero.current_ap, "cost": cost, "route": route, "ok": okay})
	if not okay:
		_errors.append("real_hero_preparation_cast_failed")


func _hero_walk(cell: Vector2i) -> void:
	var before := _hero.current_mp
	_battle._on_move_pressed()
	var route := _click(cell)
	var deadline := Time.get_ticks_msec() + 9000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if _hero.grid_pos == cell and bool(_battle._can_accept_player_intent()):
			break
	var okay := _hero.grid_pos == cell and _hero.current_mp < before
	_hero_actions.append({"kind": "move", "cell": cell, "mp_before": before, "mp_after": _hero.current_mp, "route": route, "ok": okay})
	if not okay:
		_errors.append("real_hero_preparation_walk_failed")


func _click(cell: Vector2i) -> Dictionary:
	var renderer := (_battle.get("arena_assembly") as Dictionary).get("renderer") as ArenaTerrainVisualRenderer
	var root := renderer.node_for_cell(cell)
	var floor_sprite := root.get_node_or_null("Visual") as Sprite2D if root != null else null
	if floor_sprite == null:
		_errors.append("real_target_floor_sprite_missing")
		return {}
	var polygon := GEOMETRY.sprite_polygon(floor_sprite)
	return _interaction._route_local_pointer(_battle.get("grid_view"), (polygon[0] + polygon[2]) * 0.5, true)


func _is_infernal() -> bool:
	return is_instance_valid(_observed_visual) and str(_observed_visual.get_visual_runtime_state().get("combat_form", "")) == "infernal"


func _has_infernal_cast() -> bool:
	for cast: Dictionary in _casts:
		if str(cast.get("spell_id", "")) == "paris_infernal_whip":
			return true
	return false


func _clip_duration(clip: StringName) -> float:
	var profile := _observed_visual.get("sprite_profile") as Resource
	var durations: Dictionary = profile.get("action_durations")
	return float(durations.get(str(clip).get_slice("_", 0), 0.0))


func _on_transformation_finished() -> void:
	if _active_transform.is_empty():
		_errors.append("transformation_finish_without_animation")
		return
	_active_transform.finish_count += 1
	_active_transform.finished_usec = Time.get_ticks_usec()
	_active_transform.duration_seconds = float(int(_active_transform.finished_usec) - int(_active_transform.started_usec)) / 1000000.0
	_active_transform.form_after = str(_observed_visual.get_visual_runtime_state().get("combat_form", ""))
	_active_transform.final_frames = _sprite.sprite_frames.resource_path
	_active_transform.returned_idle = str(_sprite.animation).begins_with("idle_")
	_active_transform = {}


func _on_occupancy(reason: StringName, unit, from_cell: Vector2i, to_cell: Vector2i) -> void:
	if unit not in [_paris, _hero]:
		return
	_occupancy.append({"time_usec": Time.get_ticks_usec(), "reason": str(reason),
		"unit_id": str(unit.unit_id), "from": from_cell, "to": to_cell,
		"terrain": _battle.grid.get_terrain_properties(to_cell), "mp": unit.current_mp})


func _scenario_observed() -> bool:
	if configuration.scenario in ["transform", "defeat"]:
		return _is_infernal() and _has_infernal_cast()
	var expected := {"spectral": "paris_spectral_arrow", "ice": "paris_ice_arrow", "fire": "paris_fire_arrow",
		"vortex": "paris_vortex_arrow", "teleport": "paris_vortex_step", "approach": "paris_spectral_arrow"}
	for cast: Dictionary in _casts:
		if str(cast.get("spell_id", "")) == str(expected.get(configuration.scenario, "")):
			return configuration.scenario != "approach" or not _moves.is_empty()
	return false


func _validate() -> void:
	if _max_ground_error > 0.01 or _max_destination_error > 0.01:
		_errors.append("paris_anchor_or_arrival_drift")
	if is_instance_valid(_observed_visual) and _observed_visual.position != _initial_local_position:
		_errors.append("paris_visual_root_drift")
	if not _states_seen.has("idle_%s" % configuration.direction):
		_errors.append("requested_direction_idle_missing")
	if configuration.scenario == "defeat":
		if _paris.is_alive or _deaths != 1 or _death_finishes != 1 or is_instance_valid(_observed_unit_view):
			_errors.append("real_infernal_death_or_cleanup_missing")
	elif not _scenario_observed():
		_errors.append("requested_natural_ai_behavior_not_observed")
	for cast: Dictionary in _casts:
		if int(cast.release_count) != 1 or int(cast.finish_count) != 1 or int(cast.spell_count) != 1:
			_errors.append("paris_cast_markers_not_exactly_once")
		if int(cast.get("resolved_usec", 0)) < int(cast.release_usec):
			_errors.append("paris_spell_resolved_before_release")
		if int(cast.get("ap_after", -1)) != int(cast.ap_before) - int(cast.get("ap_cost", -100)):
			_errors.append("paris_cast_ap_budget_not_once")
		if not bool(cast.get("returned_idle", false)):
			_errors.append("paris_cast_did_not_return_idle")
		if not _capture_enabled:
			var expected := float(cast.get("expected_duration", 0.0))
			if expected <= 0.0 or absf(float(cast.get("duration_seconds", 0.0)) - expected) > 0.18:
				_errors.append("paris_cast_duration_outside_budget")
			if absf(float(cast.get("release_seconds", 0.0)) - expected * 0.5) > 0.16:
				_errors.append("paris_cast_release_outside_budget")
		for fact: Dictionary in cast.facts:
			if int(fact.time_usec) < int(cast.release_usec):
				_errors.append("paris_effect_before_visual_release")
	for movement: Dictionary in _moves:
		if not movement.has("finished_usec") or int(movement.get("mp_after", -1)) != int(movement.mp_before) - int(movement.cost):
			_errors.append("real_movement_budget_or_completion_failed")
	if configuration.scenario in ["ice", "fire"]:
		var wanted := "frozen" if configuration.scenario == "ice" else "burn"
		var has_status := false
		var has_terrain := false
		for fact: Dictionary in _facts:
			has_status = has_status or (fact.kind == "status" and str(fact.get("status_id", "")) == wanted)
		for cast: Dictionary in _casts:
			if str(cast.get("spell_id", "")) == "paris_%s_arrow" % configuration.scenario:
				has_terrain = has_terrain or not (cast.get("terrain_after", []) as Array).is_empty()
		if not has_status:
			_errors.append("elemental_arrow_missing_actual_status:" + wanted)
		if not has_terrain:
			_errors.append("elemental_arrow_missing_actual_surface")
	if configuration.scenario == "vortex":
		var pulled := false
		for event: Dictionary in _occupancy:
			pulled = pulled or (str(event.unit_id) == str(_hero.unit_id) and Vector2i(event.to) == Vector2i(placement.expected_pull_destination))
		if not pulled or not _has_fact("hp_damage", _hero, true):
			_errors.append("vortex_arrow_did_not_pull_hero_into_real_hazard")
	if configuration.scenario == "teleport":
		var teleported := false
		for event: Dictionary in _occupancy:
			teleported = teleported or (str(event.unit_id) == str(_paris.unit_id) and _battle.grid.manhattan(Vector2i(event.from), Vector2i(event.to)) > 1)
		if not teleported:
			_errors.append("vortex_step_did_not_move_real_paris")
		if is_instance_valid(_observed_unit_view):
			var actual_destination: Vector2 = _battle.grid_cell_to_parent_local(_paris.grid_pos, _observed_unit_view.get_parent())
			if _observed_unit_view.position.distance_to(actual_destination) > 0.01:
				_errors.append("vortex_step_view_did_not_reach_actual_cell")
	if configuration.scenario == "approach" and not _has_action("walk"):
		_errors.append("real_paris_walk_animation_missing")
	if configuration.scenario in ["transform", "defeat"]:
		if _transformations.size() != 1:
			_errors.append("threshold_transformation_not_exactly_once")
		for transition: Dictionary in _transformations:
			if int(transition.hp) <= 0 or int(transition.hp) * 5 >= int(transition.max_hp):
				_errors.append("transformation_did_not_start_below_strict_twenty_percent")
			if int(transition.get("finish_count", 0)) != 1 or str(transition.get("form_after", "")) != "infernal":
				_errors.append("transformation_did_not_finish_in_infernal_form")
			if not bool(transition.get("returned_idle", false)):
				_errors.append("transformation_did_not_return_to_idle")
			if not _capture_enabled and absf(float(transition.get("duration_seconds", 0.0)) - 0.90) > 0.18:
				_errors.append("transformation_duration_outside_budget")
		if not _has_infernal_cast() or not _has_action("hit"):
			_errors.append("infernal_ai_kit_or_real_hit_animation_missing")
		if not _form_atlases.has("spectral") or not _form_atlases.has("infernal") or str(_form_atlases.get("spectral", "")) == str(_form_atlases.get("infernal", "")):
			_errors.append("both_distinct_canonical_form_atlases_not_observed")
	if _effects.is_empty():
		_errors.append("paris_sprite_spell_effects_not_observed")
	for effect: Dictionary in _effects:
		if not bool(effect.canonical_atlas_observed) or int(effect.maximum_sprite_count) <= 0:
			_errors.append("paris_effect_not_using_canonical_sprite_atlas")


func _has_fact(kind: String, target: Unit, positive: bool) -> bool:
	for fact: Dictionary in _facts:
		if str(fact.kind) == kind and int(fact.target_instance) == target.get_instance_id() and (not positive or int(fact.amount) > 0):
			return true
	return false


func _has_action(action: String) -> bool:
	for clip: String in _states_seen:
		if clip.begins_with(action + "_"):
			return true
	return false


func _snapshot(unit: Unit) -> Dictionary:
	return {"id": str(unit.unit_id), "instance_id": unit.get_instance_id(), "cell": unit.grid_pos,
		"hp": unit.current_hp, "max_hp": unit.max_hp.get_int(), "ap": unit.current_ap, "mp": unit.current_mp,
		"shield": unit.current_shield, "alive": unit.is_alive}


func _inherits(node: Node, path: String) -> bool:
	var script := node.get_script() as Script
	while script != null:
		if script.resource_path == path:
			return true
		script = script.get_base_script()
	return false


func _begin_clip() -> void:
	var viewport_size := Vector2i(get_viewport().get_visible_rect().size)
	var bounds := Rect2(_observed_unit_view.get_global_transform_with_canvas().origin, Vector2.ONE)
	for view: Node2D in (_battle.get("_unit_views") as Dictionary).values():
		bounds = bounds.expand(view.get_global_transform_with_canvas().origin)
	bounds.position -= Vector2(135, 200)
	bounds.size += Vector2(270, 270)
	_clip_rect = Rect2i(bounds).intersection(Rect2i(Vector2i.ZERO, viewport_size))
	_clip_start = Time.get_ticks_usec()
	_clip_active = true


func _capture_clip_frame() -> void:
	_clip_pending = true
	await RenderingServer.frame_post_draw
	var now := Time.get_ticks_usec()
	_clip_last = now
	var picture := get_viewport().get_texture().get_image()
	if picture != null and not picture.is_empty():
		if configuration.scenario in ["defeat", "transform"] and _clip_images.size() >= 360:
			_clip_images.pop_front()
			_clip_frames.pop_front()
			_clip_omitted_frames += 1
		_clip_images.append(picture.get_region(_clip_rect))
		_clip_frames.append({"index": _clip_frames.size(), "capture_usec": now,
			"animation": str(_sprite.animation) if is_instance_valid(_sprite) else "removed",
			"frame": _sprite.frame if is_instance_valid(_sprite) else -1,
			"paris_hp": _paris.current_hp, "hero_hp": _hero.current_hp, "combat_form": str(_observed_visual.get_visual_runtime_state().get("combat_form", "")) if is_instance_valid(_observed_visual) else "removed"})
	_clip_pending = false


func _flush_clip() -> void:
	if not _clip_enabled:
		return
	var directory := _output.path_join("clip")
	DirAccess.make_dir_recursive_absolute(directory)
	for index in _clip_images.size():
		_clip_frames[index]["index"] = index
		var path := directory.path_join("frame_%04d.png" % index)
		if _clip_images[index].save_png(path) == OK:
			_clip_frames[index]["path"] = path
		else:
			_errors.append("clip_png_write_failed")
	_clip_report = {"enabled": true, "schema": "dd.paris.real-ai-gameplay-clip.v1",
		"source": "Real viewport readback after frame_post_draw. Fixed crop only, no sprite reconstruction.",
		"target_fps": 20, "maximum_frames": 600, "frame_count": _clip_frames.size(), "omitted_earlier_frames": _clip_omitted_frames,
		"frame_limit_reached": _clip_frames.size() >= 600,
		"rectangle_px": [_clip_rect.position.x, _clip_rect.position.y, _clip_rect.size.x, _clip_rect.size.y],
		"started_usec": _clip_frames[0].capture_usec if not _clip_frames.is_empty() else _clip_start, "ended_usec": _clip_end, "frames": _clip_frames,
		"timing_note": "Presentation capture, GPU readback may perturb timing. PNG compression is deferred. Use original timestamps to encode."}
	var file := FileAccess.open(directory.path_join("clip_manifest.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_clip_report, "  "))
		file.close()
	_clip_images.clear()


func _finish(details: Dictionary) -> void:
	if _finished:
		return
	_finished = true
	_running = false
	_clip_active = false
	var report := {"schema": "dd.paris.production-combat-validation.v1", "ok": _errors.is_empty(), "errors": _errors,
		"configuration": configuration, "placement_fixture": placement, "progression_fixture": progression,
		"godot_version": Engine.get_version_info().get("string", ""), "renderer": RenderingServer.get_current_rendering_method(),
		"scope": "RegisteredTerrainBattle on the isolated Silent Judgment Courtyard test field; the actual production boss remains in Catabase room V. Memory-only spawn/facing and optional pre-combat XP fixtures are disclosed. Achilles uses native deployment, GridView spell/move clicks and End Turn confirmation. EnemyAI chooses all paris actions. HP, AP, MP, occupancy and animation clocks are never edited during combat."}
	report.merge(details)
	# A derived probe may describe its actual production room explicitly.
	if details.has("scope"):
		report["scope"] = details["scope"]
	var file := FileAccess.open(_output.path_join("runtime_validation.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	else:
		report.ok = false
		push_error("Cannot write Paris validation report")
	print("PARIS_COMBAT_VALIDATION ", JSON.stringify(report))
	get_tree().quit(0 if bool(report.ok) else 1)


func _verify_stable_rest(visual: Node2D, unit_view: Node2D, phase: String) -> Dictionary:
	var readiness: Dictionary = await CANVAS_STABILITY.wait_for_settled_canvas(self, _battle, visual, unit_view, _sprite)
	if not bool(readiness.get("ok", false)):
		_errors.append("canvas_or_model_not_stable_before_rest_%s" % phase)
		return {"phase": phase, "sample_count": 0, "observed_seconds": 0.0,
			"unexpected_pose_samples": int(readiness.get("unexpected_model_samples", 0)),
			"maximum_screen_foot_drift_px": 0.0, "maximum_screen_anchor_error_px": 0.0,
			"canvas_stabilization": readiness}
	# Keep the existing strict 650 ms rest measurement, including its 0.01 px
	# screen drift tolerance. Settling never replaces or weakens that check.
	var result: Dictionary = await super._verify_stable_rest(visual, unit_view, phase)
	result.canvas_stabilization = readiness
	return result