extends Node

const BATTLE_SCRIPT := "res://tools/labs/greek_drawn_arena/greek_drawn_battle.gd"
const INTERACTIONS := preload("res://tools/labs/greek_drawn_arena/greek_interaction_checks.gd")
const GEOMETRY := preload("res://tools/labs/greek_drawn_arena/greek_geometry_checks.gd")
const DEFAULT_OUTPUT := "res://artifacts/achilles_sprite_validation_v1"

var _output := ""
var _capture_enabled := false
var _observe := false
var _sprite: AnimatedSprite2D
var _captures: Dictionary = {}
var _pending_captures: Dictionary = {}
var _states_seen: Dictionary = {}
var _errors: Array[String] = []
var _action_events := {"releases": 0, "finishes": 0}
var _capture_jobs := 0
var _motion_samples: Array[Dictionary] = []
var _last_motion_key := ""
var _previous_motion_sample: Dictionary = {}
var _frame_intervals: Array[Dictionary] = []
var _frame_discontinuities: Array[Dictionary] = []
var _motion_spans: Array[Dictionary] = []
var _open_motion_span: Dictionary = {}
var _observed_visual: Node2D
var _observed_unit_view: Node2D
var _deferred_pngs: Dictionary = {}
var _capture_work_intervals: Array[Dictionary] = []
var _active_action_timing: Dictionary = {}
var _startup_observations: Array[Dictionary] = []
var _deployment_clicks: Array[Dictionary] = []
var _synchronous_animation_events: Array[Dictionary] = []
var _synchronous_walk_spans: Array[Dictionary] = []
var _open_synchronous_walk_span: Dictionary = {}
var _last_signalled_clip := ""


func _ready() -> void:
	_output = ProjectSettings.globalize_path(DEFAULT_OUTPUT)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--artifact-dir="):
			_output = ProjectSettings.globalize_path(argument.trim_prefix("--artifact-dir="))
	_capture_enabled = DisplayServer.get_name() != "headless" \
		and not OS.get_cmdline_user_args().has("--no-screenshots")
	DirAccess.make_dir_recursive_absolute(_output)
	_run.call_deferred()


func _process(_delta: float) -> void:
	if not _observe or not is_instance_valid(_sprite):
		return
	var animation := String(_sprite.animation)
	var action := animation.get_slice("_", 0)
	_states_seen[animation] = true
	var now := Time.get_ticks_usec()
	if action in ["walk", "attack"]:
		_update_motion_span(now, animation)
		var motion_key := "%s:%d" % [animation, _sprite.frame]
		if motion_key != _last_motion_key and _motion_samples.size() < 120:
			var sample := {"time_usec": now, "clip": animation,
				"frame": _sprite.frame, "frame_progress": _sprite.frame_progress,
				"speed_scale": _sprite.speed_scale,
				"source_fps": _sprite.sprite_frames.get_animation_speed(_sprite.animation),
				"source_duration": _sprite.sprite_frames.get_frame_duration(_sprite.animation, _sprite.frame)}
			_record_frame_interval(sample)
			_motion_samples.append(sample)
			_previous_motion_sample = sample
			_last_motion_key = motion_key
	else:
		_close_motion_span(now)
		_previous_motion_sample = {}
		_last_motion_key = ""
	if not _capture_enabled or _captures.has(action) or _pending_captures.has(action):
		return
	if action == "idle" or (action == "walk" and _sprite.frame >= 1) \
			or (action == "attack" and _sprite.frame >= 3):
		_capture_current_state(action)

