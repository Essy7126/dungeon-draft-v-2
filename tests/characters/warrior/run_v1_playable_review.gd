extends Node

const ELF_PATH := "res://data/units/alliés/elfe.tres"
const MAGE_PATH := "res://data/units/alliés/mage.tres"
const WARRIOR_PATH := "res://data/units/alliés/Guerrier.tres"
const FIXED_RUN_PATH := "res://data/runs/fixed_trio_prototype_run.tres"
const ARTIFACT_DIR := "res://artifacts/run_v1_playable_pass"
const RUNTIME_REPORT_PATH := "C:/Blender_AI_Test/Output/run_v1_playable_runtime.json"
const CENTER := Vector2i(5, 4)
const REVIEW_SPELL_IDS := [
	&"warrior_shove",
	&"warrior_hook",
	&"warrior_shoulder_charge",
	&"warrior_execution",
]

@onready var battle = $Battle

var elf: Unit
var mage: Unit
var warrior: Unit
var warrior_view: Node2D
var warrior_iso: WarriorIsoUnitView
var reference_enemy: Unit
var reference_enemy_view: Node2D
var review_state: CharacterRunState
var progression_service := CharacterProgressionService.new()
var errors: Array[String] = []
var warnings: Array[String] = []
var damage_events := 0
var spell_cast_events := 0
var release_events := 0


func _enter_tree() -> void:
	GameManager.cleanup_run_state()
	elf = Unit.from_data(load(ELF_PATH) as UnitData)
	mage = Unit.from_data(load(MAGE_PATH) as UnitData)
	warrior = Unit.from_data(load(WARRIOR_PATH) as UnitData)
	GameManager.heroes = [elf, mage, warrior]
	var run_data := load(FIXED_RUN_PATH) as RunData
	GameManager.rooms = run_data.rooms.duplicate()
	GameManager.current_room_index = 0
	GameManager.run_active = true
	review_state = CharacterRunState.new()
	if not review_state.initialize(warrior, load(WARRIOR_PATH) as UnitData, 8):
		errors.append("Warrior review state initialization failed")


func _ready() -> void:
	EventBus.damage_dealt.connect(_on_damage_dealt)
	EventBus.spell_cast.connect(_on_spell_cast)
	await get_tree().process_frame
	var debug_overlay := battle.get_node_or_null("DebugOverlay") as CanvasItem
	if debug_overlay != null:
		debug_overlay.visible = false
	if battle.inspect_panel != null:
		battle.inspect_panel.visible = false
	if battle.player_combat_log != null:
		battle.player_combat_log.visible = false
	if not await _deploy_party():
		errors.append("Fixed trio deployment failed")
		_finish_and_quit(31)
		return
	_select_warrior_final_state()
	await _settle_hud()

	var static_capture := _argument_value("--run-v1-static=")
	if not static_capture.is_empty():
		await _capture_artifact(static_capture)
		_write_json(RUNTIME_REPORT_PATH, {
			"capture": static_capture,
			"hud": _hud_snapshot(),
			"errors": errors,
		})
		_finish_and_quit(0 if errors.is_empty() else 32)
		return
	if "--run-v1-review" in OS.get_cmdline_user_args():
		await _run_playable_review()
		_finish_and_quit(0 if errors.is_empty() else 33)


func _exit_tree() -> void:
	if EventBus.damage_dealt.is_connected(_on_damage_dealt):
		EventBus.damage_dealt.disconnect(_on_damage_dealt)
	if EventBus.spell_cast.is_connected(_on_spell_cast):
		EventBus.spell_cast.disconnect(_on_spell_cast)


func _deploy_party() -> bool:
	for cell in [Vector2i(9, 7), Vector2i(8, 7), Vector2i(7, 7)]:
		if battle._deployment == null or not battle._deployment.is_active():
			return false
		battle._deployment.on_cell_clicked(cell)
		await get_tree().process_frame
	warrior_view = battle._unit_views.get(warrior) as Node2D
	if warrior_view == null or not warrior_view.has_method("get_optional_visual"):
		return false
	warrior_iso = warrior_view.get_optional_visual() as WarriorIsoUnitView
	if warrior_iso == null:
		return false
	warrior_iso.cast_release_reached.connect(func(): release_events += 1)
	var enemies: Array = battle.units.filter(
		func(unit): return unit != null and unit.team == 1
	)
	if enemies.is_empty():
		return false
	reference_enemy = enemies[0] as Unit
	reference_enemy_view = battle._unit_views.get(reference_enemy) as Node2D
	return is_instance_valid(reference_enemy_view)


