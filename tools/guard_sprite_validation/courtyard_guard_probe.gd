extends "res://tools/achilles_sprite_validation/courtyard_sprite_probe.gd"

## Uses the existing validated deployment and foot-anchor probes. Only the
## cast/move below is real player input. Damage is an explicitly labelled
## lifecycle probe through Unit.take_damage, not an enemy-AI action.
var _guard_view: Node2D
var _guard_effect: VFXShieldSpriteEffect
var _guard_observing := false
var _guard_moving := false
var _guard_samples: Array[Dictionary] = []
var _guard_phases: Array[String] = []
var _guard_last_key := ""
var _guard_phase_started := 0
var _guard_last_phase := ""
var _guard_maximum_follow_error := 0.0
var _guard_maximum_local_offset := 0.0
var _guard_capture_pending: Dictionary = {}
var _guard_images: Dictionary = {}
var _guard_capture_details: Dictionary = {}
var _guard_capture_jobs := 0
var _guard_clip_enabled := false
var _guard_clip_pending := false
var _guard_clip_epoch_usec := 0
var _guard_clip_last_capture_usec := 0
var _guard_clip_ended_usec := 0
var _guard_clip_rect := Rect2i()
var _guard_clip_images: Array[Image] = []
var _guard_clip_frames: Array[Dictionary] = []
var _guard_clip_report: Dictionary = {"enabled": false}
const GUARD_CLIP_MAX_FRAMES := 150
const GUARD_CLIP_INTERVAL_USEC := 33333


func _ready() -> void:
	_output = ProjectSettings.globalize_path("res://artifacts/guard_sprite_validation_v1")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--artifact-dir="):
			_output = ProjectSettings.globalize_path(argument.trim_prefix("--artifact-dir="))
	_capture_enabled = DisplayServer.get_name() != "headless" \
		and not OS.get_cmdline_user_args().has("--no-screenshots")
	_guard_clip_enabled = DisplayServer.get_name() != "headless" \
		and OS.get_cmdline_user_args().has("--capture-clip")
	DirAccess.make_dir_recursive_absolute(_output)
	_run.call_deferred()