func _run() -> void:
	var battle: Node = null
	var deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		var candidate := get_tree().current_scene
		if candidate != null and candidate.get_script() != null \
				and candidate.get_script().resource_path == BATTLE_SCRIPT \
				and bool(candidate.get("runtime_ready_state")):
			battle = candidate
			break
	if battle == null:
		_errors.append("real_battle_timeout")
		await _finish_startup_failure(battle, "runtime_ready")
		return
	if not await _wait_for_real_deployment(battle, 15000):
		_errors.append("real_hero_deployment_timeout")
		await _finish_startup_failure(battle, "deployment")
		return
	var interaction := INTERACTIONS.new()
	add_child(interaction)
	if not await interaction._wait_for_player(battle, 10000):
		_errors.append("real_player_intent_timeout")
		await _finish_startup_failure(battle, "player_intent")
		return
	var hud = battle.get("_hud_port")
	var banner: Control = hud.get_turn_intro_banner() as Control if hud != null else null
	deadline = Time.get_ticks_msec() + 5000
	while is_instance_valid(banner) and banner.visible and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	var hero: Unit = null
	for unit: Unit in battle.get("units"):
		if unit.team == 0:
			hero = unit
	if hero == null:
		_errors.append("canonical_achilles_not_deployed")
		_finish({})
		return
	var unit_views: Dictionary = battle.get("_unit_views")
	var unit_view: Node2D = unit_views.get(hero) as Node2D
	var visual: Node2D = unit_view.get_optional_visual() if unit_view != null else null
	if visual == null or not visual.has_method("get_visual_runtime_state"):
		_errors.append("canonical_visual_facade_missing")
		_finish({})
		return
	var state: Dictionary = visual.get_visual_runtime_state()
	var sprites := visual.find_children("*", "AnimatedSprite2D", true, false)
	if str(state.get("ACHILLES_VISUAL_BACKEND_ACTIVE", "")) != "SPRITE_2D" \
			or sprites.size() != 1 \
			or not visual.find_children("*", "SubViewport", true, false).is_empty() \
			or not visual.find_children("*", "Node3D", true, false).is_empty():
		_errors.append("canonical_achilles_is_not_exclusively_sprite_2d")
		_finish({"runtime_state": state})
		return
	_sprite = sprites[0] as AnimatedSprite2D
	if not _sprite.is_visible_in_tree():
		_errors.append("canonical_sprite_is_not_visible")
	_observed_visual = visual
	_observed_unit_view = unit_view
	visual.cast_release_reached.connect(_on_visual_release)
	_last_signalled_clip = str(_sprite.animation)
	_sprite.animation_changed.connect(_on_sprite_animation_changed)
	_sprite.frame_changed.connect(_on_sprite_frame_changed)
	_record_synchronous_sprite_event("subscription_initial_state")
	visual.animation_finished.connect(_on_visual_finished)
	_observe = true
	var initial_rest_report := await _verify_stable_rest(visual, unit_view, "initial")
	var assembly: Dictionary = battle.get("arena_assembly")
	var grid := battle.get("grid") as GridData
	var pathfinder := battle.get("pathfinder") as Pathfinder
	var grid_view := battle.get("grid_view") as Node2D
	var renderer := assembly.get("renderer") as ArenaTerrainVisualRenderer
	var interaction_report: Dictionary = await interaction.run(battle, hero, grid, pathfinder, grid_view, renderer)
	_errors.append_array(interaction_report.get("errors", []))
	var attack_report := await _run_real_attack(battle, hero, grid_view, renderer, interaction)
	await get_tree().create_timer(0.1).timeout
	var returned_rest_report := await _verify_stable_rest(visual, unit_view, "after_actions")
	if _capture_enabled:
		await _capture_current_state("idle", "rest_after_actions")
	_observe = false
	deadline = Time.get_ticks_msec() + 2000
	while _capture_jobs > 0 and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_flush_deferred_captures()
	for action: String in ["idle", "walk", "attack"]:
		var observed := false
		for animation: String in _states_seen:
			if animation.begins_with(action + "_"):
				observed = true
		if not observed:
			_errors.append("actual_controller_did_not_play_%s" % action)
		if _capture_enabled and not _captures.has(action):
			_errors.append("actual_map_screenshot_missing_%s" % action)
	if int(_action_events.releases) != 2 or int(_action_events.finishes) != 2:
		_errors.append("guard_and_attack_events_not_exactly_once")
	var anchor_screen := unit_view.get_global_transform_with_canvas().origin
	var visible_bounds := _screen_bounds(_sprite)
	_finish({
		"actual_scene": battle.scene_file_path,
		"startup_observations": _startup_observations,
		"deployment_clicks": _deployment_clicks,
		"runtime_state": state,
		"post_action_runtime_state": visual.get_visual_runtime_state(),
		"hero_data": hero.character_data.resource_path if hero.character_data != null else "",
		"actual_sprite_frames": _sprite.sprite_frames.resource_path,
		"states_observed_during_real_input": _states_seen.keys(),
		"guard_and_attack_visual_events": _action_events,
		"real_move_and_guard": interaction_report,
		"real_attack_cast": attack_report,
		"stable_rest_before_actions": initial_rest_report,
		"stable_rest_after_actions": returned_rest_report,
		"motion_frame_samples": _motion_samples,
		"animation_timing": _timing_report(),
		"visual_screen_bounds": visible_bounds,
		"unit_anchor_screen": [anchor_screen.x, anchor_screen.y],
		"screenshots": _captures,
		"screenshot_capture_enabled": _capture_enabled,
		"scope": "Real GreekDrawnCourtyard deployment and existing GridView click routing; no OS pointer simulation. Idle and walk observed during normal movement; timed Guard followed by a legal Spear Thrust or Sweep cast exercises the attack sprite. Capture never pauses or replaces animation.",
	})


