extends "res://tools/achilles_sprite_validation/courtyard_sprite_probe.gd"

const REGISTERED_SCRIPT := "res://battle/painted/registered_terrain/registered_terrain_battle.gd"
const FRAMES := "res://assets/characters/philosopher_mage/sprites_v1/philosopher_sprite_frames.tres"
const CAST_ACTIONS := ["attack", "heal", "control", "shield"]
const DURATIONS := {"attack": 0.64, "heal": 0.80, "control": 0.72, "shield": 0.64}
const SHOT := &"achilles_pelion_shot"
const STRIKE := &"achilles_peleid_strike"

var configuration: Dictionary = {}
var placement: Dictionary = {}
var progression: Dictionary = {}
var _battle: Node
var _interaction: Node
var _hero: Unit
var _mage: Unit
var _ally: Unit
var _running := false
var _finished := false
var _mage_turns := 0
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


func _ready() -> void:
	_output = ProjectSettings.globalize_path("res://artifacts/philosopher_sprite_validation_v1")
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
		elif unit.unit_id == &"philosopher_mage":
			_mage = unit
		else:
			_ally = unit
	if _hero == null or _mage == null:
		_errors.append("canonical_hero_or_mage_missing")
		_finish({})
		return
	if _mage.grid_pos != Vector2i(placement.mage_cell) or (_ally != null and _ally.grid_pos != Vector2i(placement.ally_cell)):
		_errors.append("real_initial_roles_do_not_match_authored_spawn_fixture")
		_finish({"actual_initial_mage": _snapshot(_mage), "actual_initial_ally": _snapshot(_ally) if _ally != null else {}})
		return
	_observed_unit_view = (_battle.get("_unit_views") as Dictionary).get(_mage) as Node2D
	_observed_visual = _observed_unit_view.get_optional_visual() if _observed_unit_view != null else null
	if _observed_visual == null:
		_errors.append("canonical_mage_visual_missing")
		_finish({})
		return
	var sprites := _observed_visual.find_children("*", "AnimatedSprite2D", true, false)
	if sprites.size() != 1 or not _observed_visual.find_children("*", "Node3D", true, false).is_empty() or not _observed_visual.find_children("*", "SubViewport", true, false).is_empty():
		_errors.append("mage_not_exclusively_sprite_2d")
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
	_mage.died.connect(_on_death)
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
	var initial := _snapshot(_mage)
	var initial_ally := _snapshot(_ally) if _ally != null else {}
	var initial_rest := await _verify_stable_rest(_observed_visual, _observed_unit_view, "mage_initial")
	if _clip_enabled:
		_begin_clip()
	var scenario := str(configuration.scenario)
	if scenario in ["heal_self", "heal_ally"]:
		var patient := _ally if scenario == "heal_ally" else _mage
		await _wound_with_real_hero_combo(patient)
		if patient.current_hp >= ceili(patient.max_hp.get_int() * 0.70):
			_errors.append("real_wound_did_not_reach_healing_threshold")
	if scenario == "defeat":
		for round_index in 10:
			if not _mage.is_alive or not _hero.is_alive or not _errors.is_empty():
				break
			await _wound_with_real_hero_combo(_mage)
			if _mage.is_alive:
				await _pass_real_turn()
	else:
		for round_index in 4:
			if not _hero.is_alive or not _errors.is_empty():
				break
			await _pass_real_turn()
			if _scenario_observed():
				break
	if scenario == "shield" and _ally != null and _ally.is_alive and _errors.is_empty():
		var attack := STRIKE if _battle.grid.manhattan(_hero.grid_pos, _ally.grid_pos) == 1 else SHOT
		await _hero_cast(attack, _ally.grid_pos)
	await get_tree().create_timer(0.8).timeout
	var final_rest := {"not_applicable": "Mage died from real Achilles spell damage"}
	if _mage.is_alive and is_instance_valid(_observed_visual):
		final_rest = await _verify_stable_rest(_observed_visual, _observed_unit_view, "mage_after_actions")
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
		"actual_sprite_frames": _observed_frames_path, "initial_mage": initial, "initial_ally": initial_ally, "final_mage": _snapshot(_mage),
		"final_hero": _snapshot(_hero), "enemy_turns": _mage_turns, "hero_turns": _hero_turns,
		"stable_rest_before": initial_rest, "stable_rest_after": final_rest,
		"runtime_state": _runtime, "real_hero_actions": _hero_actions,
		"real_ai_casts": _casts, "real_ai_movements": _moves, "combat_facts": _facts,
		"observed_poses": _poses, "states_seen": _states_seen.keys(), "reactions": _reactions, "effects": _effects,
		"maximum_local_ground_anchor_error_px": _max_ground_error,
		"maximum_completed_movement_error_px": _max_destination_error,
		"death_events": _deaths, "death_visual_finishes": _death_finishes,
		"death_finish_alpha": _death_finish_alpha,
		"mage_view_removed": not is_instance_valid(_observed_unit_view),
		"screenshots": _captures, "capture_clip": _clip_report,
		"capture_work_intervals": _capture_work_intervals,
		"clean_timing_run": not _capture_enabled})