func _process(_delta: float) -> void:
	if not _guard_observing or not is_instance_valid(_guard_view):
		return
	_maybe_capture_guard_clip()
	if not is_instance_valid(_guard_effect):
		_guard_effect = _find_guard(_guard_view)
	if not is_instance_valid(_guard_effect):
		return
	var phase := str(_guard_effect.get_phase_id())
	var runtime := _guard_effect.get_runtime_instance()
	if runtime == null:
		return
	var fx_sprite := _guard_sprite(_guard_effect)
	if fx_sprite == null:
		return
	var now := Time.get_ticks_usec()
	if phase != _guard_last_phase:
		_guard_last_phase = phase
		_guard_phase_started = now
		_guard_phases.append(phase)
	var key := "%s:%d" % [phase, fx_sprite.frame]
	if key != _guard_last_key:
		_guard_last_key = key
		_guard_samples.append({"time_usec": now, "phase": phase,
			"frame": fx_sprite.frame, "elapsed": runtime.elapsed,
			"duration": runtime.sequence.duration(), "moving": _guard_moving,
			"visible": fx_sprite.is_visible_in_tree()})
	_guard_maximum_follow_error = maxf(_guard_maximum_follow_error,
		_guard_effect.get_global_transform_with_canvas().origin.distance_to(
			_guard_view.get_global_transform_with_canvas().origin))
	_guard_maximum_local_offset = maxf(_guard_maximum_local_offset, _guard_effect.position.length())
	if not _capture_enabled:
		return
	var label := ""
	if phase == "activation" and runtime.elapsed >= 0.12:
		label = "activation"
	elif phase == "hold":
		label = "hold_moving" if _guard_moving and _sprite.frame >= 1 else "hold"
	elif phase == "hit" and runtime.elapsed >= 0.07:
		label = "hit"
	elif phase == "end" and runtime.elapsed >= 0.08:
		label = "end"
	if not label.is_empty() and not _guard_images.has(label) and not _guard_capture_pending.has(label):
		_capture_guard(label, phase)


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
		_errors.append("canonical_achilles_missing")
		_finish({})
		return
	var views: Dictionary = battle.get("_unit_views")
	_guard_view = views.get(hero) as Node2D
	var visual: Node2D = _guard_view.get_optional_visual() if _guard_view != null else null
	if visual == null:
		_errors.append("canonical_achilles_visual_missing")
		_finish({})
		return
	var hero_sprites := visual.find_children("*", "AnimatedSprite2D", true, false)
	if hero_sprites.size() != 1:
		_errors.append("canonical_achilles_sprite_missing")
		_finish({})
		return
	_sprite = hero_sprites[0] as AnimatedSprite2D
	var guard: Spell = null
	for spell: Spell in hero.spells:
		if spell.get_effective_spell_id() == &"achilles_guard":
			guard = spell
	if guard == null or guard.vfx_scene == null \
			or guard.vfx_scene.resource_path != "res://battle/vfx/achilles_guard_sprite_vfx.tscn":
		_errors.append("canonical_guard_sprite_scene_not_bound")
		_finish({})
		return
	var assembly: Dictionary = battle.get("arena_assembly")
	var renderer := assembly.get("renderer") as ArenaTerrainVisualRenderer
	var grid_view := battle.get("grid_view") as Node2D
	interaction.observed_clicks.clear()
	grid_view.cell_clicked.connect(interaction._observe_click)
	var before_ap := hero.current_ap
	var before_shield := hero.current_shield
	var before_uses := hero.get_spell_uses(guard)
	_guard_observing = true
	if _guard_clip_enabled:
		_begin_guard_clip()
		await get_tree().create_timer(0.15).timeout
	battle._on_spell_pressed(guard)
	var cast_route := _click_cell(interaction, grid_view, renderer, hero.grid_pos)
	deadline = Time.get_ticks_msec() + 7000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if hero.current_shield == 10 and is_instance_valid(_guard_effect) \
				and _guard_effect.get_phase_id() == &"hold" \
				and not bool(battle.get("_spell_resolution_pending")) \
				and bool(battle._can_accept_player_intent()):
			break
	if not is_instance_valid(_guard_effect):
		_errors.append("real_cast_did_not_spawn_bound_guard_sprite")
		_finish({"guard_cast_route": cast_route, "actual_shield": hero.current_shield,
			"ap_before": before_ap, "ap_after": hero.current_ap})
		return
	var cast_report := {"spell_id": str(guard.get_effective_spell_id()),
		"input_api": "Battle spell selection then GridView.update_hover/click_at floor sprite coordinates",
		"os_pointer_simulated": false, "routing": cast_route,
		"ap_before": before_ap, "ap_after": hero.current_ap,
		"shield_before": before_shield, "shield_after": hero.current_shield,
		"uses_before": before_uses, "uses_after": hero.get_spell_uses(guard),
		"phase": str(_guard_effect.get_phase_id()),
		"attached_to_real_unit_view": _guard_effect.get_parent() == _guard_view,
		"bound_to_real_hero": _guard_effect.get_bound_unit() == hero}
	if hero.current_ap != before_ap - 2 or hero.current_shield != 10 \
			or hero.get_spell_uses(guard) != before_uses + 1 \
			or _guard_effect.get_phase_id() != &"hold" \
			or _guard_effect.get_bound_unit() != hero:
		_errors.append("real_guard_gameplay_or_binding_contract_failed")
	var hold_runtime := _guard_effect.get_runtime_instance()
	var hold_geometry := hold_runtime.geometry_fingerprint()
	var hold_report := await _verify_stable_rest(visual, _guard_view, "guard_hold")
	hold_report["effect_elapsed"] = hold_runtime.elapsed
	hold_report["effect_frame"] = _guard_sprite(_guard_effect).frame
	hold_report["effect_geometry_stable"] = hold_runtime.geometry_fingerprint() == hold_geometry
	if hold_runtime.elapsed != 0.0 or _guard_sprite(_guard_effect).frame != 0 \
			or not bool(hold_report.effect_geometry_stable):
		_errors.append("guard_hold_animates_or_drifts")
	var movement_report := await _move_one_cell(battle, hero, interaction, grid_view, renderer)
	var rest_after_move := await _verify_stable_rest(visual, _guard_view, "guard_after_move")
	var lifecycle := await _probe_absorption(hero)
	if _guard_clip_enabled:
		await get_tree().create_timer(0.2).timeout
	_guard_clip_ended_usec = Time.get_ticks_usec()
	_guard_observing = false
	deadline = Time.get_ticks_msec() + 1000
	while (_guard_capture_jobs > 0 or _guard_clip_pending) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_flush_guard_images()
	_flush_guard_clip()
	for phase: String in ["activation", "hold", "hit", "end"]:
		if not _guard_phases.has(phase):
			_errors.append("guard_phase_not_observed:%s" % phase)
		if _capture_enabled and not _captures.has(phase):
			_errors.append("guard_screenshot_missing:%s" % phase)
	if _guard_maximum_follow_error > 0.01 or _guard_maximum_local_offset > 0.01:
		_errors.append("guard_does_not_follow_unit_anchor")
	_finish({"actual_scene": battle.scene_file_path,
		"actual_hero_data": hero.character_data.resource_path,
		"actual_vfx_scene": guard.vfx_scene.resource_path,
		"guard_cast": cast_report, "hold": hold_report,
		"real_move_after_guard": movement_report, "rest_after_move": rest_after_move,
		"lifecycle_probe": lifecycle, "observed_phases": _guard_phases,
		"frame_samples": _guard_samples,
		"maximum_effect_to_unit_anchor_error_px": _guard_maximum_follow_error,
		"maximum_effect_local_offset_px": _guard_maximum_local_offset,
		"screenshots": _captures, "capture_details": _guard_capture_details,
		"screenshot_capture_enabled": _capture_enabled, "capture_clip": _guard_clip_report,
		"scope": "Canonical courtyard, normal deployment, actual Guard cast and one-cell move via GridView; partial/full shield absorption separately labelled lifecycle_probe via Unit.take_damage. No replacement demo actor or manually spawned effect. PNG compression deferred until after playback; GPU readback may perturb visual runs. Clean timing requires --no-screenshots without --capture-clip."})