func _run_playable_review() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ARTIFACT_DIR))
	_activate_unit_turn(elf)
	await get_tree().create_timer(0.55).timeout
	_activate_unit_turn(mage)
	await get_tree().create_timer(0.55).timeout
	_activate_unit_turn(warrior)
	await _settle_hud()
	await _capture_artifact("trio_run_playable.png")
	await _capture_artifact("warrior_no_energy_ui.png")

	var action_results := []
	for spell_id in REVIEW_SPELL_IDS:
		var capture_name := ""
		if spell_id == &"warrior_shoulder_charge":
			capture_name = "warrior_breaker_animation.png"
		elif spell_id == &"warrior_execution":
			capture_name = "warrior_execution_animation.png"
		action_results.append(await _cast_profiled_spell(spell_id, capture_name))
		await get_tree().create_timer(0.45).timeout
	action_results.append(await _cast_profiled_spell(
		&"warrior_stomp",
		"warrior_ravager_animation.png"
	))
	await get_tree().create_timer(0.45).timeout

	var breaker_progress := review_state.get_discipline_progress(&"warrior_breaker")
	var skill_screen = GameManager.get_persistent_run_ui().get_skill_tree_screen()
	var tree_opened := false
	if breaker_progress == null or breaker_progress.xp < 3:
		errors.append("Breaker did not gain the expected cast XP")
	elif not skill_screen.open_for_state(review_state, &"warrior_breaker"):
		errors.append("Warrior skill tree failed to open")
	else:
		tree_opened = true
		await get_tree().create_timer(0.85).timeout
		await _capture_artifact("warrior_skill_tree.png")
		if not review_state.select_upgrade(
			&"warrior_breaker",
			2,
			&"warrior_breaker_driving_shove"
		):
			errors.append("Driving Shove upgrade selection failed")
		skill_screen.close_screen()
		await get_tree().create_timer(0.35).timeout

	var upgrade_effect := await _validate_driving_shove_effect()
	var movement_result := await _validate_one_cell_move()
	var performance := await _sample_performance()
	var vfx_layer := battle.get_node_or_null("VFXLayer")
	var residual_vfx := vfx_layer.get_child_count() if vfx_layer != null else 0
	if residual_vfx != 0:
		errors.append("Residual VFX found after review")
	warnings.append(
		"Warrior spells use generic impact feedback because no dedicated vfx_scene is assigned."
	)
	_select_warrior_final_state()
	await _settle_hud()
	var report := {
		"verdict": "RUN_V1_PLAYABLE_PASS_COMPLETE" if errors.is_empty() else "RUN_V1_PLAYABLE_PASS_INCOMPLETE",
		"party": [elf.unit_id, mage.unit_id, warrior.unit_id],
		"room_count": GameManager.rooms.size(),
		"warrior": {
			"max_ap": warrior.max_ap.get_int(),
			"max_mp": warrior.max_mp.get_int(),
			"has_energy": warrior.has_energy(),
			"trait_count": warrior.traits.size(),
			"spell_count": warrior.spells.size(),
			"discipline_count": review_state.get_disciplines().size(),
			"breaker_xp": breaker_progress.xp if breaker_progress != null else -1,
			"selected_upgrades": breaker_progress.selected_upgrade_ids if breaker_progress != null else [],
		},
		"hud": _hud_snapshot(),
		"actions": action_results,
		"upgrade_effect": upgrade_effect,
		"movement": movement_result,
		"performance": performance,
		"vfx_residual_count": residual_vfx,
		"skill_tree_opened": tree_opened,
		"errors": errors,
		"warnings": warnings,
	}
	_write_json(RUNTIME_REPORT_PATH, report)


