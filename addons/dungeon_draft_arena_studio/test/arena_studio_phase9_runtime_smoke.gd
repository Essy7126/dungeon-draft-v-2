extends Node

const TEST_RUNNER := preload(
	"res://addons/dungeon_draft_arena_studio/test/arena_studio_test_runner.tscn"
)
const FOREST_PATH := "res://data/arenas/room_01_forest.tres"
const ODYSSEY_RUN_PATH := "res://data/runs/odyssey.tres"
const ODYSSEY_ENCOUNTER_PATH := (
	"res://data/encounters/odyssey_room_01_encounter.tres"
)
const CAPTURE_ROOT := "res://artifacts/terrain_studio/screenshots"


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
	var run := load(ODYSSEY_RUN_PATH) as RunData
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
	var canonical_hashes := {
		"run": FileAccess.get_sha256(ODYSSEY_RUN_PATH),
		"room": FileAccess.get_sha256(run.rooms[0].resource_path),
		"encounter": FileAccess.get_sha256(ODYSSEY_ENCOUNTER_PATH),
	}
	var prepared := ArenaDirectTestService.prepare(
		arena, run, &"real_encounter", {
			"integration_action": ArenaProductionAttachmentService.UPDATE,
			"target_room_index": 0,
		}
	)
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
			and bool(result.get("runtime_scene_inspected", false)) \
			and not bool(result.get("probe_pending", true)) \
			and bool(result.get("fingerprints_identical", false)) \
			and bool(result.get("topology_hashes_identical", false)) \
			and bool(result.get("configuration_consumed", false)) \
			and bool(result.get("illustration_loaded", false)) \
			and bool(result.get("encounter_preserved_and_loaded", false)) \
			and str(result.get("loaded_encounter_path", "")) == ODYSSEY_ENCOUNTER_PATH \
			and bool(result.get("canonical_sources_unchanged", false)) \
			and str(result.get("camera_mode", "")) == "STUDIO_MATCH" \
			and int(result.get("floor_layer_count", 0)) == 1 \
			and int(result.get("floor_renderer_count", 0)) == 1 \
			and int(result.get("duplicate_tile_count", -1)) == 0 \
			and int(result.get("misplaced_floor_node_count", -1)) == 0 \
			and not bool(result.get("produced_bundle_loaded", true))
		var capture_1280 := await _capture_runtime(Vector2i(1280, 720))
		var capture_1920 := await _capture_runtime(Vector2i(1920, 1080))
		result["capture_1280"] = capture_1280
		result["capture_1920"] = capture_1920
		result["canonical_hashes_before"] = canonical_hashes
		result["canonical_hashes_after"] = {
			"run": FileAccess.get_sha256(ODYSSEY_RUN_PATH),
			"room": FileAccess.get_sha256(run.rooms[0].resource_path),
			"encounter": FileAccess.get_sha256(ODYSSEY_ENCOUNTER_PATH),
		}
		ok = ok and bool(capture_1280.get("ok", false)) \
			and bool(capture_1920.get("ok", false)) \
			and result.canonical_hashes_before == result.canonical_hashes_after
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


func _capture_runtime(size: Vector2i) -> Dictionary:
	get_window().size = size
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	get_window().content_scale_size = size
	for _frame in range(4):
		await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := CAPTURE_ROOT.path_join(
		"terrain_update_real_encounter_combat_%dx%d.png" % [size.x, size.y]
	)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_ROOT))
	var error := image.save_png(ProjectSettings.globalize_path(path)) \
		if image != null and not image.is_empty() else ERR_CANT_CREATE
	return {"ok": error == OK, "path": path, "error": error_string(error)}


func _finish(ok: bool, details: Dictionary) -> void:
	details["ok"] = ok
	var console_details := details.duplicate(true)
	console_details.erase("visual_report")
	print("ARENA_STUDIO_PHASE9_RUNTIME_SMOKE ", JSON.stringify(console_details))
	get_tree().quit(0 if ok else 1)