func _move_one_cell(battle: Node, hero: Unit, interaction: Node,
		grid_view: Node2D, renderer: ArenaTerrainVisualRenderer) -> Dictionary:
	if not await interaction._wait_for_player(battle, 5000):
		_errors.append("player_not_ready_to_move_with_guard")
		return {}
	var pathfinder := battle.get("pathfinder") as Pathfinder
	var grid := battle.get("grid") as GridData
	var start := hero.grid_pos
	var target := start
	var cost := 0
	for candidate: Vector2i in pathfinder.get_reachable(start, hero.current_mp, hero):
		var path := pathfinder.find_path(start, candidate, hero)
		if path.size() == 2:
			target = candidate
			cost = int(pathfinder.path_cost_breakdown(path, hero).get("total", 0))
			break
	if target == start or cost <= 0:
		_errors.append("no_legal_single_cell_move_for_guard")
		return {}
	var before_mp := hero.current_mp
	var before_ap := hero.current_ap
	_guard_moving = true
	battle._on_move_pressed()
	var route := _click_cell(interaction, grid_view, renderer, target)
	var deadline := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if hero.grid_pos == target and (battle.get("turn_state") as TurnState).current == TurnState.State.IDLE \
				and bool(battle._can_accept_player_intent()):
			break
	_guard_moving = false
	var okay: bool = hero.grid_pos == target and grid.get_unit(target) == hero \
		and hero.current_mp == before_mp - cost and hero.current_ap == before_ap \
		and hero.current_shield == 10 and is_instance_valid(_guard_effect) \
		and _guard_effect.get_phase_id() == &"hold"
	if not okay:
		_errors.append("move_with_guard_contract_failed")
	return {"ok": okay, "from": [start.x, start.y], "target": [target.x, target.y],
		"actual": [hero.grid_pos.x, hero.grid_pos.y], "route": route,
		"mp_before": before_mp, "mp_after": hero.current_mp, "cost": cost,
		"shield_after": hero.current_shield}