func _wait_for_real_deployment(battle: Node, timeout_ms: int) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	var last_state := ""
	var last_attempted_hero_id := 0
	while Time.get_ticks_msec() < deadline and is_instance_valid(battle):
		var deployment := battle.get("_deployment") as DeploymentController
		var grid := battle.get("grid") as GridData
		var units: Array = battle.get("units")
		var pending: Array = deployment.get("_heroes_to_place") if deployment != null else []
		var active := deployment != null and deployment.is_active()
		var state_key := "%s:%d:%d:%s" % [str(active), pending.size(), units.size(), str(battle.get("turn_state"))]
		if state_key != last_state and _startup_observations.size() < 12:
			_startup_observations.append(_startup_snapshot(battle))
			last_state = state_key
		if grid != null and not active:
			for unit: Unit in units:
				if unit.team == 0 and unit.is_alive and grid.is_valid(unit.grid_pos) \
						and grid.get_unit(unit.grid_pos) == unit:
					return true
		if active and grid != null and not pending.is_empty() \
				and not bool(battle._is_evolution_locked()):
			var hero := pending[0] as Unit
			var zone: Array = deployment.get("_deploy_zone")
			var target := Vector2i(-1, -1)
			var preferred := Vector2i(4, 10)
			if zone.has(preferred) and grid.is_valid(preferred) \
					and grid.is_walkable(preferred) and not grid.has_unit(preferred):
				target = preferred
			else:
				for cell: Vector2i in zone:
					if grid.is_valid(cell) and grid.is_walkable(cell) and not grid.has_unit(cell):
						target = cell
						break
			if hero != null and hero.get_instance_id() != last_attempted_hero_id and target != Vector2i(-1, -1):
				last_attempted_hero_id = hero.get_instance_id()
				var attempt := {"time_usec": Time.get_ticks_usec(), "hero": hero.unit_name,
					"cell": [target.x, target.y], "preferred_cell_available": target == preferred,
					"deploy_zone_contains_cell": zone.has(target), "pending_heroes_before": pending.size()}
				# Route a validated placement click through the normal Battle entrypoint.
				# No start/deployment flags, grid occupants, turn state or locks are changed by the probe.
				battle._on_cell_clicked(target)
				attempt["hero_present_after_click"] = grid.get_unit(target) == hero
				attempt["pending_heroes_after"] = (deployment.get("_heroes_to_place") as Array).size()
				_deployment_clicks.append(attempt)
		await get_tree().process_frame
	return false


func _startup_snapshot(battle: Node) -> Dictionary:
	if not is_instance_valid(battle):
		var current_scene := get_tree().current_scene
		return {"time_usec": Time.get_ticks_usec(), "battle_valid": false,
			"current_scene": current_scene.scene_file_path if current_scene != null else "", "tree_paused": get_tree().paused}
	var deployment := battle.get("_deployment") as DeploymentController
	var grid := battle.get("grid") as GridData
	var state := battle.get("turn_state") as TurnState
	var queue := battle.get("turn_queue") as TurnQueue
	var current: Unit = queue.get_current_unit() as Unit if queue != null else null
	var presentation := battle.get("presentation_state") as CombatPresentationState
	var unit_entries: Array[Dictionary] = []
	for unit: Unit in battle.get("units"):
		unit_entries.append({"name": unit.unit_name, "team": unit.team, "alive": unit.is_alive,
			"cell": [unit.grid_pos.x, unit.grid_pos.y],
			"registered_in_grid": grid != null and grid.is_valid(unit.grid_pos) and grid.get_unit(unit.grid_pos) == unit})
	var pending: Array = deployment.get("_heroes_to_place") if deployment != null else []
	var zone: Array = deployment.get("_deploy_zone") if deployment != null else []
	var zone_values: Array = []
	for cell: Vector2i in zone:
		zone_values.append([cell.x, cell.y])
	return {"time_usec": Time.get_ticks_usec(), "battle_valid": true, "actual_scene": battle.scene_file_path,
		"runtime_ready": bool(battle.get("runtime_ready_state")), "tree_paused": get_tree().paused,
		"deployment_present": deployment != null, "deployment_active": deployment != null and deployment.is_active(),
		"pending_heroes": pending.size(), "valid_deployment_zone": zone_values,
		"units": unit_entries, "turn_state": int(state.current) if state != null else -1,
		"current_unit": current.unit_name if current != null else "", "current_unit_team": current.team if current != null else -1,
		"can_accept_player_intent": bool(battle._can_accept_player_intent()),
		"evolution_locked": bool(battle._is_evolution_locked()), "battle_closing": bool(battle.get("_closing")),
		"battle_over": bool(battle.get("_battle_over")), "direct_test_options": battle.get("_direct_test_options"),
		"presentation": presentation.get_snapshot() if presentation != null else {}}


