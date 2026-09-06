extends Node

## Run with trial_entry_probe.tscn. This observer survives normal scene changes;
## it follows production selection, transition and deployment, then one EndTurn.
const SELECTION_PATH := "res://ui/selection/CharacterSelectionScreen.tscn"
const TRIAL_PATH := "res://data/runs/philosopher_trial.tres"
const ROOM_PATH := "res://data/rooms/philosopher_trial.tres"
const TRANSITION_PATH := "res://ui/Transitionsalle.tscn"
const BATTLE_PATH := "res://battle/painted/registered_terrain/RegisteredTerrainBattle.tscn"
const EXPECTED_TERRAIN_PLAN := "res://data/arenas/lethe_crossing_v1/terrain_plan.json"
const EXPECTED_FRAMES := {
	&"achilles": "res://assets/characters/Achilles/sprites_kit_v2/achilles_sprite_frames.tres",
	&"philosopher_mage": "res://assets/characters/philosopher_mage/sprites_v1/philosopher_sprite_frames.tres",
	&"spectre_greatsword": "res://assets/characters/spectre_greatsword/sprites_v1/spectre_sprite_frames.tres",
}

var _persistent := false
var _output := ""
var _capture_enabled := false
var _finished := false
var _errors: Array[String] = []
var _scenes: Array[Dictionary] = []
var _actions: Array[Dictionary] = []
var _captures: Dictionary = {}
var _selection: Dictionary = {}
var _progression_before: Array[Dictionary] = []
var _last_scene := ""
var _natural_casts: Array[Dictionary] = []
var _first_turn: Dictionary = {}
var _first_turn_observing := false
var _first_turn_completed := false
var _first_turn_mage: Unit
var _first_turn_grid: GridData
var _first_turn_battle: Node
var _first_turn_grid_events: Array[Dictionary] = []
var _first_turn_casts: Array[Dictionary] = []
var _first_turn_movements: Array[Dictionary] = []
var _first_turn_ap: Array[Dictionary] = []



class DeploymentInteractions:
	extends "res://tools/achilles_sprite_validation/courtyard_sprite_probe.gd"

	func _ready() -> void:
		pass


func _ready() -> void:
	if not _persistent:
		# SceneTree replaces the current scene through the ordinary navigation.
		# A sibling observer remains alive to follow it, without replacing state.
		var observer := get_script().new() as Node
		observer.set("_persistent", true)
		observer.name = "PhilosopherTrialEntryObserver"
		get_tree().root.add_child.call_deferred(observer)
		set_process(false)
		return
	_output = ProjectSettings.globalize_path("res://artifacts/philosopher_sprite_validation_v1/trial_entry")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--artifact-dir="):
			_output = ProjectSettings.globalize_path(argument.trim_prefix("--artifact-dir="))
	_capture_enabled = DisplayServer.get_name() != "headless" \
		and not OS.get_cmdline_user_args().has("--no-screenshots")
	DirAccess.make_dir_recursive_absolute(_output)
	EventBus.spell_cast.connect(_on_natural_cast)
	_run.call_deferred()


func _process(_delta: float) -> void:
	if not _persistent or _finished:
		return
	var current := get_tree().current_scene
	if current != null and current.scene_file_path != _last_scene:
		_last_scene = current.scene_file_path
		_scenes.append({"scene": _last_scene, "time_usec": Time.get_ticks_usec()})


