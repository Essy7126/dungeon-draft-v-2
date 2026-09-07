extends Node
## Spawn/deployment and registered-renderer probe for all ten expansion maps.
## Optional user argument capture=true writes real viewport PNGs (GPU required).

const CATALOG := preload("res://core/expedition/expedition_map_catalog.gd")
var _checks := 0
var _errors: Array[String] = []
var _capture := false


func _ready() -> void:
	_capture = "capture=true" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/catabase_maps/runtime"))
	for index in range(5, 15):
		var arena := CATALOG.get_room(index) as ArenaDefinition
		var run := (load("res://data/runs/odyssey.tres") as RunData).duplicate(false) as RunData
		run.rooms = [arena]
		run.default_seed = 2401
		run.randomize_seed_each_run = false
		GameManager._prepare_preconfigured_run(run, [load("res://data/units/allies/achilles.tres")])
		var build := ExpeditionBuildState.new()
		_check(build.initialize(GameManager.get_character_state(&"achilles")), str(arena.arena_id) + " canonical kit initialized")
		_check(GameManager.heroes[0].spells.size() == 4, str(arena.arena_id) + " canonical four base spells")
		GameManager.current_room_index = 0
		GameManager.set_reduced_motion_enabled(true)
		var battle := arena.battle_scene.instantiate()
		add_child(battle)
		var start := Time.get_ticks_msec()
		while not bool(battle.get("runtime_ready_state")) and Time.get_ticks_msec() - start < 20000:
			await get_tree().process_frame
		_check(bool(battle.get("runtime_ready_state")), str(arena.arena_id) + " battle ready")
		_check(bool(battle.get("registered_terrain_ready")), str(arena.arena_id) + " registered terrain ready")
		_check(int(battle.get("registered_floor_tile_count")) == arena.cells.size(), str(arena.arena_id) + " complete floor renderer")
		var grid := battle.get("grid") as GridData
		var units: Array = battle.get("units")
		var enemy_count := 0
		var occupied := {}
		for unit: Unit in units:
			if unit.team == 0: continue
			enemy_count += 1
			_check(not occupied.has(unit.grid_pos), str(arena.arena_id) + " enemy has own cell")
			_check(grid.is_walkable(unit.grid_pos, unit), str(arena.arena_id) + " enemy on legal floor")
			_check(arena.enemy_spawn_zone.has(unit.grid_pos), str(arena.arena_id) + " enemy on authored spawn")
			occupied[unit.grid_pos] = true
		_check(enemy_count == arena.enemies.size(), str(arena.arena_id) + " complete roster spawned")
		var deployment = battle.get("_deployment")
		_check(deployment != null and deployment.is_active(), str(arena.arena_id) + " player chooses deployment")
		if deployment != null and deployment.is_active():
			deployment.on_cell_clicked(arena.hero_spawn_zone[0])
		for frame in 6: await get_tree().process_frame
		_check(GameManager.heroes[0].grid_pos == arena.hero_spawn_zone[0], str(arena.arena_id) + " Achilles deployed legally")
		var actual_renderer = battle.get("arena_assembly").get("renderer")
		if actual_renderer != null:
			var actual: Dictionary = actual_renderer.actual_render_report()
			_check(actual.errors.is_empty(), str(arena.arena_id) + " rendered topology valid")
			_check(actual.cells.size() == arena.cells.size(), str(arena.arena_id) + " no missing floor node")
		if _capture:
			await get_tree().create_timer(2.0).timeout
			await RenderingServer.frame_post_draw
			var image := get_viewport().get_texture().get_image()
			_check(image != null and not image.is_empty(), str(arena.arena_id) + " GPU image")
			if image != null:
				image.save_png(ProjectSettings.globalize_path("res://artifacts/catabase_maps/runtime/%02d_%s.png" % [index + 1, arena.arena_id]))
		print("Catabase runtime map %d: %s floor=%d enemies=%d" % [index + 1, arena.room_name, arena.cells.size(), enemy_count])
		battle.queue_free()
		for frame in 4: await get_tree().process_frame
		GameManager.cleanup_run_state()
		for frame in 2: await get_tree().process_frame
	print("Catabase map runtime: %d checks, %d failures, capture=%s" % [_checks, _errors.size(), _capture])
	for failure in _errors: push_error(failure)
	get_tree().quit(0 if _errors.is_empty() else 1)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition: _errors.append(label)