func _finish_startup_failure(battle: Node, stage: String) -> void:
	var diagnostics := _startup_snapshot(battle)
	var screenshot_path := ""
	# A failure picture is outside animation timing and is useful even when the
	# successful path was requested with --no-screenshots.
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var screenshot := get_viewport().get_texture().get_image()
		if screenshot != null and not screenshot.is_empty():
			screenshot_path = _output.path_join("startup_failure_%s.png" % stage)
			if screenshot.save_png(screenshot_path) != OK:
				screenshot_path = ""
	_finish({"failed_startup_stage": stage, "startup_diagnostics": diagnostics,
		"startup_observations": _startup_observations, "deployment_clicks": _deployment_clicks,
		"startup_failure_screenshot": screenshot_path})

func _run_real_attack(battle: Node, hero: Unit, grid_view: Node2D,
		renderer: ArenaTerrainVisualRenderer, interaction: Node) -> Dictionary:
	if not await interaction._wait_for_player(battle, 5000):
		_errors.append("player_not_ready_for_attack_probe")
		return {}
	var caster := battle.get("spell_caster") as SpellCaster
	var selected: Spell = null
	var target := Vector2i(-1, -1)
	# Prefer damage against an in-range enemy. Sweep is always legally self
	# targetable and exercises the same first-release attack art if none is near.
	for wanted: StringName in [&"achilles_spear_thrust", &"achilles_sweep"]:
		for spell: Spell in hero.spells:
			if spell.get_effective_spell_id() != wanted or hero.get_spell_availability_reason(spell) != &"":
				continue
			var targets := caster.get_targetable_cells(hero, spell)
			if not targets.is_empty():
				selected = spell
				target = targets[0]
				break
		if selected != null:
			break
	if selected == null:
		_errors.append("no_legal_attack_spell_for_real_controller_probe")
		return {}
	var before_ap := hero.current_ap
	var before_uses := hero.get_spell_uses(selected)
	var before_releases: int = _action_events.releases
	var before_finishes: int = _action_events.finishes
	var expected_ap := hero.get_spell_ap_cost(selected)
	var floor_root := renderer.node_for_cell(target)
	var floor_sprite := floor_root.get_node_or_null("Visual") as Sprite2D if floor_root != null else null
	if floor_sprite == null:
		_errors.append("attack_target_floor_sprite_missing")
		return {}
	var polygon := GEOMETRY.sprite_polygon(floor_sprite)
	_active_action_timing = {"spell_id": str(selected.get_effective_spell_id()),
		"input_dispatched_usec": Time.get_ticks_usec(), "animation_started_usec": 0,
		"release_usec": 0, "finished_usec": 0}
	battle._on_spell_pressed(selected)
	interaction._route_local_pointer(grid_view, (polygon[0] + polygon[2]) * 0.5, true)
	var deadline := Time.get_ticks_msec() + 7000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if hero.current_ap == before_ap - expected_ap and not bool(battle.get("_spell_resolution_pending")) \
				and int(_action_events.finishes) == before_finishes + 1:
			break
	var result := {
		"spell_id": str(selected.get_effective_spell_id()), "target": [target.x, target.y],
		"ap_before": before_ap, "ap_after": hero.current_ap, "expected_ap_cost": expected_ap,
		"uses_before": before_uses, "uses_after": hero.get_spell_uses(selected),
		"release_count": int(_action_events.releases) - before_releases,
		"finish_count": int(_action_events.finishes) - before_finishes,
		"controller_returned_idle": (battle.get("turn_state") as TurnState).current == TurnState.State.IDLE,
		"animation_wall_timing": _active_action_timing.duplicate(true),
	}
	if hero.current_ap != before_ap - expected_ap or hero.get_spell_uses(selected) != before_uses + 1 \
			or int(result.release_count) != 1 or int(result.finish_count) != 1 or not bool(result.controller_returned_idle):
		_errors.append("real_attack_controller_contract_failed")
	grid_view.clear_selection()
	grid_view.update_hover(Vector2(-100000, -100000))
	return result

