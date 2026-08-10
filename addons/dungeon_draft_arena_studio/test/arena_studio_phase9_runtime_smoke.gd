extends Node

const TEST_RUNNER := preload(
	"res://addons/dungeon_draft_arena_studio/test/arena_studio_test_runner.tscn"
)
const FOREST_PATH := "res://data/arenas/room_01_forest.tres"
const MAIN_RUN_PATH := "res://data/runs/first_run.tres"


func _ready() -> void:
	get_tree().current_scene = null
	call_deferred("_run")


func _run() -> void:
	var previous_result := ProjectSettings.globalize_path(
		ArenaDirectTestService.LAST_RESULT_PATH
	)
	if FileAccess.file_exists(previous_result):
		DirAccess.remove_absolute(previous_result)
	var source := ArenaLegacyImporter.import_production(&"room_01_forest")
	var run := load(MAIN_RUN_PATH) as RunData
	var session := ArenaEditSession.new()
	if source == null or run == null \
			or not session.open(source, FOREST_PATH, false, "phase9_runtime_smoke"):
		_finish(false, {"error": "fixture_load_failed"})
		return
	var arena := session.working_arena
	ArenaEditingService.prepare_automatically(arena)
	arena.visual_mode = ArenaDefinition.VisualMode.HYBRID
	arena.modular_visual_profile = ArenaModularVisualProfile.new()
	arena.modular_visual_profile.theme_id = arena.theme_id
	arena.modular_visual_profile.base_terrain_id = &"stone"
	arena.modular_visual_profile.hybrid_floor_policy = (
		ArenaModularVisualProfile.HybridFloorPolicy.ALL_DEFINED
	)
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	var prepared := ArenaDirectTestService.prepare(arena, run, &"real_encounter")
	if not bool(prepared.get("ok", false)):
		_finish(false, prepared)
		return
	add_child(TEST_RUNNER.instantiate())
	for _frame in range(480):
		await get_tree().process_frame
		var result := ArenaDirectTestService.load_last_result()
		if not bool(result.get("runtime_scene_inspected", false)):
			continue
		var ok := bool(result.get("ok", false)) \
			and bool(result.get("fingerprints_identical", false)) \
			and bool(result.get("configuration_consumed", false)) \
			and str(result.get("camera_mode", "")) == "STUDIO_MATCH" \
			and int(result.get("floor_layer_count", 0)) == 1 \
			and int(result.get("floor_renderer_count", 0)) == 1 \
			and int(result.get("duplicate_tile_count", -1)) == 0 \
			and int(result.get("misplaced_floor_node_count", -1)) == 0 \
			and not bool(result.get("produced_bundle_loaded", true))
		var manager := get_tree().root.get_node_or_null("GameManager")
		if manager != null:
			manager.cleanup_run_state()
		var scene := get_tree().current_scene
		get_tree().current_scene = null
		if scene != null:
			scene.queue_free()
		for _cleanup_frame in range(4):
			await get_tree().process_frame
		_finish(ok, result)
		return
	_finish(false, {"error": "runtime_probe_timeout"})


func _finish(ok: bool, details: Dictionary) -> void:
	details["ok"] = ok
	var console_details := details.duplicate(true)
	console_details.erase("visual_report")
	print("ARENA_STUDIO_PHASE9_RUNTIME_SMOKE ", JSON.stringify(console_details))
	get_tree().quit(0 if ok else 1)
