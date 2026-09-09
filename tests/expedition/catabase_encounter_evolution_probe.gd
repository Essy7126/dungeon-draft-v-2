extends Node
## Exact production rosters and deployment, plus a player-facing route preview.
## No simulated victories below are evidence of a won or balanced full run.
const CATALOG := preload("res://core/expedition/catabase_monster_encounter_catalog.gd")
const PREVIEW := preload("res://ui/expedition/expedition_encounter_preview.gd")
const CLEANUP := preload("res://test/support/isolated_battlefield_cleanup.gd")
const SEEDS := [2401, 42, 777]
var _checks := 0
var _errors: Array[String] = []
var _captures: Array[String] = []
var _encounters: Array[Dictionary] = []
var _runtime_nodes: Array[String] = []
var _formation_failures: Array[Dictionary] = []
var _resolution := Vector2i(1280, 720)
var _output := ""
var _capture := false
var _finished := false


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("resolution="):
			var dimensions := argument.trim_prefix("resolution=").split("x")
			if dimensions.size() == 2:
				_resolution = Vector2i(int(dimensions[0]), int(dimensions[1]))
	_capture = "capture=true" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	_output = ProjectSettings.globalize_path("res://artifacts/catabase_monsters/evolution/%dx%d" % [_resolution.x, _resolution.y])
	DirAccess.make_dir_recursive_absolute(_output)
	get_window().size = _resolution
	get_tree().create_timer(240.0).timeout.connect(func():
		if not _finished:
			_errors.append("Probe exceeded 240 seconds")
			_finish())
	_run.call_deferred()


func _run() -> void:
	GameManager.expedition_save_path = _output.path_join("isolated_probe_save.json")
	GameManager.set_reduced_motion_enabled(true)
	# Hold sources throughout the pass so reloading cannot mask shared mutations.
	var source_rooms := ExpeditionMapCatalog.all_rooms()
	for seed_value: int in SEEDS:
		for node: Dictionary in ExpeditionRouteCatalog.create_nodes(seed_value):
			if not ExpeditionRouteCatalog.is_combat(str(node.kind)):
				continue
			_validate_data(node, seed_value)
	_check(source_rooms.size() == 15, "All authored arenas remained available")
	await _probe_route()
	if "data_only" not in OS.get_cmdline_user_args():
		# A ranged early pack, slow heavy pack, and late support-led crowd.
		for id: String in ["d02_1", "d06_0", "d18_0"]:
			for node: Dictionary in ExpeditionRouteCatalog.create_nodes(SEEDS[0]):
				if str(node.id) == id:
					await _probe_battle(node)
	_finish()


func _validate_data(node: Dictionary, seed_value: int) -> void:
	var label := "%s seed%d" % [node.id, seed_value]
	var room := ExpeditionRunFactory.make_room(node, seed_value)
	var encounter := room.get_encounter_for_wave(0)
	_check(encounter.is_valid(), label + ": valid encounter")
	_check(room.enemies.size() == encounter.get_initial_enemy_count(), label + ": complete expanded roster")
	var grid := EncounterGridFactory.build_from_room(room)
	var planner := EncounterFormationPlanner.new(grid, Pathfinder.new(grid))
	var plan := planner.build_plan(encounter, room.hero_spawn_zone, room.enemy_spawn_zone, seed_value)
	_check(bool(plan.get("valid", false)), label + ": legal formation " + str(plan.get("reason", "")))
	if not bool(plan.get("valid", false)):
		var capacity := {}
		for data: UnitData in encounter.roster_units:
			var minimum := int(encounter.minimum_path_distance_by_role.get(data.tactical_role_id, 0))
			var allowed := 0
			for cell: Vector2i in planner.call("_all_walkable_cells"):
				var distance: int = planner.call("_minimum_path_distance", cell, room.hero_spawn_zone)
				if distance >= minimum and distance < 999999 and not encounter.forbidden_initial_spawn_cells.has(cell):
					allowed += 1
			capacity[str(data.tactical_role_id)] = {"minimum": minimum, "eligible_cells": allowed}
		_formation_failures.append({"node": str(node.id), "seed": seed_value, "roles": capacity})
	_check((plan.get("placements", []) as Array).size() == room.enemies.size(), label + ": no missing bodies")
	if CATALOG.uses_monsters(node):
		var published := node.duplicate(true)
		published.knowledge = "near"
		published.room_index = -1
		var preview := PREVIEW.describe(published, seed_value)
		_check(int(preview.get("count", 0)) == room.enemies.size(), label + ": announced count matches combat")
		_check(room.enemies.size() >= 1 and room.enemies.size() <= 8, label + ": authored 1–8 body budget")
		_check(encounter.living_enemy_cap == room.enemies.size(), label + ": living cap matches roster")
		for data: UnitData in room.enemies:
			_check(data.max_hp > 0 and data.max_mp > 0, label + ": active enemy stats")
			_check(not data.spells.is_empty(), label + ": real techniques")
			_check(str(preview.get("details", "")).contains(data.unit_name), label + ": enemy identity announced")
			for spell: Spell in data.spells:
				_check(spell != null and spell.ap_cost <= data.max_ap, label + ": affordable technique")
				if spell == null:
					continue
				_check(not spell.spell_name.is_empty() and not spell.description.is_empty(), label + ": named and explained technique")
				_check(spell.spell_range >= spell.minimum_range, label + ": legal range interval")
				_check(str(preview.get("details", "")).contains(spell.spell_name), label + ": technique inspectable")
	if seed_value == SEEDS[0]:
		var units: Array[Dictionary] = []
		for data: UnitData in room.enemies:
			units.append({"id": str(data.unit_id), "name": data.unit_name, "hp": data.max_hp,
				"ap": data.max_ap, "mp": data.max_mp, "prowess": data.attack_power,
				"spells": data.spells.map(func(spell: Spell): return str(spell.spell_id))})
		_encounters.append({"node": str(node.id), "depth": int(node.depth), "count": room.enemies.size(), "units": units})
	CLEANUP.dispose_grid(grid)