func _run() -> void:
	if get_tree().change_scene_to_file(SELECTION_PATH) != OK:
		_fail("selection_scene_load_failed")
		return
	var screen := await _wait_scene(SELECTION_PATH, 20000) as CharacterSelectionScreen
	if screen == null:
		_fail("selection_scene_timeout")
		return
	await get_tree().create_timer(0.55).timeout
	var entry_index := -1
	var entries := screen.get_entries()
	for index in entries.size():
		var run := entries[index].get("run") as RunData
		if run != null and run.resource_path == TRIAL_PATH:
			if entry_index != -1:
				_errors.append("trial_selection_entry_duplicated")
			entry_index = index
	if entry_index < 0:
		_fail("trial_selection_entry_missing")
		return
	var roster: Array = screen.get("_roster_buttons")
	var entry_button := roster[entry_index] as Button
	if entry_button == null or not entry_button.is_visible_in_tree() or entry_button.disabled:
		_fail("trial_selection_button_unavailable")
		return
	entry_button.pressed.emit()
	_actions.append({"action": "select_roster_button", "index": entry_index})
	await get_tree().process_frame
	var selected := screen.get_selected_entry()
	var selected_run := selected.get("run") as RunData
	if selected_run == null or selected_run.resource_path != TRIAL_PATH:
		_fail("roster_button_did_not_select_trial")
		return
	_selection = {"entry_index": entry_index, "entry_count": entries.size(),
		"run_path": selected_run.resource_path, "chapter": selected.chapter,
		"party_note": selected.party_note, "button_visible": entry_button.is_visible_in_tree(),
		"button_rect": _rect(entry_button.get_global_rect()),
		"start_button_text": screen.start_button.text,
		"start_button_enabled": not screen.start_button.disabled,
		"occluding_panels": _occluding_panels(screen, entry_button)}
	if not (_selection.occluding_panels as Array).is_empty():
		_errors.append("trial_roster_button_center_occluded_by_later_panel")
	await get_tree().create_timer(0.35).timeout
	await _capture("selection_trial")
	if screen.start_button.disabled:
		_fail("trial_start_button_disabled")
		return
	screen.start_button.pressed.emit()
	_actions.append({"action": "press_start_adventure", "run_path": TRIAL_PATH})
	var transition := await _wait_scene(TRANSITION_PATH, 20000)
	if transition == null:
		_fail("production_room_transition_timeout")
		return
	var active_run := GameManager.get("_active_run_data") as RunData
	var room := GameManager.get_current_room()
	if not GameManager.run_active or active_run == null or active_run.resource_path != TRIAL_PATH:
		_errors.append("production_game_manager_run_mismatch")
	if room == null or room.resource_path != ROOM_PATH:
		_errors.append("production_room_resource_mismatch")
	for state in GameManager.get_ordered_character_states():
		var snapshot := state.champion_progression.to_snapshot() if state.champion_progression != null else {}
		_progression_before.append({"unit_id": str(state.unit.unit_id), "progression": snapshot,
			"hp": state.unit.current_hp, "max_hp": state.unit.max_hp.get_int()})
		if int(snapshot.get("current_level", -1)) != 1 or int(snapshot.get("current_xp", -1)) != 0 \
				or not (snapshot.get("selected_node_ids", []) as Array).is_empty():
			_errors.append("hero_did_not_start_with_normal_level_one_progression")
		if state.unit.current_hp != state.unit.max_hp.get_int():
			_errors.append("hero_did_not_start_at_normal_full_health")
	await get_tree().create_timer(0.25).timeout
	await _capture("room_transition")
	var continue_button := transition.get_node_or_null("Contenu/BoutonContinuer") as Button
	if continue_button == null or not continue_button.is_visible_in_tree() or continue_button.disabled:
		_fail("production_continue_button_unavailable")
		return
	continue_button.pressed.emit()
	_actions.append({"action": "press_room_continue", "room_path": ROOM_PATH})
	var battle := await _wait_scene(BATTLE_PATH, 30000)
	if battle == null:
		_fail("registered_terrain_battle_timeout")
		return
	var deadline := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline and is_instance_valid(battle):
		if bool(battle.get("runtime_ready_state")) and bool(battle.get("registered_terrain_ready")):
			break
		await get_tree().process_frame
	if not bool(battle.get("runtime_ready_state")) or not bool(battle.get("registered_terrain_ready")):
		_fail("production_terrain_not_ready")
		return
	await _capture("production_deployment")
	var deployment := DeploymentInteractions.new()
	add_child(deployment)
	if not await deployment._wait_for_real_deployment(battle, 15000):
		_errors.append("normal_player_deployment_failed")
	else:
		_actions.append({"action": "normal_deployment_clicks", "clicks": deployment.get("_deployment_clicks")})
	# Preserve the untouched opening before one ordinary player EndTurn.
	await get_tree().create_timer(0.65).timeout
	await _wait_for_turn_banner(battle)
	var observations := _inspect_production_battle(battle)
	await _capture("production_combat")
	var first_turn_result: Variant = await _observe_first_production_turn(battle)
	_first_turn = first_turn_result if first_turn_result is Dictionary else {}
	if not bool(_first_turn.get("ok", false)):
		_errors.append("production_first_turn_validation_failed")
	_finish(observations)