func _probe_absorption(hero: Unit) -> Dictionary:
	var hp_before := hero.current_hp
	var options := {"ignore_defense": true, "cannot_be_dodged": true}
	hero.take_damage(3, null, Spell.DamageType.PHYSICAL, Spell.Element.NONE, options)
	var partial := {"requested_damage": 3, "shield_after": hero.current_shield,
		"hp_after": hero.current_hp, "phase": str(_guard_effect.get_phase_id())}
	if hero.current_shield != 7 or hero.current_hp != hp_before or _guard_effect.get_phase_id() != &"hit":
		_errors.append("partial_absorption_lifecycle_failed")
	var deadline := Time.get_ticks_msec() + 2000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if is_instance_valid(_guard_effect) and _guard_effect.get_phase_id() == &"hold":
			break
	await get_tree().create_timer(0.15).timeout
	if not is_instance_valid(_guard_effect):
		_errors.append("partial_absorption_removed_remaining_shield_visual")
		return {"api": "Unit.take_damage; controlled lifecycle probe, not enemy AI", "partial": partial}
	var exhaustion_started_usec := Time.get_ticks_usec()
	hero.take_damage(7, null, Spell.DamageType.PHYSICAL, Spell.Element.NONE, options)
	var exhausted := {"requested_damage": 7, "shield_after": hero.current_shield,
		"hp_after": hero.current_hp, "phase": str(_guard_effect.get_phase_id())}
	if hero.current_shield != 0 or hero.current_hp != hp_before or _guard_effect.get_phase_id() != &"end":
		_errors.append("exhausted_shield_lifecycle_failed")
	deadline = Time.get_ticks_msec() + 2000
	while Time.get_ticks_msec() < deadline and is_instance_valid(_guard_effect):
		await get_tree().process_frame
	var visual_removed_usec := Time.get_ticks_usec()
	var removed := _find_guard(_guard_view) == null
	if not removed:
		_errors.append("exhausted_shield_visual_not_freed")
	return {"api": "Unit.take_damage; controlled lifecycle probe, not enemy AI",
		"partial": partial, "exhaustion": exhausted, "visual_removed_after_end": removed,
		"exhaustion_started_usec": exhaustion_started_usec,
		"visual_removed_usec": visual_removed_usec if removed else 0,
		"observed_dissolution_seconds": float(visual_removed_usec - exhaustion_started_usec) / 1000000.0 if removed else -1.0}


func _click_cell(interaction: Node, view: Node2D,
		renderer: ArenaTerrainVisualRenderer, cell: Vector2i) -> Dictionary:
	var root := renderer.node_for_cell(cell)
	var floor_sprite := root.get_node_or_null("Visual") as Sprite2D if root != null else null
	if floor_sprite == null:
		_errors.append("real_floor_sprite_missing:%s" % cell)
		return {}
	var polygon := GEOMETRY.sprite_polygon(floor_sprite)
	return interaction._route_local_pointer(view, (polygon[0] + polygon[2]) * 0.5, true)


func _find_guard(view: Node) -> VFXShieldSpriteEffect:
	for child in view.get_children():
		if child is VFXShieldSpriteEffect and not child.is_queued_for_deletion():
			return child
	return null


func _guard_sprite(effect: VFXShieldSpriteEffect) -> Sprite2D:
	var runtime := effect.get_runtime_instance()
	if runtime == null:
		return null
	var sprites := runtime.find_children("*", "Sprite2D", true, false)
	return sprites[0] as Sprite2D if not sprites.is_empty() else null


func _capture_guard(label: String, phase: String) -> void:
	_guard_capture_pending[label] = true
	_guard_capture_jobs += 1
	await RenderingServer.frame_post_draw
	if is_instance_valid(_guard_effect) and str(_guard_effect.get_phase_id()) == phase:
		var start := Time.get_ticks_usec()
		var picture := get_viewport().get_texture().get_image()
		if picture != null and not picture.is_empty():
			_guard_images[label] = picture
			var fx_sprite := _guard_sprite(_guard_effect)
			_guard_capture_details[label] = {"time_usec": start,
				"readback_ms": float(Time.get_ticks_usec() - start) / 1000.0,
				"phase": phase, "frame": fx_sprite.frame if fx_sprite != null else -1,
				"elapsed": _guard_effect.get_runtime_instance().elapsed,
				"hero_animation": str(_sprite.animation), "hero_frame": _sprite.frame}
	_guard_capture_pending.erase(label)
	_guard_capture_jobs -= 1


func _flush_guard_images() -> void:
	for label: String in _guard_images:
		var picture := _guard_images[label] as Image
		var path := _output.path_join("guard_%s.png" % label)
		if picture.save_png(path) == OK:
			_captures[label] = path
		else:
			_errors.append("capture_write_failed:%s" % label)
	_guard_images.clear()