func _probe_route() -> void:
	var run := ExpeditionRunFactory.create(SEEDS[0], {"achilles": "painted_g"})
	var heroes = GameManager.resolve_run_hero_data(run, false)
	_check(heroes.is_valid(), "Route screen has a canonical hero")
	if not heroes.is_valid():
		return
	_check(GameManager._prepare_preconfigured_run(run, heroes.heroes), "Route screen services prepared")
	var session := ExpeditionSession.new()
	session.initialize(GameManager.get_character_state(&"achilles"), SEEDS[0])
	for depth in range(1, 18):
		var options := session.route.get_available_nodes()
		if options.is_empty():
			_check(false, "Route fixture reaches threshold 18")
			return
		_check(session.route.choose_node(str(options[0].id)), "Route fixture follows a real edge")
		if session.route.phase == "combat":
			session.route.mark_combat_won()
		session.route.complete_current_node()
	GameManager.expedition = session
	var screen := (load("res://ui/expedition/ExpeditionScreen.tscn") as PackedScene).instantiate() as ExpeditionScreen
	add_child(screen)
	await _settle()
	var view: Control = screen.get("_route_view")
	view.call("_on_destination_selected", "d18_0")
	var before := session.route.to_snapshot()
	await _settle()
	var panel := view.find_child("RouteEncounterPreview", true, false) as Control
	var commit := view.find_child("CommitDestination", true, false) as Button
	_check(panel.visible, "Known formation visible before route commitment")
	_check(not commit.disabled, "Inspection preserves access to route confirmation")
	_check(commit.get_global_rect().end.y <= _resolution.y, "Confirmation remains inside viewport")
	_check(panel.get_global_rect().end.y <= commit.get_global_rect().position.y, "Preview does not overlap confirmation")
	await _save_capture("route_before_choice")
	(view.find_child("InspectEncounter", true, false) as Button).pressed.emit()
	await _settle()
	var dialog := view.find_child("EncounterDetailsDialog", true, false) as AcceptDialog
	var details := view.find_child("EncounterTechniques", true, false) as RichTextLabel
	_check(dialog.visible and not details.text.is_empty(), "Techniques open from the route")
	_check(details.get_rect().size.y > 100, "Technique list has a readable viewport")
	_check(session.route.to_snapshot() == before, "Inspection never commits or rerolls a choice")
	await _save_capture("route_enemy_techniques")
	dialog.hide()
	screen.queue_free()
	await _settle(3)
	GameManager.cleanup_run_state()