func _cast_profiled_spell(spell_id: StringName, capture_name: String) -> Dictionary:
	var spell := _spell_by_id(spell_id)
	if spell == null:
		errors.append("Missing Warrior spell %s" % spell_id)
		return {"spell_id": spell_id, "error": "missing"}
	_prepare_warrior_and_enemy()
	_activate_unit_turn(warrior)
	_hide_turn_banner()
	warrior.current_ap = 100
	battle._spell_resolution_pending = false
	warrior_iso.cancel_spell_action()
	var target_cell := warrior.grid_pos if spell.is_self_only() else reference_enemy.grid_pos
	var visual := warrior_iso.get_warrior_visual()
	var expected_animation := visual.get_animation_for_spell(spell)
	var releases_before := release_events
	var casts_before := spell_cast_events
	var damage_before := damage_events
	var started := Time.get_ticks_msec()
	await battle._on_request_cast_spell(spell, target_cell, false)
	progression_service.grant_cast_xp(
		{&"warrior": review_state},
		warrior,
		spell,
		{}
	)
	var elapsed := float(Time.get_ticks_msec() - started) / 1000.0
	if not capture_name.is_empty():
		await _capture_artifact(capture_name)
	var result := {
		"spell_id": spell_id,
		"spell_name": spell.spell_name,
		"animation": expected_animation,
		"active_at_impact": visual.get_current_animation(),
		"speed": visual.get_playback_speed_for_spell(spell),
		"impact_normalized": visual.get_impact_normalized_for_spell(spell),
		"final_duration": visual.get_calibrated_duration(expected_animation),
		"impact_wait_seconds": elapsed,
		"release_events": release_events - releases_before,
		"spell_cast_events": spell_cast_events - casts_before,
		"damage_events": damage_events - damage_before,
	}
	if result.release_events != 1 or result.spell_cast_events != 1:
		errors.append("%s did not resolve exactly once" % spell.spell_name)
	if result.active_at_impact != expected_animation:
		errors.append("%s did not retain its animation at impact" % spell.spell_name)
	return result


func _validate_driving_shove_effect() -> Dictionary:
	var shove := _spell_by_id(&"warrior_shove")
	_prepare_warrior_and_enemy()
	_activate_unit_turn(warrior)
	warrior.current_ap = 100
	var from := reference_enemy.grid_pos
	await battle._on_request_cast_spell(shove, from, false)
	var distance: int = battle.grid.manhattan(from, reference_enemy.grid_pos)
	if distance != 2:
		errors.append("Driving Shove moved %d cells instead of 2" % distance)
	return {
		"upgrade_id": &"warrior_breaker_driving_shove",
		"from": [from.x, from.y],
		"to": [reference_enemy.grid_pos.x, reference_enemy.grid_pos.y],
		"distance": distance,
	}


func _validate_one_cell_move() -> Dictionary:
	_force_relocate(warrior, CENTER, warrior_view)
	var from := warrior.grid_pos
	var to := from + Vector2i.DOWN
	var iso_root := warrior_iso.position
	var relocated: bool = battle.grid.relocate_unit(warrior, to)
	if relocated:
		battle._animate_move(warrior, [from, to])
		await get_tree().create_timer(0.4).timeout
	var expected: Vector2 = battle.grid_cell_to_parent_local(
		to,
		warrior_view.get_parent()
	)
	var final_error := warrior_view.position.distance_to(expected)
	if not relocated or final_error > 0.01 or warrior_iso.position != iso_root:
		errors.append("Warrior one-cell movement validation failed")
	return {
		"from": [from.x, from.y],
		"to": [to.x, to.y],
		"relocated": relocated,
		"final_position_error": final_error,
		"iso_root_stable": warrior_iso.position == iso_root,
	}


func _sample_performance() -> Dictionary:
	_select_warrior_final_state()
	var samples: Array[float] = []
	var deadline := Time.get_ticks_msec() + 1500
	while Time.get_ticks_msec() < deadline:
		var fps := Engine.get_frames_per_second()
		if fps > 0:
			samples.append(fps)
		await get_tree().process_frame
	if samples.is_empty():
		return {"average_fps": 0.0, "minimum_fps": 0.0, "samples": 0}
	var total := 0.0
	var minimum := INF
	for sample in samples:
		total += sample
		minimum = minf(minimum, sample)
	return {
		"average_fps": total / samples.size(),
		"minimum_fps": minimum,
		"samples": samples.size(),
	}


func _prepare_warrior_and_enemy() -> void:
	_force_relocate(warrior, CENTER, warrior_view)
	_force_relocate(reference_enemy, CENTER + Vector2i.RIGHT, reference_enemy_view)
	reference_enemy.current_hp = 10000
	warrior_iso.set_facing(Vector2i.RIGHT)