func _verify_stable_rest(visual: Node2D, unit_view: Node2D, phase: String) -> Dictionary:
	var profile: Resource = visual.get("sprite_profile")
	var local_foot := _sprite.offset + Vector2(profile.get("foot_anchor"))
	if _sprite.centered:
		local_foot -= Vector2(profile.get("frame_canvas_size")) * 0.5
	var initial_pose := _sprite.transform
	var initial_unit := unit_view.transform
	var first_foot := _sprite.get_global_transform_with_canvas() * local_foot
	var maximum_drift := 0.0
	var maximum_anchor_error := 0.0
	var unexpected_pose_samples := 0
	var samples := 0
	var start := Time.get_ticks_usec()
	while Time.get_ticks_usec() - start < 650000:
		await get_tree().process_frame
		var current_foot := _sprite.get_global_transform_with_canvas() * local_foot
		maximum_drift = maxf(maximum_drift, first_foot.distance_to(current_foot))
		maximum_anchor_error = maxf(maximum_anchor_error,
			current_foot.distance_to(unit_view.get_global_transform_with_canvas().origin))
		if not String(_sprite.animation).begins_with("idle_") or _sprite.frame != 0 \
				or _sprite.is_playing() or _sprite.transform != initial_pose or unit_view.transform != initial_unit:
			unexpected_pose_samples += 1
		samples += 1
	var result := {"phase": phase, "sample_count": samples,
		"observed_seconds": float(Time.get_ticks_usec() - start) / 1000000.0,
		"unexpected_pose_samples": unexpected_pose_samples, "maximum_screen_foot_drift_px": maximum_drift,
		"maximum_screen_anchor_error_px": maximum_anchor_error,
		"animation": str(_sprite.animation), "frame": _sprite.frame, "playing": _sprite.is_playing()}
	if samples == 0 or unexpected_pose_samples != 0 or maximum_drift > 0.01 or maximum_anchor_error > 0.01:
		_errors.append("unstable_rest_%s" % phase)
	return result

func _capture_current_state(action: String, label: String = "") -> void:
	var capture_key := action if label.is_empty() else label
	_pending_captures[capture_key] = true
	_capture_jobs += 1
	await RenderingServer.frame_post_draw
	if not is_instance_valid(_sprite) or not String(_sprite.animation).begins_with(action + "_"):
		_pending_captures.erase(capture_key)
		_capture_jobs -= 1
		return
	var start := Time.get_ticks_usec()
	var screenshot := get_viewport().get_texture().get_image()
	var readback_end := Time.get_ticks_usec()
	_capture_work_intervals.append({"capture": capture_key, "operation": "GPU_readback_during_playback",
		"started_usec": start, "ended_usec": readback_end, "duration_ms": float(readback_end - start) / 1000.0})
	if screenshot == null or screenshot.is_empty():
		_errors.append("empty_screenshot_%s" % action)
	else:
		var texture := _sprite.sprite_frames.get_frame_texture(_sprite.animation, _sprite.frame)
		var offset := _sprite.offset
		if _sprite.centered:
			offset -= texture.get_size() * 0.5
		_captures[capture_key] = {"path": _output.path_join("courtyard_%s.png" % capture_key),
			"animation": str(_sprite.animation), "frame": _sprite.frame,
			"size": [screenshot.get_width(), screenshot.get_height()],
			"gpu_readback_ms": float(readback_end - start) / 1000.0,
			"compression_deferred_until_after_actions": true}
		_deferred_pngs[capture_key] = {"image": screenshot, "texture": texture,
			"transform": _sprite.get_global_transform_with_canvas(), "offset": offset}
	_pending_captures.erase(capture_key)
	_capture_jobs -= 1


func _flush_deferred_captures() -> void:
	# Keep PNG compression and alpha-bound readbacks outside all measured actions.
	for capture_key: String in _deferred_pngs:
		var job: Dictionary = _deferred_pngs[capture_key]
		var screenshot := job.image as Image
		var texture := job.texture as Texture2D
		var start := Time.get_ticks_usec()
		if screenshot.save_png(str(_captures[capture_key].path)) != OK:
			_errors.append("screenshot_save_failed_%s" % capture_key)
			continue
		var source := texture.get_image()
		if source != null:
			if source.is_compressed():
				source.decompress()
			var used := Rect2(source.get_used_rect())
			var transform: Transform2D = job.transform
			var offset: Vector2 = job.offset
			var top_left := transform * (used.position + offset)
			var bottom_right := transform * (used.end + offset)
			_captures[capture_key]["sprite_screen_bounds"] = {
				"top_left": [top_left.x, top_left.y], "bottom_right": [bottom_right.x, bottom_right.y],
				"width_px": absf(bottom_right.x - top_left.x), "height_px": absf(bottom_right.y - top_left.y)}
		var finished := Time.get_ticks_usec()
		_capture_work_intervals.append({"capture": capture_key, "operation": "PNG_compression_and_bounds_after_actions",
			"started_usec": start, "ended_usec": finished, "duration_ms": float(finished - start) / 1000.0})
	_deferred_pngs.clear()

