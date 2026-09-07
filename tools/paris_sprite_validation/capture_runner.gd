extends Node

const CASES := preload("res://tools/paris_sprite_validation/cases.gd")
const PROBE := preload("res://tools/paris_sprite_validation/combat_probe.gd")


func _ready() -> void:
	_launch.call_deferred()


func _launch() -> void:
	var configuration := {"scenario": "ice", "direction": "E",
		"room_path": "res://data/arenas/silent_judgment_courtyard_v1/arena.tres"}
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
		_fail(probe, "canonical_room_not_an_arena")
		return
	var arena := ArenaRuntimeBridge.build_runtime_projection(source)
	if arena == null or arena.painted_map_visual_data == null:
		_fail(probe, "arena_projection_failed")
		return
	probe.placement = CASES.configure(arena, configuration.scenario, configuration.direction)
	if not bool(probe.placement.get("ok", false)):
		_fail(probe, str(probe.placement.get("error", "placement_failed")))
		return
	var production := load("res://data/runs/odyssey.tres") as RunData
	var run := production.duplicate(false) as RunData
	run.run_name = "Paris production combat validation"
	run.default_seed = 9062026
	run.randomize_seed_each_run = false
	run.rooms = [arena]
	run.hub_room_selection_enabled = false
	configuration["action_classification_catalog"] = run.action_classification_catalog.resource_path
	var resolution := RunHeroResolver.resolve_runtime_hero_data(run, false)
	if not resolution.is_valid():
		_fail(probe, "canonical_hero_resolution_failed")
		return
	var options := ArenaDirectTestConfiguration.resolve(&"real_encounter")
	options["camera_mode"] = "PRODUCTION"
	if not GameManager.start_direct_encounter_test(run, resolution.heroes, options):
		_fail(probe, "direct_combat_launch_failed")
		return
	probe.progression = CASES.prepare_progression(configuration.scenario)
	if not bool(probe.progression.get("ok", false)):
		_fail(probe, "progression_fixture_failed")


func _fail(probe: Node, reason: String) -> void:
	(probe.get("_errors") as Array).append(reason)
	probe._finish({"launch_failed": true})
