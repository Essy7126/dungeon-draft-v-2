extends Node

const CASES := preload("res://tools/achilles_kit_sprite_validation/kit_cases.gd")
const PROBE := preload("res://tools/achilles_kit_sprite_validation/kit_sprite_probe.gd")


func _ready() -> void:
	_launch.call_deferred()


func _launch() -> void:
	var configuration := {"kit": "base", "scenario": "", "direction": "E",
		"room_path": "res://data/arenas/greek_drawn_courtyard_v1/arena.tres"}
	for argument: String in OS.get_cmdline_user_args():
		for key: String in ["kit", "scenario", "direction", "room_path"]:
			var prefix := "--%s=" % key.replace("_", "-")
			if argument.begins_with(prefix):
				configuration[key] = argument.trim_prefix(prefix)
	var probe := PROBE.new()
	probe.configuration = configuration
	get_tree().root.add_child(probe)
	if not CASES.KITS.has(configuration.kit):
		_fail(probe, "unknown_kit")
		return
	if str(configuration.scenario).is_empty():
		configuration.scenario = CASES.KITS[configuration.kit].scenario
	configuration.direction = str(configuration.direction).to_upper()
	var source := load(str(configuration.room_path)) as ArenaDefinition
	if source == null:
		_fail(probe, "room_not_an_arena_definition")
		return
	var arena := source.duplicate(true) as ArenaDefinition
	if not ArenaRuntimeBridge.sync_runtime_resources(arena):
		_fail(probe, "arena_projection_failed")
		return
	var placement := CASES.configure_placement_fixture(arena, configuration.scenario,
		configuration.kit, configuration.direction)
	probe.placement = placement
	if not bool(placement.get("ok", false)):
		_fail(probe, str(placement.get("error", "placement_fixture_failed")))
		return
	var run := RunData.new()
	run.run_name = "Achilles sprite kit validation"
	run.default_seed = 9052026
	run.randomize_seed_each_run = false
	run.rooms = [arena]
	run.hub_room_selection_enabled = false
	run.content_profile = load("res://data/runs/profiles/odyssey_content_profile.tres") as RunContentProfile
	var resolution := RunHeroResolver.resolve_runtime_hero_data(run, false)
	if not resolution.is_valid():
		_fail(probe, "canonical_hero_resolution_failed")
		return
	var options := ArenaDirectTestConfiguration.resolve(&"real_encounter")
	options["camera_mode"] = "PRODUCTION"
	if not GameManager.start_direct_encounter_test(run, resolution.heroes, options):
		_fail(probe, "direct_combat_launch_failed")
		return
	# Battle is deferred. Purchase through the normal manager while the real
	# run state is initialized and its combat tracker has not started yet.
	probe.progression = CASES.prepare_progression(configuration.kit)
	if not bool(probe.progression.get("ok", false)):
		_fail(probe, str(probe.progression.get("error", "progression_fixture_failed")))


func _fail(probe: Node, reason: String) -> void:
	(probe.get("_errors") as Array).append(reason)
	probe._finish({"launch_failed": true})