func _screen_bounds(sprite: AnimatedSprite2D) -> Dictionary:
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	var image := texture.get_image()
	if image == null:
		return {}
	if image.is_compressed():
		image.decompress()
	var used := Rect2(image.get_used_rect())
	var offset := sprite.offset
	if sprite.centered:
		offset -= texture.get_size() * 0.5
	var transform := sprite.get_global_transform_with_canvas()
	var top_left := transform * (used.position + offset)
	var bottom_right := transform * (used.end + offset)
	return {"top_left": [top_left.x, top_left.y], "bottom_right": [bottom_right.x, bottom_right.y],
		"width_px": absf(bottom_right.x - top_left.x), "height_px": absf(bottom_right.y - top_left.y)}


func _record_frame_interval(sample: Dictionary) -> void:
	if _previous_motion_sample.is_empty():
		return
	var previous := _previous_motion_sample
	var reason := ""
	if str(previous.clip) != str(sample.clip):
		reason = "clip_or_direction_changed"
	elif int(sample.frame) == 0 and int(previous.frame) > 0:
		reason = "loop_or_restart"
	elif int(sample.frame) != int(previous.frame) + 1:
		reason = "noncontiguous_observed_frame"
	elif not is_equal_approx(float(previous.speed_scale), float(sample.speed_scale)):
		reason = "speed_changed"
	var interval := {"clip": str(sample.clip), "previous_clip": str(previous.clip),
		"from_frame": int(previous.frame), "to_frame": int(sample.frame),
		"from_observed_usec": int(previous.time_usec), "to_observed_usec": int(sample.time_usec),
		"wall_duration_ms": float(int(sample.time_usec) - int(previous.time_usec)) / 1000.0,
		"from_frame_progress": float(previous.frame_progress), "to_frame_progress": float(sample.frame_progress)}
	if not reason.is_empty():
		interval["exclusion_reason"] = reason
		_frame_discontinuities.append(interval)
		return
	var expected_ms := 1000.0 * float(previous.source_duration) \
		/ (float(previous.source_fps) * absf(float(previous.speed_scale)))
	interval["expected_duration_ms"] = expected_ms
	interval["authored_fps"] = float(previous.source_fps)
	interval["speed_scale"] = float(previous.speed_scale)
	interval["wall_to_expected_ratio"] = float(interval.wall_duration_ms) / expected_ms
	_frame_intervals.append(interval)


func _update_motion_span(now: int, clip: String) -> void:
	if not _open_motion_span.is_empty() and str(_open_motion_span.clip) != clip:
		_close_motion_span(now)
	if _open_motion_span.is_empty():
		_open_motion_span = {"clip": clip, "observed_begin_usec": now, "previous_sample_usec": now,
			"max_process_sample_gap_ms": 0.0, "process_samples": 0,
			"max_sprite_own_translation_px": 0.0, "max_visual_own_translation_px": 0.0,
			"unit_parent_travel_px": 0.0, "_sprite_origin": _sprite.position,
			"_visual_origin": _observed_visual.position, "_unit_origin": _observed_unit_view.position,
			"_unit_previous": _observed_unit_view.position}
	var sprite_origin: Vector2 = _open_motion_span._sprite_origin
	var visual_origin: Vector2 = _open_motion_span._visual_origin
	var unit_previous: Vector2 = _open_motion_span._unit_previous
	_open_motion_span.max_sprite_own_translation_px = maxf(float(_open_motion_span.max_sprite_own_translation_px),
		sprite_origin.distance_to(_sprite.position))
	_open_motion_span.max_visual_own_translation_px = maxf(float(_open_motion_span.max_visual_own_translation_px),
		visual_origin.distance_to(_observed_visual.position))
	_open_motion_span.unit_parent_travel_px = float(_open_motion_span.unit_parent_travel_px) \
		+ unit_previous.distance_to(_observed_unit_view.position)
	_open_motion_span._unit_previous = _observed_unit_view.position
	_open_motion_span.max_process_sample_gap_ms = maxf(float(_open_motion_span.max_process_sample_gap_ms),
		float(now - int(_open_motion_span.previous_sample_usec)) / 1000.0)
	_open_motion_span.previous_sample_usec = now
	_open_motion_span.process_samples = int(_open_motion_span.process_samples) + 1


