extends Node

const REQUEST_PATH := "user://arena_studio/test_request.json"
const DirectTestConfiguration = preload(
	"res://addons/dungeon_draft_arena_studio/services/arena_direct_test_configuration.gd"
)
const DEFAULT_HEROES := [
	"res://data/units/alliés/elfe.tres",
	"res://data/units/alliés/mage.tres",
	"res://data/units/alliés/Guerrier.tres",
]


func _ready() -> void:
	var request := _load_request()
	var arena_path := str(request.get("arena_path", ""))
	var arena := load(arena_path) as ArenaDefinition if ResourceLoader.exists(arena_path) else null
	if arena == null:
		push_error("Arena Studio : la ressource de test est introuvable.")
		get_tree().quit(1)
		return
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	var report := ArenaValidator.validate(arena, false)
	if not report.is_valid():
		push_error("Arena Studio : la map de test n'est pas valide.")
		get_tree().quit(2)
		return
	var run := RunData.new()
	var configuration := StringName(request.get("configuration", "movement"))
	var test_options := DirectTestConfiguration.resolve(configuration)
	get_tree().set_meta("arena_studio_test_configuration", configuration)
	get_tree().set_meta(DirectTestConfiguration.TREE_META, test_options)
	run.run_name = "Test Arena Studio [%s] — %s" % [configuration, arena.display_name]
	run.rooms = [arena]
	run.default_seed = 1337
	var heroes: Array = request.get("heroes", DEFAULT_HEROES)
	if not bool(test_options.get("spawn_heroes", false)):
		heroes = []
	if heroes.any(func(path): return not ResourceLoader.exists(str(path))):
		heroes = DEFAULT_HEROES
	print("ARENA_STUDIO_DIRECT_TEST configuration=%s applied=%s arena=%s" % [
		configuration, test_options.get("applied_mode", "unknown"), arena.arena_id,
	])
	var game_manager := get_node_or_null("/root/GameManager")
	if game_manager == null:
		push_error("Arena Studio : l'autoload GameManager est introuvable.")
		get_tree().quit(3)
		return
	var started: bool = game_manager.start_direct_encounter_test(
		run, heroes, test_options
	)
	_write_launch_result(request, started, arena)
	if not started:
		push_error("Arena Studio : le lancement direct a ete refuse par GameManager.")
		get_tree().quit(4)
		return
	_cleanup_temporary_request(request)


func _load_request() -> Dictionary:
	if not FileAccess.file_exists(REQUEST_PATH):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(REQUEST_PATH))
	return parsed if parsed is Dictionary else {}


func _write_launch_result(request: Dictionary, started: bool, arena: ArenaDefinition) -> void:
	var result_path := str(request.get("result_path", ""))
	if result_path.is_empty():
		return
	var absolute := ProjectSettings.globalize_path(result_path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var file := FileAccess.open(result_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({
			"ok": started,
			"arena_id": str(arena.arena_id),
			"configuration": str(request.get("configuration", "")),
			"applied_mode": str(get_tree().get_meta(
				DirectTestConfiguration.TREE_META, {}
			).get("applied_mode", "")),
			"working_copy": true,
		}, "  "))
		file.close()


func _cleanup_temporary_request(request: Dictionary) -> void:
	if not bool(request.get("cleanup_on_load", false)):
		return
	var arena_path := str(request.get("arena_path", ""))
	if arena_path.begins_with("user://dungeon_draft_studio/arena_studio/tests/"):
		var absolute := ProjectSettings.globalize_path(arena_path)
		if FileAccess.file_exists(absolute):
			DirAccess.remove_absolute(absolute)
	var request_absolute := ProjectSettings.globalize_path(REQUEST_PATH)
	if FileAccess.file_exists(request_absolute):
		DirAccess.remove_absolute(request_absolute)
