extends Node

const FIXTURE := "res://artifacts/studio_1_2/production_fixture/arena.tres"
const RESULT := "res://artifacts/studio_1_2/modular_runtime_smoke.json"
const REQUEST := "user://arena_studio/test_request.json"
const TEST_RUNNER := preload(
	"res://addons/dungeon_draft_arena_studio/test/arena_studio_test_runner.tscn"
)
const MODULAR_SCRIPT := "res://battle/modular/modular_battle.gd"


func _ready() -> void:
	get_tree().current_scene = null
	call_deferred("_run")


func _run() -> void:
	var arena := ResourceLoader.load(FIXTURE, "", ResourceLoader.CACHE_MODE_IGNORE) as ArenaDefinition
	if arena == null:
		_finish(false, {"error": "produced_fixture_missing"})
		return
	var file := FileAccess.open(REQUEST, FileAccess.WRITE)
	if file == null:
		_finish(false, {"error": "request_write_failed"})
		return
	file.store_string(JSON.stringify({
		"arena_path": FIXTURE,
		"configuration": "full_run",
		"heroes": [
			"res://data/units/alliés/elfe.tres",
			"res://data/units/alliés/mage.tres",
			"res://data/units/alliés/Guerrier.tres",
		],
	}, "  "))
	file.close()
	add_child(TEST_RUNNER.instantiate())
	for _frame in range(300):
		await get_tree().process_frame
		var scene := get_tree().current_scene
		if scene == null or scene.get_script() == null \
				or scene.get_script().resource_path != MODULAR_SCRIPT:
			continue
		for _settle in range(16):
			await get_tree().process_frame
		var grid := scene.get("grid") as GridData
		var pathfinder := scene.get("pathfinder") as Pathfinder
		var manager := get_tree().root.get_node_or_null("GameManager")
		var room := manager.get_current_room() as ArenaDefinition if manager != null else null
		var renderer := scene.find_child("ArenaFeatureRenderer", true, false)
		var dynamic_wall := scene.find_child("DynamicWall*", true, false)
		var ok := grid != null and pathfinder != null and room != null \
			and room.arena_id == arena.arena_id and scene.has_node("IsoGridView") \
			and scene.has_node("YSortedWorld") and renderer != null \
			and dynamic_wall != null
		var details := {
			"scene": scene.scene_file_path,
			"script": scene.get_script().resource_path,
			"arena_id": str(room.arena_id) if room != null else "",
			"grid_size": [grid.cols, grid.rows] if grid != null else [],
			"pathfinder": pathfinder != null,
			"shared_renderer": renderer != null,
			"dynamic_wall": dynamic_wall != null,
			"y_sorted_world": scene.has_node("YSortedWorld"),
		}
		if manager != null:
			manager.cleanup_run_state()
		get_tree().current_scene = null
		scene.queue_free()
		for _cleanup in range(4):
			await get_tree().process_frame
		_finish(ok, details)
		return
	_finish(false, {"error": "modular_battle_timeout"})


func _finish(ok: bool, details: Dictionary) -> void:
	details["ok"] = ok
	var file := FileAccess.open(RESULT, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(details, "  "))
		file.close()
	print("STUDIO_V12_MODULAR_RUNTIME_SMOKE ", JSON.stringify(details))
	get_tree().quit(0 if ok else 1)