func _process(_delta: float) -> void:
	if not _running:
		return
	_observe_effects()
	if is_instance_valid(_sprite):
		var clip := str(_sprite.animation)
		var action := clip.get_slice("_", 0)
		_states_seen[clip] = true
		var key := "%s:%d" % [clip, _sprite.frame]
		if key != _last_pose:
			_last_pose = key
			_poses.append({"time_usec": Time.get_ticks_usec(), "animation": clip, "frame": _sprite.frame,
				"mage_cell": _mage.grid_pos, "mage_hp": _mage.current_hp,
				"view_position": _observed_unit_view.position})
		var profile := _observed_visual.get("sprite_profile") as Resource
		var ground := _sprite.offset + Vector2(profile.get("foot_anchor"))
		if _sprite.centered:
			ground -= Vector2(profile.get("frame_canvas_size")) * 0.5
		_max_ground_error = maxf(_max_ground_error, (_sprite.transform * ground).length())
		_runtime = _observed_visual.get_visual_runtime_state()
		if _capture_enabled and not _captures.has(action) and not _pending_captures.has(action) and (action == "idle" or _sprite.frame >= 1):
			_capture_current_state(action)
	if _clip_active and not _clip_pending and (_clip_images.size() < 500 or configuration.scenario == "defeat") and Time.get_ticks_usec() - _clip_last >= 50000:
		_capture_clip_frame()


func _observe_effects() -> void:
	for effect: Node in get_tree().get_nodes_in_group("philosopher_spell_sprite_vfx"):
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
			if texture != null and texture.resource_path == "res://assets/vfx/philosopher_mage/sprites_v1/effects.png":
				record.canonical_atlas_observed = true



func _on_animation() -> void:
	var clip := str(_sprite.animation)
	var action := clip.get_slice("_", 0)
	var now := Time.get_ticks_usec()
	if not _reaction.is_empty() and action != str(_reaction.action):
		_reaction.finished_usec = now
		_reaction.duration_seconds = float(now - int(_reaction.started_usec)) / 1000000.0
		_reaction = {}
	if action in ["hit", "death"] and action != _last_action:
		_reaction = {"action": action, "animation": clip, "started_usec": now, "finished_usec": 0}
		_reactions.append(_reaction)
	if action in CAST_ACTIONS:
		_active_cast = {"animation": clip, "action": action, "activation": _mage_turns,
			"started_usec": now, "release_usec": 0, "finished_usec": 0,
			"release_count": 0, "finish_count": 0, "spell_count": 0,
			"ap_before": _mage.current_ap, "facts": []}
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
	_active_cast.ap_after = _mage.current_ap
	_active_cast.returned_idle = str(_sprite.animation).begins_with("idle_")
	_active_cast = {}


func _on_spell_cast(actor: Unit, spell: Spell, report: Dictionary) -> void:
	if actor != _mage:
		return
	if _active_cast.is_empty():
		_errors.append("mage_cast_without_body_animation")
		return
	_active_cast.spell_count += 1
	_active_cast.spell_id = str(spell.get_effective_spell_id())
	_active_cast.ap_cost = _mage.get_spell_ap_cost(spell)
	_active_cast.resolved_usec = Time.get_ticks_usec()
	_active_cast.report = report


func _fact(kind: String, actor: Unit, target: Unit, amount: int, extra: Dictionary = {}) -> void:
	var fact := {"kind": kind, "time_usec": Time.get_ticks_usec(), "actor_id": str(actor.unit_id) if actor != null else "",
		"target_id": str(target.unit_id), "target_instance": target.get_instance_id(), "amount": amount,
		"target_hp": target.current_hp, "target_shield": target.current_shield, "target_cell": target.grid_pos}
	fact.merge(extra)
	_facts.append(fact)
	if actor == _mage and not _active_cast.is_empty():
		(_active_cast.facts as Array).append(fact)


func _on_damage(target: Unit, attacker: Unit, amount: int, _category: int, _element: int, _critical: bool) -> void:
	if target == _mage or attacker == _mage or target == _ally:
		_fact("hp_damage", attacker, target, amount)


func _on_heal(target: Unit, source: Unit, amount: int) -> void:
	if source == _mage:
		_fact("heal", source, target, amount)


func _on_shield(target: Unit, source: Unit, amount: int) -> void:
	if source == _mage:
		_fact("shield", source, target, amount)


