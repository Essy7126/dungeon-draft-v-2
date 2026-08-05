extends Node

const RESULT_PATH := "res://artifacts/encounter_studio/test_direct_runtime_smoke.json"
const RUN_PATH := "res://data/runs/first_run.tres"

var request := {}
var canonical_snapshot := {}


func _ready() -> void:
	get_tree().current_scene = null
	call_deferred("_run")


func _run() -> void:
	var source_run := ResourceLoader.load(
		RUN_PATH, "", ResourceLoader.CACHE_MODE_IGNORE
	) as RunData
	var session := EncounterEditSession.new()
	if source_run == null or not session.open(source_run, RUN_PATH):
		_finish(false, {"error": "run_open_failed"})
		return
	canonical_snapshot = EncounterCopyService.encounter_snapshot(
		source_run.rooms[0].get_encounter_for_wave(0)
	)
	var prepared := EncounterTestLauncher.prepare_and_launch(session, null, 424242)
	request = prepared.get("request", {})
	if prepared.get("error", "") != "editor_play_api_missing" or request.is_empty():
		_finish(false, {"error": "temporary_context_failed", "details": prepared})
		return
	var bootstrap := preload(
		"res://addons/dungeon_draft_arena_studio/encounter/runtime/EncounterStudioTestBootstrap.tscn"
	).instantiate()
	get_tree().root.add_child(bootstrap)
	for _frame in range(360):
		await get_tree().process_frame
		var battle := get_tree().current_scene
		if battle == null or battle.get("grid") == null:
			continue
		for _settle in range(12):
			await get_tree().process_frame
		var current_room := GameManager.get_current_room()
		var current_encounter := GameManager.get_current_encounter_definition()
		var formation = battle.get("encounter_formation_snapshot")
		var source_run_check := ResourceLoader.load(
			RUN_PATH, "", ResourceLoader.CACHE_MODE_IGNORE
		) as RunData
		var canonical_untouched := EncounterCopyService.encounter_snapshot(
			source_run_check.rooms[0].get_encounter_for_wave(0)
		) == canonical_snapshot
		var details := {
			"scene": battle.scene_file_path,
			"grid": [battle.grid.cols, battle.grid.rows],
			"run_seed": GameManager.get_run_seed(),
			"temporary_room": current_room.resource_path if current_room != null else "",
			"temporary_encounter": current_encounter.resource_path \
				if current_encounter != null else "",
			"formation_valid": formation is Dictionary and formation.get("valid", false),
			"canonical_untouched": canonical_untouched,
			"game_manager_active": GameManager.run_active,
		}
		var ok := current_room != null and current_encounter != null \
			and str(current_room.resource_path).begins_with(EncounterTestLauncher.ROOT) \
			and int(details.run_seed) == 424242 \
			and bool(details.formation_valid) and canonical_untouched
		get_tree().current_scene = null
		battle.queue_free()
		_finish(ok, details)
		return
	_finish(false, {"error": "battle_timeout"})


func _finish(ok: bool, details: Dictionary) -> void:
	GameManager.cleanup_run_state()
	for child in get_tree().root.get_children():
		if child is EncounterStudioDebugBridge:
			child.queue_free()
	if not request.is_empty():
		EncounterTestLauncher.cleanup_context(request)
	details["ok"] = ok
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(RESULT_PATH.get_base_dir())
	)
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(details, "  "))
	print("ENCOUNTER_STUDIO_RUNTIME_SMOKE ", JSON.stringify(details))
	get_tree().quit(0 if ok else 1)