func _inspect_production_battle(battle: Node) -> Dictionary:
	var room := battle.get("room_data") as RoomData
	var active_encounter := GameManager.get_current_encounter_definition()
	if room == null or room.resource_path != ROOM_PATH:
		_errors.append("battle_did_not_use_registered_trial_room")
	if active_encounter == null or active_encounter.encounter_id != &"philosopher_trial":
		_errors.append("battle_did_not_use_registered_trial_encounter")
	var direct_options: Dictionary = battle.get("_direct_test_options")
	if not direct_options.is_empty():
		_errors.append("production_entry_unexpectedly_used_direct_test_options")
	var unit_ids: Array[String] = []
	var units_report: Array[Dictionary] = []
	var painted_scales: Dictionary = {}
	var views: Dictionary = battle.get("_unit_views")
	for unit: Unit in battle.get("units"):
		unit_ids.append(str(unit.unit_id))
		var detail := {"id": str(unit.unit_id), "team": unit.team,
			"hp": unit.current_hp, "max_hp": unit.max_hp.get_int(),
			"cell": [unit.grid_pos.x, unit.grid_pos.y], "visual_scene": unit.visual_scene.resource_path if unit.visual_scene != null else ""}
		var view := views.get(unit) as Node2D
		var visual := view.get_optional_visual() as Node2D if view != null else null
		if view != null:
			var painted_scale := float(view.get_painted_visual_scale())
			painted_scales[unit.unit_id] = painted_scale
			detail["painted_visual_scale"] = painted_scale
			var family := view.get("_painted_family_profile") as UnitVisualProfile
			detail["painted_family_profile"] = family.resource_path if family != null else ""
		if visual == null:
			_errors.append("production_unit_visual_missing:" + str(unit.unit_id))
			units_report.append(detail)
			continue
		var sprites := visual.find_children("*", "AnimatedSprite2D", true, false)
		detail["sprite_count"] = sprites.size()
		detail["backend"] = str(visual.get_active_backend_name()) if visual.has_method("get_active_backend_name") else ""
		if sprites.size() != 1 or detail.backend != "Sprite2DBackend" \
				or not visual.find_children("*", "SubViewport", true, false).is_empty() \
				or not visual.find_children("*", "Node3D", true, false).is_empty():
			_errors.append("production_unit_not_canonical_sprite:" + str(unit.unit_id))
		if sprites.size() == 1:
			var sprite := sprites[0] as AnimatedSprite2D
			detail["frames_path"] = sprite.sprite_frames.resource_path if sprite.sprite_frames != null else ""
			detail["animation"] = str(sprite.animation)
			detail["visible"] = sprite.is_visible_in_tree()
			if unit.unit_id == &"philosopher_mage":
				var profile := visual.get("sprite_profile") as PhilosopherSpriteVisualProfile
				var foot_error := sprite.to_global(sprite.offset + profile.foot_anchor).distance_to(view.global_position) \
					if profile != null else INF
				detail["ground_anchor_error_pixels"] = foot_error
				if foot_error > 0.1:
					_errors.append("production_mage_ground_pivot_moved")
			if detail.frames_path != EXPECTED_FRAMES.get(unit.unit_id, "") or not sprite.is_visible_in_tree():
				_errors.append("production_sprite_atlas_missing_or_hidden:" + str(unit.unit_id))
		units_report.append(detail)
	var mage_scale := float(painted_scales.get(&"philosopher_mage", 0.0))
	var hero_scale := float(painted_scales.get(&"achilles", 0.0))
	var mage_to_hero_scale := mage_scale / hero_scale if hero_scale > 0.0 else 0.0
	if mage_scale <= 1.4 or mage_to_hero_scale < 0.9 or mage_to_hero_scale > 1.1:
		_errors.append("production_mage_map_scale_mismatches_achilles")
	unit_ids.sort()
	if unit_ids != ["achilles", "philosopher_mage", "spectre_greatsword"]:
		_errors.append("production_encounter_roster_mismatch")
	var axiom := load("res://data/spells/enemies/philosopher_axiom.tres") as Spell
	var classification := str(battle.get("spell_caster").get_action_classification(axiom))
	if classification != "PROJECTILE":
		_errors.append("production_axiom_projectile_classification_missing")
	for cast in _natural_casts:
		if int(cast.team) == 0:
			_errors.append("probe_unexpected_player_spell")
	return {"actual_scene": battle.scene_file_path,
		"room_path": room.resource_path if room != null else "",
		"encounter_id": str(active_encounter.encounter_id) if active_encounter != null else "",
		"registered_terrain_ready": bool(battle.get("registered_terrain_ready")),
		"terrain_plan": battle.get("registered_terrain_plan_path"),
		"terrain": _inspect_production_terrain(battle, room as ArenaDefinition),
		"direct_test_options": direct_options, "units": units_report,
		"axiom_classification": classification, "natural_enemy_casts": _natural_casts.duplicate(true),
		"mage_painted_visual_scale": mage_scale, "achilles_painted_visual_scale": hero_scale,
		"mage_to_achilles_scale_ratio": mage_to_hero_scale,
		"startup_observer_only": true}