func _close_motion_span(now: int) -> void:
	if _open_motion_span.is_empty():
		return
	_open_motion_span["observed_end_usec"] = now
	_open_motion_span["measured_observed_duration_ms"] = float(now - int(_open_motion_span.observed_begin_usec)) / 1000.0
	var unit_origin: Vector2 = _open_motion_span._unit_origin
	_open_motion_span["unit_parent_displacement_px"] = unit_origin.distance_to(_observed_unit_view.position)
	for internal_key: String in ["_sprite_origin", "_visual_origin", "_unit_origin", "_unit_previous", "previous_sample_usec"]:
		_open_motion_span.erase(internal_key)
	_motion_spans.append(_open_motion_span)
	_open_motion_span = {}


func _on_sprite_animation_changed() -> void:
	var event := _record_synchronous_sprite_event("animation_changed")
	var clip := str(_sprite.animation)
	if not _open_synchronous_walk_span.is_empty() and clip != str(_open_synchronous_walk_span.clip):
		var start_event: Dictionary = _open_synchronous_walk_span.start_event
		var start_position := Vector2(float(start_event.unit_parent_position[0]), float(start_event.unit_parent_position[1]))
		var end_position := _observed_unit_view.position
		_open_synchronous_walk_span["end_event"] = event
		_open_synchronous_walk_span["wall_duration_ms"] = float(int(event.time_usec) - int(start_event.time_usec)) / 1000.0
		_open_synchronous_walk_span["unit_parent_displacement_px"] = start_position.distance_to(end_position)
		_synchronous_walk_spans.append(_open_synchronous_walk_span)
		_open_synchronous_walk_span = {}
	if clip.begins_with("walk_") and _open_synchronous_walk_span.is_empty():
		_open_synchronous_walk_span = {"clip": clip, "start_event": event}
	_last_signalled_clip = clip
	if _active_action_timing.is_empty() or not String(_sprite.animation).begins_with("attack_") \
			or int(_active_action_timing.get("animation_started_usec", 0)) != 0:
		return
	_active_action_timing.animation_started_usec = Time.get_ticks_usec()
	_active_action_timing["clip"] = str(_sprite.animation)
	var frames := _sprite.sprite_frames
	var fps := frames.get_animation_speed(_sprite.animation)
	var speed := absf(_sprite.speed_scale)
	var marker := int((_observed_visual.get("sprite_profile") as Resource).get("attack_release_frame"))
	var duration := 0.0
	var release_time := 0.0
	for frame_index in frames.get_frame_count(_sprite.animation):
		var seconds := frames.get_frame_duration(_sprite.animation, frame_index) / (fps * speed)
		duration += seconds
		if frame_index < marker:
			release_time += seconds
	_active_action_timing["expected_release_ms"] = release_time * 1000.0
	_active_action_timing["expected_animation_duration_ms"] = duration * 1000.0


func _on_sprite_frame_changed() -> void:
	_record_synchronous_sprite_event("frame_changed")


func _record_synchronous_sprite_event(kind: String) -> Dictionary:
	var sprite_parent := _sprite.get_parent()
	var unit_position := _observed_unit_view.position
	var sprite_position := _sprite.position
	var visual_position := _observed_visual.position
	var event := {"kind": kind, "time_usec": Time.get_ticks_usec(),
		"process_frame": Engine.get_process_frames(), "physics_frame": Engine.get_physics_frames(),
		"process_delta_seconds": get_process_delta_time(), "physics_delta_seconds": get_physics_process_delta_time(),
		"engine_time_scale": Engine.time_scale, "previous_signalled_clip": _last_signalled_clip,
		"clip": str(_sprite.animation), "frame": _sprite.frame, "frame_progress": _sprite.frame_progress,
		"live_clock_playing": _sprite.is_playing(), "speed_scale": _sprite.speed_scale,
		"distance_driven_move": bool(sprite_parent.get("_distance_driven_move")),
		"unit_parent_position": [unit_position.x, unit_position.y],
		"sprite_own_position": [sprite_position.x, sprite_position.y],
		"visual_own_position": [visual_position.x, visual_position.y]}
	if _synchronous_animation_events.size() < 512:
		_synchronous_animation_events.append(event)
	return event