func _on_shield_absorbed(target: Unit, amount: int) -> void:
	if target == _mage or target == _ally:
		_fact("shield_absorbed", null, target, amount)


func _on_status(target: Unit, status: StatusData) -> void:
	if target == _hero:
		_fact("status", _mage, target, 0, {"status_id": str(status.status_id)})


func _on_push(target: Unit, from: Vector2i, to: Vector2i, _collision: bool) -> void:
	if target == _hero:
		_fact("push", _mage, target, 1, {"from": from, "to": to})


func _on_turn(unit: Unit) -> void:
	if unit == _mage:
		_mage_turns += 1
	elif unit == _hero:
		_hero_turns += 1
		# EventBus.turn_started is emitted by Unit.start_turn before Battle
		# processes turn-start statuses; retain this as the pre-effect budget.
		_hero_activation_before = {"mp": _hero.current_mp, "hero_action_count": _hero_actions.size(), "activation_index": _hero.activation_index}
		_fact("hero_activation_started", null, _hero, 0, {"mp": _hero.current_mp, "max_mp": _hero.max_mp.get_int(), "activation_index": _hero.activation_index, "phase": "before_turn_start_status_processing"})


func _on_move_prepared(unit: Unit, path: Array, _base: int, cost: int, action_id: StringName) -> void:
	if unit == _mage:
		_moves.append({"action_id": str(action_id), "path": path, "cost": cost, "started_usec": Time.get_ticks_usec(), "ap_before": unit.current_ap, "mp_before": unit.current_mp})


func _on_move_resolved(unit: Unit, _path: Array, cost: int, action_id: StringName) -> void:
	if unit != _mage:
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
	var grid := _battle.get("grid") as GridData
	if grid.manhattan(_hero.grid_pos, target.grid_pos) >= 2:
		await _hero_cast(SHOT, target.grid_pos)
	if not target.is_alive:
		return
	if grid.manhattan(_hero.grid_pos, target.grid_pos) > 1:
		var finder := _battle.get("pathfinder") as Pathfinder
		var best: Array = []
		for direction: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var candidate := target.grid_pos + direction
			var path := finder.find_path(_hero.grid_pos, candidate, _hero)
			if path.size() < 2 or int(finder.path_cost_breakdown(path, _hero).get("total", 999)) > _hero.current_mp:
				continue
			if best.is_empty() or path.size() < best.size():
				best = path
		if not best.is_empty():
			await _hero_walk(best.back())
	if target.is_alive and grid.manhattan(_hero.grid_pos, target.grid_pos) == 1:
		await _hero_cast(STRIKE, target.grid_pos)


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
		if _hero.current_ap == before - cost and not bool(_battle.get("_spell_resolution_pending")) and (bool(_battle._can_accept_player_intent()) or not _mage.is_alive):
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


func _scenario_observed() -> bool:
	var expected := {"attack": "philosopher_axiom", "control": "philosopher_aporia", "shield": "philosopher_aegis",
		"heal_self": "philosopher_mending", "heal_ally": "philosopher_mending", "repel": "philosopher_refutation", "approach": "philosopher_axiom"}
	for cast: Dictionary in _casts:
		if str(cast.get("spell_id", "")) == str(expected.get(configuration.scenario, "")):
			return configuration.scenario != "approach" or not _moves.is_empty()
	return false