func _occluding_panels(screen: CharacterSelectionScreen, button: Button) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var canvas := screen.get("_canvas") as Control
	for child in canvas.get_children():
		if child is Panel and child.is_visible_in_tree() and child.get_index() > button.get_index() \
				and child.get_global_rect().has_point(button.get_global_rect().get_center()):
			result.append({"name": str(child.name), "rect": _rect(child.get_global_rect())})
	return result


func _rect(value: Rect2) -> Array:
	return [value.position.x, value.position.y, value.size.x, value.size.y]


func _wait_scene(path: String, timeout_ms: int) -> Node:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		var candidate := get_tree().current_scene
		if candidate != null and candidate.scene_file_path == path and candidate.is_node_ready():
			return candidate
	return null


func _capture(label: String) -> void:
	if not _capture_enabled:
		return
	await RenderingServer.frame_post_draw
	var picture := get_viewport().get_texture().get_image()
	var path := _output.path_join(label + ".png")
	if picture == null or picture.save_png(path) != OK:
		_errors.append("capture_failed:" + label)
		return
	_captures[label] = path


func _on_natural_cast(caster: Unit, spell: Spell, report: Dictionary) -> void:
	var detail := {"unit_id": str(caster.unit_id), "team": caster.team,
		"spell_id": str(spell.spell_id), "failed": bool(report.get("failed", false)),
		"time_usec": Time.get_ticks_usec(), "caster_cell": [caster.grid_pos.x, caster.grid_pos.y],
		"caster_ap_after": caster.current_ap, "ap_cost": caster.get_spell_ap_cost(spell)}
	_natural_casts.append(detail)
	if _first_turn_observing and caster == _first_turn_mage:
		var target_cell: Vector2i = report.get("cell", caster.grid_pos)
		var spell_caster := _first_turn_battle.get("spell_caster") as SpellCaster
		var pathfinder := _first_turn_battle.get("pathfinder") as Pathfinder
		detail["target_cell"] = [target_cell.x, target_cell.y]
		detail["distance"] = _first_turn_grid.manhattan(caster.grid_pos, target_cell)
		detail["minimum_range"] = spell_caster.get_effective_spell_minimum_range(caster, spell)
		detail["maximum_range"] = spell_caster.get_effective_spell_range(caster, spell)
		detail["line_of_sight"] = pathfinder.has_line_of_sight(caster.grid_pos, target_cell)
		detail["projectile_path"] = pathfinder.has_projectile_path(caster.grid_pos, target_cell)
		detail["classification"] = str(spell_caster.get_action_classification(spell))
		detail["needs_line_of_sight"] = spell.needs_line_of_sight
		var port = _first_turn_battle.get("_hud_port")
		var banner := port.get_turn_intro_banner() as Control if port != null else null
		detail["banner_visible"] = is_instance_valid(banner) and banner.is_visible_in_tree()
		_first_turn_casts.append(detail.duplicate(true))
	elif _first_turn_observing and caster.team == 0:
		_errors.append("first_turn_unexpected_player_spell")