func _on_visual_release() -> void:
	_action_events.releases += 1
	if _active_action_timing.is_empty():
		return
	var now := Time.get_ticks_usec()
	_active_action_timing.release_usec = now
	_active_action_timing["release_frame"] = _sprite.frame
	_active_action_timing["release_after_input_ms"] = float(now - int(_active_action_timing.input_dispatched_usec)) / 1000.0
	if int(_active_action_timing.animation_started_usec) > 0:
		_active_action_timing["release_after_animation_start_ms"] = float(now - int(_active_action_timing.animation_started_usec)) / 1000.0


func _on_visual_finished(_clip: StringName) -> void:
	_action_events.finishes += 1
	if _active_action_timing.is_empty():
		return
	var now := Time.get_ticks_usec()
	_active_action_timing.finished_usec = now
	if int(_active_action_timing.animation_started_usec) > 0:
		_active_action_timing["measured_animation_duration_ms"] = float(now - int(_active_action_timing.animation_started_usec)) / 1000.0
	if int(_active_action_timing.release_usec) > 0:
		_active_action_timing["recovery_after_release_ms"] = float(now - int(_active_action_timing.release_usec)) / 1000.0


func _timing_report() -> Dictionary:
	var by_clip: Dictionary = {}
	for interval: Dictionary in _frame_intervals:
		var clip: String = interval.clip
		var overlaps: Array[String] = []
		for work: Dictionary in _capture_work_intervals:
			if str(work.operation) == "GPU_readback_during_playback" \
					and int(work.started_usec) <= int(interval.to_observed_usec) \
					and int(work.ended_usec) >= int(interval.from_observed_usec):
				overlaps.append(str(work.capture))
		interval["overlapping_capture_readbacks"] = overlaps
		if not by_clip.has(clip):
			by_clip[clip] = {"samples": 0, "total_wall_ms": 0.0, "maximum_wall_ms": 0.0,
				"minimum_wall_ms": INF, "expected_duration_ms": interval.expected_duration_ms}
		var summary: Dictionary = by_clip[clip]
		summary.samples = int(summary.samples) + 1
		summary.total_wall_ms = float(summary.total_wall_ms) + float(interval.wall_duration_ms)
		summary.maximum_wall_ms = maxf(float(summary.maximum_wall_ms), float(interval.wall_duration_ms))
		summary.minimum_wall_ms = minf(float(summary.minimum_wall_ms), float(interval.wall_duration_ms))
	for summary: Dictionary in by_clip.values():
		summary["mean_wall_ms"] = float(summary.total_wall_ms) / float(summary.samples)
	return {"capture_mode": "visual_evidence_with_GPU_readback" if _capture_enabled else "no_screenshots",
		"unperturbed_by_capture_work": not _capture_enabled,
		"contiguous_same_clip_frame_intervals": _frame_intervals,
		"excluded_frame_transitions": _frame_discontinuities, "contiguous_summary_by_clip": by_clip,
		"observed_animation_spans": _motion_spans, "attack_action": _active_action_timing,
		"synchronous_animation_events": _synchronous_animation_events,
		"synchronous_walk_spans": _synchronous_walk_spans,
		"open_synchronous_walk_span": _open_synchronous_walk_span,
		"capture_work_intervals": _capture_work_intervals,
		"measurement_notes": "Raw wall time between first process observations of consecutive frame indices in the same clip at the same speed. Loops, direction changes and skipped observations are excluded from cadence statistics and retained separately. No phase correction, interpolation or stall removal is applied. Expected duration uses the authored frame duration / (FPS * speed). Sprite and facade translations are their own local positions; UnitView travel is measured separately in its parent's pixels. PNG compression and alpha bounds are deferred after actions; GPU readback still perturbs visual runs. Use the separate graphical --no-screenshots run for timing."}

func _finish(details: Dictionary) -> void:
	_observe = false
	var report := {
		"schema": "dd.achilles.sprite-courtyard-validation.v1",
		"ok": _errors.is_empty(), "errors": _errors,
		"godot_version": Engine.get_version_info().get("string", ""),
		"renderer": RenderingServer.get_current_rendering_method(),
	}
	report.merge(details)
	var file := FileAccess.open(_output.path_join("runtime_validation.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	else:
		push_error("Cannot write Achilles sprite validation report: %s" % _output)
		report["ok"] = false
	print("ACHILLES_SPRITE_VALIDATION ", JSON.stringify(report))
	get_tree().quit(0 if bool(report.ok) else 1)