func _force_relocate(unit: Unit, cell: Vector2i, view: Node2D) -> bool:
	var occupant = battle.grid.get_unit(cell)
	if occupant != null and occupant != unit:
		var spare := _find_spare_cell([cell, unit.grid_pos])
		if spare == Vector2i(-1, -1):
			return false
		var occupant_view = battle._unit_views.get(occupant) as Node2D
		if not battle.grid.relocate_unit(occupant, spare):
			return false
		if is_instance_valid(occupant_view):
			occupant_view.position = battle.grid_cell_to_parent_local(
				spare,
				occupant_view.get_parent()
			)
	if not battle.grid.relocate_unit(unit, cell):
		return false
	view.position = battle.grid_cell_to_parent_local(cell, view.get_parent())
	return true


func _find_spare_cell(excluded: Array) -> Vector2i:
	for y in battle.grid.rows:
		for x in battle.grid.cols:
			var cell := Vector2i(x, y)
			if cell in excluded or not battle.grid.is_walkable(cell) or battle.grid.has_unit(cell):
				continue
			return cell
	return Vector2i(-1, -1)


func _spell_by_id(spell_id: StringName) -> Spell:
	for spell in (load(WARRIOR_PATH) as UnitData).spells:
		if spell.spell_id == spell_id:
			return spell
	return null


func _activate_unit_turn(unit: Unit) -> void:
	var order: Array = battle.turn_queue.get_full_order()
	var index := order.find(unit)
	if index < 0:
		errors.append("%s absent from TurnQueue" % unit.unit_name)
		return
	battle.turn_queue._current_index = index
	unit.start_turn()
	battle._on_turn_started(unit)
	for view in battle._unit_views.values():
		if is_instance_valid(view) and view.has_method("set_active"):
			view.set_active(view == battle._unit_views.get(unit))


func _select_warrior_final_state() -> void:
	if warrior == null or not warrior.is_alive:
		return
	_activate_unit_turn(warrior)
	warrior_iso.cancel_spell_action()
	warrior_iso.play_idle()
	var hud := GameManager.get_persistent_run_ui().get_combat_hud()
	hud.set_active_mode("")
	hud.set_player_controls_enabled(true)
	hud.show_layout_debug = false
	var vfx_layer := battle.get_node_or_null("VFXLayer")
	if vfx_layer != null:
		for child in vfx_layer.get_children():
			child.queue_free()


func _settle_hud() -> void:
	_hide_turn_banner()
	for _frame in range(5):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _hide_turn_banner() -> void:
	var hud := GameManager.get_persistent_run_ui().get_combat_hud()
	var banner = hud.get_node_or_null("%TurnIntroBanner")
	if banner != null and banner.has_method("hide_immediately"):
		banner.hide_immediately()


func _hud_snapshot() -> Dictionary:
	var hud := GameManager.get_persistent_run_ui().get_combat_hud()
	var viewport_size := get_viewport().get_visible_rect().size
	var panel_size: Vector2 = hud.get_character_panel_size()
	return {
		"viewport": [viewport_size.x, viewport_size.y],
		"panel_size": [panel_size.x, panel_size.y],
		"vertical_ratio": panel_size.y / maxf(viewport_size.y, 1.0),
		"spell_slots": hud.get("_spell_buttons").size(),
		"energy_bar_visible": hud.get_node("%EnergyBar").visible,
		"energy_name_visible": hud.get_node("%EnergyNameLabel").visible,
		"awakening_visible": hud.get_node("%AwakeningButton").visible,
		"reaction_visible": hud.get_node("%ReactionButton").visible,
		"layout_debug": hud.show_layout_debug,
	}


func _capture_artifact(filename: String) -> String:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ARTIFACT_DIR))
	var resource_path := "%s/%s" % [ARTIFACT_DIR, filename]
	var error := get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path(resource_path)
	)
	if error != OK:
		errors.append("Artifact capture failed: %s (%d)" % [filename, error])
		return ""
	return resource_path


func _argument_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


func _on_damage_dealt(
		target,
		attacker,
		_amount: int,
		_category: int,
		_element: int,
		_is_crit: bool
	) -> void:
	if target == reference_enemy and attacker == warrior:
		damage_events += 1


func _on_spell_cast(caster, _spell, _report: Dictionary) -> void:
	if caster == warrior:
		spell_cast_events += 1


func _write_json(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		errors.append("Cannot write %s" % path)
		return
	file.store_string(JSON.stringify(value, "\t"))
	file.close()


func _finish_and_quit(code: int) -> void:
	get_tree().quit(code)