func _fail(reason: String) -> void:
	_errors.append(reason)
	_finish({})


func _finish(observations: Dictionary) -> void:
	if _finished:
		return
	_finished = true
	_disconnect_first_turn_observers()
	if EventBus.spell_cast.is_connected(_on_natural_cast):
		EventBus.spell_cast.disconnect(_on_natural_cast)
	var report := {"ok": _errors.is_empty(), "errors": _errors,
		"entrypoint": SELECTION_PATH, "production_run": TRIAL_PATH,
		"selection": _selection, "scene_transitions": _scenes, "ui_actions": _actions,
		"initial_progression": _progression_before, "screenshots": _captures,
		"observations": observations, "first_turn": _first_turn,
		"startup_observer_only": false, "player_combat_intents": ["end_turn"]}
	var file := FileAccess.open(_output.path_join("trial_entry_validation.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
	else:
		push_error("Cannot write trial entry validation report")
	print("PHILOSOPHER_TRIAL_ENTRY " + JSON.stringify(report))
	get_tree().quit(0 if _errors.is_empty() and file != null else 1)


func _wait_for_turn_banner(battle: Node) -> void:
	var started := Time.get_ticks_msec()
	var deadline := started + 6000
	while Time.get_ticks_msec() < deadline and is_instance_valid(battle):
		var hud = battle.get("_hud_port")
		var banner := hud.get_turn_intro_banner() as Control if hud != null else null
		if Time.get_ticks_msec() - started >= 1800 and (not is_instance_valid(banner) or not banner.visible):
			return
		await get_tree().process_frame


func _inspect_production_terrain(battle: Node, arena: ArenaDefinition) -> Dictionary:
	if arena == null:
		_errors.append("production_trial_requires_arena_definition")
		return {}
	var grid := battle.get("grid") as GridData
	var terrain := battle.get("terrain_effects") as TerrainEffects
	var assembly: Dictionary = battle.get("arena_assembly")
	var renderer := assembly.get("renderer") as ArenaTerrainVisualRenderer
	var interactive_renderer := assembly.get("interactive_renderer") as ArenaTerrainVisualRenderer
	if grid == null or terrain == null or renderer == null:
		_errors.append("production_trial_terrain_runtime_missing")
		return {}
	if arena.registered_terrain_plan_path != EXPECTED_TERRAIN_PLAN \
			or str(battle.get("registered_terrain_plan_path")) != EXPECTED_TERRAIN_PLAN:
		_errors.append("production_trial_did_not_load_lethe_terrain_plan")
	var required_ids: Array[StringName] = [&"lava", &"water", &"ice"]
	var observed_ids: Array[StringName] = [&"lava", &"water", &"ice", &"electrified_water"]
	var counts := {}
	var special_cells: Array[Dictionary] = []
	for definition: ArenaCellDefinition in arena.cells:
		if definition == null or not definition.defined \
				or definition.cell_type == GridData.CellType.HOLE:
			continue
		var terrain_id := definition.terrain_id
		counts[str(terrain_id)] = int(counts.get(str(terrain_id), 0)) + 1
		if terrain_id not in observed_ids:
			continue
		var cell := definition.coordinate
		var catalog := ArenaCatalogService.terrain(terrain_id)
		var state := terrain.get_surface_state(cell)
		var tile := renderer.node_for_cell(cell)
		var sprite := tile.get_node_or_null("Visual") as Sprite2D if tile != null else null
		var texture_path := sprite.texture.resource_path if sprite != null and sprite.texture != null else ""
		var shader_path := ""
		if sprite != null and sprite.material is ShaderMaterial:
			var material := sprite.material as ShaderMaterial
			shader_path = material.shader.resource_path if material.shader != null else ""
		var expected_texture := catalog.base_texture.resource_path \
			if catalog != null and catalog.base_texture != null else ""
		var visible := sprite != null and sprite.is_visible_in_tree()
		var entry := {"cell": [cell.x, cell.y], "terrain_id": str(terrain_id),
			"grid_type": grid.get_type(cell), "texture": texture_path,
			"expected_texture": expected_texture, "shader": shader_path, "visible": visible,
			"base_terrain_id": str(state.base_terrain_id) if state != null else "",
			"apply_on_enter": state.base_apply_on_enter if state != null else false,
			"apply_on_turn_start": state.base_apply_on_turn_start if state != null else false,
			"effect_damage": state.base_effect.damage if state != null and state.base_effect != null else 0,
			"status_id": str(state.base_effect.applied_status.get_effective_status_id())
				if state != null and state.base_effect != null and state.base_effect.applied_status != null else ""}
		special_cells.append(entry)
		if state == null or state.base_terrain_id != terrain_id or not state.base_apply_on_enter:
			_errors.append("production_permanent_terrain_runtime_mismatch:%s:%s" % [terrain_id, cell])
		if not visible or expected_texture.is_empty() or texture_path != expected_texture:
			_errors.append("production_permanent_terrain_art_missing:%s:%s" % [terrain_id, cell])
		if shader_path == "res://battle/painted/registered_terrain/shaders/stone_palette.gdshader":
			_errors.append("production_special_terrain_recolored_as_stone:%s:%s" % [terrain_id, cell])
	for terrain_id in required_ids:
		if int(counts.get(str(terrain_id), 0)) <= 0:
			_errors.append("production_trial_required_terrain_missing:" + str(terrain_id))
	var render_report := renderer.actual_render_report()
	var expected_floor_count := 0
	for count: Variant in counts.values():
		expected_floor_count += int(count)
	if int(render_report.get("rendered_terrain_node_count", 0)) != expected_floor_count \
			or int(battle.get("registered_floor_tile_count")) != expected_floor_count \
			or not (render_report.get("errors", []) as Array).is_empty():
		_errors.append("production_floor_render_count_mismatch")
	if int(battle.get("limestone_tile_count")) != int(counts.get("stone", 0)):
		_errors.append("production_stone_palette_count_mismatch")
	var networks: Array[Dictionary] = []
	var usable_network_count := 0
	var vortex_catalog := ArenaCatalogService.interactive(&"vortex")
	var vortex_texture := vortex_catalog.texture.resource_path \
		if vortex_catalog != null and vortex_catalog.texture != null else ""
	for network: ArenaVortexNetworkDefinition in arena.vortex_networks:
		if network == null or not network.enabled:
			continue
		var cells := network.unique_cells()
		if cells.size() >= 2:
			usable_network_count += 1
		var endpoints: Array[Dictionary] = []
		for cell: Vector2i in cells:
			var actual_network := grid.get_vortex_network(cell)
			var actual_cells := grid.get_vortex_network_cells(cell)
			var tile := interactive_renderer.node_for_cell(cell) if interactive_renderer != null else null
			var sprite := tile.get_node_or_null("Visual") as Sprite2D if tile != null else null
			var visible := sprite != null and sprite.is_visible_in_tree()
			var texture := sprite.texture.resource_path if sprite != null and sprite.texture != null else ""
			endpoints.append({"cell": [cell.x, cell.y], "actual_network_id": str(actual_network.get("network_id", "")),
				"actual_cells": actual_cells.map(func(value): return [value.x, value.y]),
				"visible": visible, "texture": texture, "has_grid_portal": grid.has_vortex(cell)})
			if not grid.has_vortex(cell) or actual_network.get("network_id", &"") != network.network_id \
					or int(actual_network.get("allowed_teams", 0)) != network.allowed_teams \
					or not bool(actual_network.get("enabled", false)) or actual_cells.size() != cells.size():
				_errors.append("production_vortex_runtime_mismatch:%s:%s" % [network.network_id, cell])
			for expected_cell: Vector2i in cells:
				if not actual_cells.has(expected_cell):
					_errors.append("production_vortex_endpoint_missing:%s" % expected_cell)
			if not visible or vortex_texture.is_empty() or texture != vortex_texture:
				_errors.append("production_vortex_art_missing:%s" % cell)
		networks.append({"id": str(network.network_id), "allowed_teams": network.allowed_teams,
			"random_destination": network.random_destination, "endpoints": endpoints})
	if usable_network_count == 0:
		_errors.append("production_trial_teleport_network_missing")
	return {"arena_id": str(arena.arena_id), "grid_size": [grid.cols, grid.rows],
		"terrain_plan": arena.registered_terrain_plan_path, "terrain_counts": counts,
		"permanent_special_cells": special_cells, "vortex_networks": networks,
		"registered_floor_tile_count": int(battle.get("registered_floor_tile_count")),
		"stone_palette_tile_count": int(battle.get("limestone_tile_count")),
		"rendered_terrain_node_count": int(render_report.get("rendered_terrain_node_count", 0)),
		"rendered_by_terrain_id": render_report.get("rendered_by_terrain_id", {}),
		"observation_only": true}


func _observe_first_production_turn(battle: Node) -> Dictionary:
	var error_start := _errors.size()
	var player_ready := false
	var input_deadline := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < input_deadline and is_instance_valid(battle) \
			and battle.is_inside_tree() and not bool(battle.get("_battle_over")):
		var active := battle.get_active_unit() as Unit
		if is_instance_valid(active) and active.is_alive and active.team == 0 \
				and bool(battle._can_accept_player_intent()):
			player_ready = true
			break
		await get_tree().process_frame
	if not player_ready:
		_errors.append("production_player_not_ready_for_first_end_turn")
		return {"ok": false, "player_end_turn_requests": 0}
	for unit: Unit in battle.get("units"):
		if unit.unit_id == &"philosopher_mage":
			_first_turn_mage = unit
			break
	if not is_instance_valid(_first_turn_mage):
		_errors.append("production_first_turn_mage_missing")
		return {"ok": false, "player_end_turn_requests": 0}
	_first_turn_grid = battle.get("grid") as GridData
	_first_turn_battle = battle
	var initial := {"cell": [_first_turn_mage.grid_pos.x, _first_turn_mage.grid_pos.y],
		"hp": _first_turn_mage.current_hp, "ap": _first_turn_mage.current_ap,
		"mp": _first_turn_mage.current_mp, "activation": _first_turn_mage.activation_index}
	if int(initial.activation) != 0:
		_errors.append("production_mage_already_acted_before_first_player_end_turn")
	_first_turn_observing = true
	_first_turn_grid.occupancy_changed.connect(_on_first_turn_grid_change)
	EventBus.voluntary_movement_resolved.connect(_on_first_turn_movement)
	EventBus.ap_after_action_changed.connect(_on_first_turn_ap_change)
	EventBus.turn_ended.connect(_on_first_turn_ended)
	var requested_at := Time.get_ticks_usec()
	battle._on_end_turn_pressed()
	var confirmation: Node = battle.get("_end_turn_confirmation")
	var confirmed := is_instance_valid(confirmation) and bool(confirmation.is_open())
	if confirmed:
		confirmation._on_confirmed()
	_actions.append({"action": "press_end_turn", "confirmation_accepted": confirmed,
		"source": "production_end_turn_callback", "time_usec": requested_at})
	var captured := false
	var deadline := Time.get_ticks_msec() + 25000
	while Time.get_ticks_msec() < deadline and is_instance_valid(battle) \
			and battle.is_inside_tree() and not bool(battle.get("_battle_over")):
		await get_tree().process_frame
		if not captured and not _first_turn_casts.is_empty():
			await _capture("production_enemy_turn")
			captured = true
		if _first_turn_completed:
			break
	if not _first_turn_completed:
		_errors.append("production_first_mage_activation_did_not_complete")
	var jump := _first_real_portal_jump()
	if jump.is_empty():
		_errors.append("production_first_mage_turn_did_not_use_actual_portal")
	var casts_after_portal: Array[Dictionary] = []
	for cast: Dictionary in _first_turn_casts:
		if not jump.is_empty() and int(cast.time_usec) >= int(jump.time_usec) \
				and cast.caster_cell == jump.to and not bool(cast.failed):
			casts_after_portal.append(cast)
			if int(cast.distance) < int(cast.minimum_range) or int(cast.distance) > int(cast.maximum_range) \
					or (bool(cast.needs_line_of_sight) and not bool(cast.line_of_sight)) \
					or (str(cast.classification) == "PROJECTILE" and not bool(cast.projectile_path)):
				_errors.append("production_first_turn_cast_not_legal_from_actual_exit")
			if bool(cast.banner_visible):
				_errors.append("production_first_turn_spell_hidden_by_banner")
	if casts_after_portal.is_empty():
		_errors.append("production_first_turn_missing_real_cast_after_portal")
	var paid_mp := 0
	for movement: Dictionary in _first_turn_movements:
		paid_mp += int(movement.paid_mp)
	var paid_ap := 0
	for expense: Dictionary in _first_turn_ap:
		paid_ap += int(expense.paid_ap)
	if paid_mp <= 0 or paid_ap <= 0:
		_errors.append("production_first_turn_did_not_spend_real_action_resources")
	var final_cell := _first_turn_mage.grid_pos
	var result := {"ok": _errors.size() == error_start, "player_end_turn_requests": 1,
		"player_requested_spells": 0, "requested_at_usec": requested_at,
		"initial_mage": initial, "completed": _first_turn_completed,
		"final_mage_cell": [final_cell.x, final_cell.y],
		"actual_portal_jump": jump, "real_ai_casts": _first_turn_casts.duplicate(true),
		"casts_after_portal": casts_after_portal, "grid_events": _first_turn_grid_events.duplicate(true),
		"movements": _first_turn_movements.duplicate(true), "ap_expenses": _first_turn_ap.duplicate(true),
		"paid_mp": paid_mp, "paid_ap": paid_ap, "stats_or_positions_modified_by_probe": false}
	_disconnect_first_turn_observers()
	return result


func _on_first_turn_grid_change(reason: StringName, unit, from: Vector2i, to: Vector2i) -> void:
	if not _first_turn_observing or unit != _first_turn_mage:
		return
	_first_turn_grid_events.append({"reason": str(reason), "time_usec": Time.get_ticks_usec(),
		"from": [from.x, from.y], "to": [to.x, to.y],
		"actual_cell": [unit.grid_pos.x, unit.grid_pos.y],
		"network_id": str(_first_turn_grid.get_vortex_network(from).get("network_id", ""))})


func _on_first_turn_movement(unit, path: Array, paid_cost: int, action_id: StringName) -> void:
	if _first_turn_observing and unit == _first_turn_mage:
		_first_turn_movements.append({"time_usec": Time.get_ticks_usec(),
			"path": path.map(func(value): return [value.x, value.y]),
			"paid_mp": paid_cost, "action_id": str(action_id)})


func _on_first_turn_ap_change(unit, before: int, after: int, action_id: StringName) -> void:
	if _first_turn_observing and unit == _first_turn_mage:
		_first_turn_ap.append({"time_usec": Time.get_ticks_usec(), "before": before,
			"after": after, "paid_ap": before - after, "action_id": str(action_id)})


func _on_first_turn_ended(unit, _reason: StringName) -> void:
	if _first_turn_observing and unit == _first_turn_mage:
		_first_turn_completed = true


func _first_real_portal_jump() -> Dictionary:
	for event: Dictionary in _first_turn_grid_events:
		var from := Vector2i(int(event.from[0]), int(event.from[1]))
		var to := Vector2i(int(event.to[0]), int(event.to[1]))
		if from != to and not str(event.network_id).is_empty() \
				and _first_turn_grid.get_vortex_network_cells(from).has(to) \
				and event.actual_cell == event.to:
			return event.duplicate(true)
	return {}


func _disconnect_first_turn_observers() -> void:
	_first_turn_observing = false
	if _first_turn_grid != null and _first_turn_grid.occupancy_changed.is_connected(_on_first_turn_grid_change):
		_first_turn_grid.occupancy_changed.disconnect(_on_first_turn_grid_change)
	if EventBus.voluntary_movement_resolved.is_connected(_on_first_turn_movement):
		EventBus.voluntary_movement_resolved.disconnect(_on_first_turn_movement)
	if EventBus.ap_after_action_changed.is_connected(_on_first_turn_ap_change):
		EventBus.ap_after_action_changed.disconnect(_on_first_turn_ap_change)
	if EventBus.turn_ended.is_connected(_on_first_turn_ended):
		EventBus.turn_ended.disconnect(_on_first_turn_ended)
