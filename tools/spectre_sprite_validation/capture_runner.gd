extends Node

const PROBE := preload("res://tools/spectre_sprite_validation/courtyard_spectre_probe.gd")


func _ready() -> void:
	_launch.call_deferred()


func _launch() -> void:
	var requested_room_path := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--room-path="):
			requested_room_path = argument.trim_prefix("--room-path=")
	var probe := PROBE.new()
	probe.requested_room_path = requested_room_path
	get_tree().root.add_child(probe)
	if requested_room_path.is_empty():
		get_tree().change_scene_to_file("res://tools/labs/greek_drawn_arena/GreekDrawnCourtyard.tscn")
		return
	_launch_requested_room(requested_room_path, probe)


func _launch_requested_room(room_path: String, probe: Node) -> void:
	var source := load(room_path) as ArenaDefinition
	if source == null:
		_fail_launch(probe, "requested_room_is_not_an_arena_definition")
		return
	# Work on the same runtime projection used by registered-terrain tools.
	# The cached production resource, encounter, roster and scene are not saved
	# or replaced. The supplied room retains its own production battle scene.
	var arena := source.duplicate(true) as ArenaDefinition
	if not ArenaRuntimeBridge.sync_runtime_resources(arena):
		_fail_launch(probe, "requested_room_runtime_projection_failed")
		return
	if arena.battle_scene == null or source.battle_scene == null \
			or arena.battle_scene.resource_path != source.battle_scene.resource_path:
		_fail_launch(probe, "requested_room_battle_scene_changed_or_missing")
		return
	var validation := ArenaValidator.validate(arena, false)
	var errors: Array[String] = []
	for message in validation.messages:
		if message.severity == ArenaValidationMessage.Severity.ERROR:
			errors.append("%s: %s" % [message.code, message.message])
	if not errors.is_empty():
		_fail_launch(probe, "requested_room_validation_failed:%s" % str(errors))
		return
	var run := RunData.new()
	run.run_name = "Spectre validation - " + source.room_name
	run.default_seed = 9052026
	run.randomize_seed_each_run = false
	run.rooms = [arena]
	run.hub_room_selection_enabled = false
	run.content_profile = load("res://data/runs/profiles/odyssey_content_profile.tres") as RunContentProfile
	var hero_resolution := RunHeroResolver.resolve_runtime_hero_data(run, false)
	if not hero_resolution.is_valid():
		_fail_launch(probe, "canonical_hero_resolution_failed:%s" % str(hero_resolution.errors))
		return
	var options := ArenaDirectTestConfiguration.resolve(&"real_encounter")
	options["camera_mode"] = "PRODUCTION"
	if not GameManager.start_direct_encounter_test(run, hero_resolution.heroes, options):
		_fail_launch(probe, "production_direct_encounter_launch_refused")


func _fail_launch(probe: Node, reason: String) -> void:
	(probe.get("_errors") as Array).append(reason)
	probe._finish({"requested_room_path": probe.requested_room_path, "launch_failed": true})