func _validate() -> void:
	if _max_ground_error > 0.01 or _max_destination_error > 0.01:
		_errors.append("mage_ground_anchor_or_movement_destination_drift")
	if is_instance_valid(_observed_visual) and _observed_visual.position != _initial_local_position:
		_errors.append("mage_local_visual_root_drift")
	if not _states_seen.has("idle_%s" % configuration.direction):
		_errors.append("requested_direction_idle_missing")
	if configuration.scenario == "defeat":
		if _mage.is_alive or _deaths != 1 or _death_finishes != 1 or is_instance_valid(_observed_unit_view):
			_errors.append("real_mage_death_or_cleanup_missing")
	else:
		if not _scenario_observed():
			_errors.append("requested_natural_ai_behavior_not_observed")
	for cast: Dictionary in _casts:
		if int(cast.release_count) != 1 or int(cast.finish_count) != 1 or int(cast.spell_count) != 1:
			_errors.append("mage_cast_release_resolution_finish_not_once")
		if int(cast.get("resolved_usec", 0)) < int(cast.release_usec):
			_errors.append("mage_spell_resolved_before_visual_release")
		if int(cast.get("ap_after", -1)) != int(cast.ap_before) - int(cast.get("ap_cost", -100)):
			_errors.append("mage_cast_ap_budget_not_once")
		if not bool(cast.get("returned_idle", false)):
			_errors.append("mage_cast_did_not_return_idle")
		for fact: Dictionary in cast.facts:
			if int(fact.time_usec) < int(cast.release_usec):
				_errors.append("mage_effect_before_visual_release")
		if not _capture_enabled:
			var duration := float(DURATIONS[str(cast.action)])
			if absf(float(cast.get("duration_seconds", 0.0)) - duration) > 0.16 or absf(float(cast.get("release_seconds", 0.0)) - duration * 0.5) > 0.14:
				_errors.append("mage_cast_timing_outside_graphical_budget")
	if configuration.scenario in ["heal_self", "heal_ally"]:
		var patient := _ally if configuration.scenario == "heal_ally" else _mage
		if not _has_fact("heal", patient, true):
			_errors.append("mage_did_not_restore_real_hp_to_expected_patient")
		if configuration.scenario == "heal_self" and not _has_action("hit"):
			_errors.append("real_mage_hit_animation_missing")
	if configuration.scenario == "shield":
		if not _has_fact("shield", _ally, true):
			_errors.append("mage_did_not_shield_threatened_ally")
		if not _has_fact("shield_absorbed", _ally, true):
			_errors.append("mage_shield_did_not_absorb_real_damage")
	if configuration.scenario == "control":
		var controlled := false
		for fact: Dictionary in _facts:
			controlled = controlled or (fact.kind == "hero_activation" and int(fact.mp) == int(fact.mp_before_statuses) - 2 and int(fact.player_actions_since_start) == 0 and str(fact.phase) == "first_interactive_frame_after_turn_start_status_processing")
		if not controlled:
			_errors.append("control_did_not_reduce_actual_hero_activation_mp")
	if configuration.scenario == "repel" and not _has_fact("push", _hero, true):
		_errors.append("repel_did_not_move_real_hero")
	if configuration.scenario == "approach" and not _has_action("walk"):
		_errors.append("real_ai_walk_animation_missing")
	var expected_effect := {"attack": "bolt", "control": "control", "shield": "shield", "heal_self": "heal", "heal_ally": "heal", "approach": "bolt", "repel": "repel"}
	if expected_effect.has(configuration.scenario):
		var found := false
		for effect: Dictionary in _effects:
			found = found or (str(effect.animation) == str(expected_effect[configuration.scenario]) and bool(effect.canonical_atlas_observed) and int(effect.maximum_sprite_count) > 0 and not (effect.phases as Array).is_empty())
		if not found:
			_errors.append("requested_effect_not_observed_as_real_atlas_sprites")

	for movement: Dictionary in _moves:
		if not movement.has("finished_usec") or int(movement.get("mp_after", -1)) != int(movement.mp_before) - int(movement.cost):
			_errors.append("mage_ai_movement_budget_or_completion_failed")


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
		if configuration.scenario == "defeat" and _clip_images.size() >= 240:
			_clip_images.pop_front()
			_clip_frames.pop_front()
			_clip_omitted_frames += 1
		_clip_images.append(picture.get_region(_clip_rect))
		_clip_frames.append({"index": _clip_frames.size(), "capture_usec": now,
			"animation": str(_sprite.animation) if is_instance_valid(_sprite) else "removed",
			"frame": _sprite.frame if is_instance_valid(_sprite) else -1,
			"mage_hp": _mage.current_hp, "hero_hp": _hero.current_hp})
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
	_clip_report = {"enabled": true, "schema": "dd.philosopher.real-ai-gameplay-clip.v1",
		"source": "Real viewport readback after frame_post_draw. Fixed crop only, no sprite reconstruction.",
		"target_fps": 20, "maximum_frames": 500, "frame_count": _clip_frames.size(), "omitted_earlier_frames": _clip_omitted_frames,
		"frame_limit_reached": _clip_frames.size() >= 500,
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
	var report := {"schema": "dd.philosopher.production-combat-validation.v1", "ok": _errors.is_empty(), "errors": _errors,
		"configuration": configuration, "placement_fixture": placement, "progression_fixture": progression,
		"godot_version": Engine.get_version_info().get("string", ""), "renderer": RenderingServer.get_current_rendering_method(),
		"scope": "RegisteredTerrainBattle on the real Cour des Sources. Memory-only spawn/facing and optional pre-combat XP fixtures are disclosed. Achilles uses native deployment, GridView spell/move clicks and End Turn confirmation. EnemyAI chooses all mage actions. HP, AP, MP, occupancy and animation clocks are never edited during combat."}
	report.merge(details)
	var file := FileAccess.open(_output.path_join("runtime_validation.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	else:
		report.ok = false
		push_error("Cannot write philosopher mage validation report")
	print("PHILOSOPHER_COMBAT_VALIDATION ", JSON.stringify(report))
	get_tree().quit(0 if bool(report.ok) else 1)
