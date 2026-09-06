extends Node

const CASES := preload("res://tools/philosopher_sprite_validation/terrain_cases.gd")
const PROBE := preload("res://tools/philosopher_sprite_validation/terrain_probe.gd")


func _ready() -> void:
	_launch.call_deferred()


func _launch() -> void:
	var configuration := {"scenario": "push_lava", "direction": "E",
		"room_path": "res://data/arenas/greek_drawn_courtyard_v1/arena.tres", "seed": "9062026"}
	for argument: String in OS.get_cmdline_user_args():
		for key: String in configuration:
			var prefix := "--%s=" % key.replace("_", "-")
			if argument.begins_with(prefix):
				configuration[key] = argument.trim_prefix(prefix)
	configuration.direction = str(configuration.direction).to_upper()
	var probe := PROBE.new()
	probe.configuration = configuration
	get_tree().root.add_child(probe)
	var source := load(str(configuration.room_path)) as ArenaDefinition
	if source == null:
		_fail(probe, "canonical_arena_missing")
		return
	var source_fingerprint: String = RoomDataSnapshotService.room_fingerprint(source)
	var arena := source.duplicate(true) as ArenaDefinition
	var detached_cells := 0
	# Resource.duplicate and Array.duplicate do not share identical deep-copy
	# contracts. Explicitly detach any source cell still shared by this copy.
	for index in arena.cells.size():
		var cell: ArenaCellDefinition = arena.cells[index]
		if cell != null and cell == source.get_cell_definition(cell.coordinate):
			arena.cells[index] = cell.duplicate(true) as ArenaCellDefinition
			detached_cells += 1
	arena.invalidate_cell_index()
	if not ArenaRuntimeBridge.sync_runtime_resources(arena):
		_fail(probe, "arena_projection_failed")
		return
	probe.placement = CASES.configure(arena, configuration.scenario, configuration.direction)
	if not bool(probe.placement.get("ok", false)):
		_fail(probe, str(probe.placement.get("error", "placement_failed")))
		return
	if RoomDataSnapshotService.room_fingerprint(source) != source_fingerprint:
		_fail(probe, "terrain_fixture_mutated_cached_source_resource")
		return
	probe.placement["source_memory_unchanged"] = true
	probe.placement["source_shared_cells_detached"] = detached_cells
	probe.placement["source_fingerprint"] = source_fingerprint
	var run := RunData.new()
	run.run_name = "Philosopher actual combat and canonical terrain validation"
	run.default_seed = int(configuration.seed)
	run.randomize_seed_each_run = false
	run.rooms = [arena]
	run.hub_room_selection_enabled = false
	run.content_profile = load("res://data/runs/profiles/odyssey_content_profile.tres") as RunContentProfile
	var production := load("res://data/runs/philosopher_trial.tres") as RunData
	if production == null or production.action_classification_catalog == null:
		_fail(probe, "production_classification_catalog_missing")
		return
	run.action_classification_catalog = production.action_classification_catalog
	configuration.action_classification_catalog = run.action_classification_catalog.resource_path
	var resolution := RunHeroResolver.resolve_runtime_hero_data(run, false)
	if not resolution.is_valid():
		_fail(probe, "canonical_hero_resolution_failed")
		return
	var options := ArenaDirectTestConfiguration.resolve(&"real_encounter")
	options.camera_mode = "PRODUCTION"
	probe.progression = {"ok": true, "level": 1, "scope": "Unmodified starting Achilles; no XP fixture or purchased attributes."}
	if not GameManager.start_direct_encounter_test(run, resolution.heroes, options):
		_fail(probe, "direct_combat_launch_failed")


func _fail(probe: Node, reason: String) -> void:
	(probe.get("_errors") as Array).append(reason)
	probe._finish({"launch_failed": true})