func _begin_guard_clip() -> void:
	var viewport_size := Vector2i(get_viewport().get_visible_rect().size)
	var desired_size := Vector2i(mini(420, viewport_size.x), mini(340, viewport_size.y))
	# Fixed, real viewport crop: includes the character, its full aura and a
	# one-cell move in any cardinal direction without tracking or reassembly.
	var anchor := _guard_view.get_global_transform_with_canvas().origin
	var center := anchor + Vector2(0.0, -65.0)
	var origin := Vector2i(center - Vector2(desired_size) * 0.5)
	origin.x = clampi(origin.x, 0, maxi(0, viewport_size.x - desired_size.x))
	origin.y = clampi(origin.y, 0, maxi(0, viewport_size.y - desired_size.y))
	_guard_clip_rect = Rect2i(origin, desired_size)
	_guard_clip_epoch_usec = Time.get_ticks_usec()
	_guard_clip_last_capture_usec = 0


func _maybe_capture_guard_clip() -> void:
	if not _guard_clip_enabled or _guard_clip_pending or _guard_clip_epoch_usec == 0 \
			or _guard_clip_frames.size() >= GUARD_CLIP_MAX_FRAMES:
		return
	if Time.get_ticks_usec() - _guard_clip_last_capture_usec < GUARD_CLIP_INTERVAL_USEC:
		return
	_capture_guard_clip_frame()


func _capture_guard_clip_frame() -> void:
	_guard_clip_pending = true
	await RenderingServer.frame_post_draw
	var captured_usec := Time.get_ticks_usec()
	_guard_clip_last_capture_usec = captured_usec
	var viewport_image := get_viewport().get_texture().get_image()
	if viewport_image != null and not viewport_image.is_empty():
		var picture := viewport_image.get_region(_guard_clip_rect)
		var phase := str(_guard_effect.get_phase_id()) if is_instance_valid(_guard_effect) else "none"
		_guard_clip_images.append(picture)
		_guard_clip_frames.append({"index": _guard_clip_frames.size(),
			"capture_usec": captured_usec,
			"time_seconds": float(captured_usec - _guard_clip_epoch_usec) / 1000000.0,
			"readback_and_crop_ms": float(Time.get_ticks_usec() - captured_usec) / 1000.0,
			"phase": phase, "moving": _guard_moving,
			"hero_animation": str(_sprite.animation), "hero_frame": _sprite.frame})
	_guard_clip_pending = false


func _flush_guard_clip() -> void:
	if not _guard_clip_enabled:
		return
	var directory := _output.path_join("clip")
	DirAccess.make_dir_recursive_absolute(directory)
	for index in _guard_clip_images.size():
		var path := directory.path_join("frame_%04d.png" % index)
		if _guard_clip_images[index].save_png(path) == OK:
			_guard_clip_frames[index]["path"] = path
		else:
			_errors.append("guard_clip_frame_write_failed:%d" % index)
	_guard_clip_report = {"enabled": true, "schema": "dd.achilles.guard-gameplay-clip.v1",
		"source": "Real viewport screenshot after frame_post_draw; fixed crop only",
		"target_fps": 30, "maximum_frames": GUARD_CLIP_MAX_FRAMES,
		"frame_count": _guard_clip_frames.size(),
		"frame_limit_reached": _guard_clip_frames.size() >= GUARD_CLIP_MAX_FRAMES,
		"rectangle_px": [_guard_clip_rect.position.x, _guard_clip_rect.position.y,
			_guard_clip_rect.size.x, _guard_clip_rect.size.y],
		"started_usec": _guard_clip_epoch_usec, "ended_usec": _guard_clip_ended_usec,
		"frames": _guard_clip_frames,
		"timing_note": "Presentation capture, not a timing benchmark. GPU readback and crop can perturb playback. Encode using recorded timestamps, never an assumed constant 30 fps. PNG compression happens after the scenario."}
	var path := directory.path_join("clip_manifest.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_guard_clip_report, "  "))
		file.close()
		_guard_clip_report["manifest_path"] = path
	else:
		_errors.append("guard_clip_manifest_write_failed")
	_guard_clip_images.clear()


func _finish(details: Dictionary) -> void:
	_guard_observing = false
	var report := {"schema": "dd.achilles.guard-sprite-courtyard-validation.v1",
		"ok": _errors.is_empty(), "errors": _errors,
		"godot_version": Engine.get_version_info().get("string", ""),
		"renderer": RenderingServer.get_current_rendering_method()}
	report.merge(details)
	var file := FileAccess.open(_output.path_join("runtime_validation.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	else:
		report["ok"] = false
		push_error("Cannot write Guard sprite validation report: %s" % _output)
	print("GUARD_SPRITE_VALIDATION ", JSON.stringify(report))
	get_tree().quit(0 if bool(report.ok) else 1)
