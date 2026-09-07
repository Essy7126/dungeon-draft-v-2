extends Node

const ARENA_PATH := "res://data/arenas/greek_drawn_courtyard_v1/arena.tres"
const PROBE := preload("res://tools/labs/greek_drawn_arena/greek_runtime_probe.gd")

func _ready() -> void:
	call_deferred("_launch")

func _launch() -> void:
	var source_arena := ResourceLoader.load(ARENA_PATH) as ArenaDefinition
	var arena := source_arena.duplicate(true) as ArenaDefinition if source_arena != null else null
	if arena != null:
		# Only this deep copy retains the historical lab scene/probe identity.
		# The canonical production arena and its cached resource stay untouched.
		arena.battle_scene = load("res://tools/labs/greek_drawn_arena/GreekDrawnBattle.tscn") as PackedScene
	if arena == null or not ArenaRuntimeBridge.sync_runtime_resources(arena):
		push_error("Greek courtyard: arena resource could not be loaded.")
		get_tree().quit(1)
		return
	var report := ArenaValidator.validate(arena, false)
	var errors: Array[String] = []
	for message in report.messages:
		if message.severity == ArenaValidationMessage.Severity.ERROR:
			errors.append("%s: %s" % [message.code, message.message])
	if not errors.is_empty():
		push_error("Greek courtyard validation: %s" % str(errors))
		get_tree().quit(2)
		return
	var args := OS.get_cmdline_user_args()
	if args.has("--capture") or args.has("--verify"):
		var probe := PROBE.new()
		probe.capture_enabled = args.has("--capture")
		probe.quit_after_capture = args.has("--capture-quit") or args.has("--verify")
		get_tree().root.add_child(probe)
	var run := RunData.new()
	run.run_name = "La Cour des Sources — atelier grec"
	run.default_seed = 9052026
	run.randomize_seed_each_run = false
	run.rooms = [arena]
	run.hub_room_selection_enabled = false
	run.content_profile = load("res://data/runs/profiles/odyssey_content_profile.tres") as RunContentProfile
	var hero_resolution := RunHeroResolver.resolve_runtime_hero_data(run, false)
	if not hero_resolution.is_valid():
		push_error("Greek courtyard: canonical Achilles content could not resolve: %s" % str(hero_resolution.errors))
		get_tree().quit(4)
		return
	var options := ArenaDirectTestConfiguration.resolve(&"real_encounter")
	options["camera_mode"] = "PRODUCTION"
	if not GameManager.start_direct_encounter_test(
		run, hero_resolution.heroes, options
	):
		push_error("Greek courtyard: production battle launch was refused.")
		get_tree().quit(3)


