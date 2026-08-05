extends Node

const FIXTURE := "res://artifacts/arena_studio/tests/direct_test_arena.tres"
const RESULT := "res://artifacts/arena_studio/tests/runtime_smoke.json"
const REQUEST := "user://arena_studio/test_request.json"
const TEST_RUNNER := preload(
	"res://addons/dungeon_draft_arena_studio/test/arena_studio_test_runner.tscn"
)
const PAINTED_BATTLE_SCRIPT := "res://battle/painted/painted_battle.gd"
const HEROES := [
	"res://data/units/alliés/elfe.tres",
	"res://data/units/alliés/mage.tres",
	"res://data/units/alliés/Guerrier.tres",
]



func _ready() -> void:
	# Le smoke doit survivre au changement de scene qu'il observe.
	get_tree().current_scene = null
	call_deferred("_run")


func _run() -> void:
	var arena := ArenaLegacyImporter.import_production(&"room_01_forest")
	if arena == null:
		_finish(false, {"error": "legacy_import_failed"})
		return
	ArenaEditingService.apply_safety_border(arena, 1)
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	var fixture_absolute := ProjectSettings.globalize_path(FIXTURE)
	DirAccess.make_dir_recursive_absolute(fixture_absolute.get_base_dir())
	var save_error := ResourceSaver.save(arena, FIXTURE)
	if save_error != OK:
		_finish(false, {"error": error_string(save_error)})
		return
	var request_absolute := ProjectSettings.globalize_path(REQUEST)
	DirAccess.make_dir_recursive_absolute(request_absolute.get_base_dir())
	var request_file := FileAccess.open(REQUEST, FileAccess.WRITE)
	if request_file == null:
		_finish(false, {"error": "request_write_failed"})
		return
	request_file.store_string(JSON.stringify({
		"arena_path": FIXTURE,
		"configuration": "full_run",
		"heroes": HEROES,
	}, "  "))
	request_file.close()
	add_child(TEST_RUNNER.instantiate())
	for _frame in range(240):
		await get_tree().process_frame
		var scene := get_tree().current_scene
		if scene == null or scene.get_script() == null:
			continue
		if scene.get_script().resource_path != PAINTED_BATTLE_SCRIPT:
			continue
		for _settle in range(12):
			await get_tree().process_frame
		var grid := scene.get("grid") as GridData
		var pathfinder := scene.get("pathfinder") as Pathfinder
		var game_manager := get_tree().root.get_node_or_null("GameManager")
		var room = game_manager.get_current_room() if game_manager != null else null
		var loaded_arena := room as ArenaDefinition
		var ok := (
			grid != null
			and pathfinder != null
			and loaded_arena != null
			and loaded_arena.arena_id == arena.arena_id
			and scene.has_node("IsoGridView")
			and scene.has_node("YSortedWorld")
		)
		var details := {
			"scene": scene.scene_file_path,
			"script": scene.get_script().resource_path,
			"grid_size": [grid.cols, grid.rows] if grid != null else [],
			"pathfinder_ready": pathfinder != null,
			"room_id": str(loaded_arena.arena_id) if loaded_arena != null else "",
			"configuration": str(get_tree().get_meta("arena_studio_test_configuration", "")),
			"iso_grid_view": scene.has_node("IsoGridView"),
			"y_sorted_world": scene.has_node("YSortedWorld"),
		}
		if game_manager != null:
			game_manager.cleanup_run_state()
		get_tree().current_scene = null
		scene.queue_free()
		for _cleanup in range(4):
			await get_tree().process_frame
		_finish(ok, details)
		return
	_finish(false, {"error": "painted_battle_timeout"})


func _finish(ok: bool, details: Dictionary) -> void:
	details["ok"] = ok
	var absolute := ProjectSettings.globalize_path(RESULT)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var file := FileAccess.open(RESULT, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(details, "  "))
		file.close()
	print("ARENA_STUDIO_RUNTIME_SMOKE ", JSON.stringify(details))
	get_tree().quit(0 if ok else 1)