func _probe_battle(node: Dictionary) -> void:
	var room := ExpeditionRunFactory.make_room(node, SEEDS[0])
	var run := ExpeditionRunFactory.create(SEEDS[0], {"achilles": "painted_g"})
	run.rooms = [room]
	var heroes = GameManager.resolve_run_hero_data(run, false)
	_check(heroes.is_valid(), str(node.id) + ": hero resolves")
	if not heroes.is_valid():
		return
	_check(GameManager._prepare_preconfigured_run(run, heroes.heroes), str(node.id) + ": combat prepared")
	var build := ExpeditionBuildState.new()
	_check(build.initialize(GameManager.get_character_state(&"achilles")), str(node.id) + ": legal hero kit")
	GameManager.current_room_index = 0
	var battle := room.battle_scene.instantiate()
	add_child(battle)
	var deadline := Time.get_ticks_msec() + 25000
	while not bool(battle.get("runtime_ready_state")) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(bool(battle.get("runtime_ready_state")), str(node.id) + ": battle ready")
	var grid := battle.get("grid") as GridData
	var terrain := battle.get("terrain_effects") as TerrainEffects
	if bool(battle.get("runtime_ready_state")):
		var occupied := {}
		var actual_count := 0
		var formation: Dictionary = battle.get("encounter_formation_snapshot")
		_check(bool(formation.get("valid", false)), str(node.id) + ": actual spawn plan valid")
		for unit: Unit in battle.get("units"):
			if unit.team == 0:
				continue
			actual_count += 1
			_check(not occupied.has(unit.grid_pos), str(node.id) + ": no overlapping enemies")
			_check(grid.is_walkable(unit.grid_pos, unit), str(node.id) + ": enemy stands on floor")
			occupied[unit.grid_pos] = true
			var view = battle.get("_unit_views").get(unit)
			_check(is_instance_valid(view), str(node.id) + ": visible unit view")
		_check(actual_count == room.enemies.size(), str(node.id) + ": full roster in real battle")
		_runtime_nodes.append(str(node.id))
		await _settle()
		await _save_capture("battle_" + str(node.id))
	# Dispose the RefCounted terrain graph before releasing the scene. This is
	# explicit in the probe as well as in Battle._exit_tree so the capture never
	# leaves CellSurfaceState objects alive until the process shuts down.
	if terrain != null and terrain.has_method("dispose"):
		terrain.dispose()
	CLEANUP.dispose_grid(grid)
	battle.queue_free()
	await _settle(6)
	grid = null
	terrain = null
	battle = null
	GameManager.cleanup_run_state()
	await _settle(3)


func _settle(frames := 6) -> void:
	for frame in frames:
		await get_tree().process_frame
	if _capture:
		await RenderingServer.frame_post_draw


func _save_capture(label: String) -> void:
	if not _capture:
		return
	await RenderingServer.frame_post_draw
	var screenshot := get_viewport().get_texture().get_image()
	_check(screenshot != null and not screenshot.is_empty(), label + ": GPU capture")
	if screenshot != null and not screenshot.is_empty():
		_check(screenshot.get_size() == _resolution, label + ": requested resolution")
		_check(screenshot.save_png(_output.path_join(label + ".png")) == OK, label + ": saved PNG")
		_captures.append(label)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_errors.append(label)


func _finish() -> void:
	_finished = true
	var report := {"passed": _errors.is_empty(), "checks": _checks, "errors": _errors,
		"captures": _captures, "encounters": _encounters, "runtime_nodes": _runtime_nodes,
		"formation_failures": _formation_failures,
		"data_only": "data_only" in OS.get_cmdline_user_args(), "resolution": [_resolution.x, _resolution.y],
		"scope": "Production rosters, placements, techniques, route knowledge and deployment; no full-run victory or balance claim."}
	var file := FileAccess.open(_output.path_join("report.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
	print("CATABASE_ENCOUNTER_EVOLUTION=%s checks=%d failures=%d captures=%d" % ["PASS" if _errors.is_empty() else "FAIL", _checks, _errors.size(), _captures.size()])
	for failure: String in _errors:
		push_error(failure)
	# Let the coroutine return and queued nodes finish freeing before quitting;
	# otherwise its local room/battle graphs are still roots at ObjectDB cleanup.
	call_deferred("_quit_after_probe_cleanup", 0 if _errors.is_empty() else 1)


func _quit_after_probe_cleanup(exit_code: int) -> void:
	GameManager.cleanup_run_state()
	await _settle(3)
	get_tree().quit(exit_code)
