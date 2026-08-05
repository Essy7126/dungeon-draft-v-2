extends Node

const REQUEST_PATH := "user://dungeon_draft_studio/encounter_studio/tests/active_request.json"


func _ready() -> void:
	var request := _load_request()
	var run_path := str(request.get("run_path", ""))
	var run := ResourceLoader.load(run_path, "", ResourceLoader.CACHE_MODE_IGNORE) \
		as RunData if not run_path.is_empty() else null
	if run == null:
		push_error("Encounter Studio : contexte temporaire introuvable.")
		EncounterTestLauncher.cleanup_context(request)
		get_tree().quit(1)
		return
	var bridge := EncounterStudioDebugBridge.new()
	bridge.configure(request)
	get_tree().root.add_child.call_deferred(bridge)
	var heroes: Array = request.get("heroes", EncounterTestLauncher.DEFAULT_HEROES)
	GameManager.cleanup_run_state()
	if not GameManager.start_direct_encounter_test(run, heroes):
		push_error("Encounter Studio : lancement du vrai runtime impossible.")
		EncounterTestLauncher.cleanup_context(request)
		get_tree().quit(2)


func _load_request() -> Dictionary:
	if not FileAccess.file_exists(REQUEST_PATH):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(REQUEST_PATH))
	return parsed if parsed is Dictionary else {}
