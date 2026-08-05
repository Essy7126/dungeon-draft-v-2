extends Node

const REQUEST_PATH := "user://arena_studio/test_request.json"
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
	get_tree().set_meta("arena_studio_test_configuration", configuration)
	run.run_name = "Test Arena Studio [%s] — %s" % [configuration, arena.display_name]
	run.rooms = [arena]
	run.default_seed = 1337
	var heroes: Array = request.get("heroes", DEFAULT_HEROES)
	if heroes.any(func(path): return not ResourceLoader.exists(str(path))):
		heroes = DEFAULT_HEROES
	print("ARENA_STUDIO_DIRECT_TEST configuration=%s arena=%s" % [configuration, arena.arena_id])
	var game_manager := get_node_or_null("/root/GameManager")
	if game_manager == null:
		push_error("Arena Studio : l'autoload GameManager est introuvable.")
		get_tree().quit(3)
		return
	game_manager.start_preconfigured_run(run, heroes)
	# Le bouton de l'editeur promet un test de la map seule : l'etat de run est
	# construit par GameManager, puis la salle courante entre directement dans
	# la vraie scene de bataille peinte, sans clic dans l'ecran de transition.
	game_manager.start_next_battle()


func _load_request() -> Dictionary:
	if not FileAccess.file_exists(REQUEST_PATH):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(REQUEST_PATH))
	return parsed if parsed is Dictionary else {}
