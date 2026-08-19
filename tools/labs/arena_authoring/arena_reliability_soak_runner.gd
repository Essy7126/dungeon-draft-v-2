extends Node

const USER_ROOT := "user://dungeon_draft_studio/tests/arena_reliability_soak"
const INTEGRATION_ROOT := "res://artifacts/studio_2_0/arena_reliability_soak"
const DEFAULT_REPORT_PATH := (
	"user://dungeon_draft_studio/reports/arena_reliability_soak.json"
)
const COMPLETION_MARKER := "ARENA_SOAK_IN_PROCESS_COMPLETE"
const DEFAULT_COUNTS := {
	"strokes": 100,
	"transforms": 100,
	"decorations": 20,
	"previews": 20,
	"tester_probes": 20,
	"rooms": 20,
	"production_updates": 10,
}
const COUNT_ARGUMENTS := {
	"--soak-strokes=": "strokes",
	"--soak-transforms=": "transforms",
	"--soak-decorations=": "decorations",
	"--soak-previews=": "previews",
	"--soak-tester-probes=": "tester_probes",
	"--soak-rooms=": "rooms",
	"--soak-production-updates=": "production_updates",
}


class SoakProbeScene:
	extends Node2D

	var runtime_ready_state := true
	var room_data: ArenaDefinition = null
	var grid: GridData = null
	var pathfinder: Pathfinder = null
	var arena_assembly := {}
	var camera: Camera2D = null
	var units: Array[Unit] = []
	var _direct_test_options := {}


var _expected_operations := DEFAULT_COUNTS.duplicate(true)
var _completed_operations := {
	"strokes": 0,
	"transforms": 0,
	"decorations": 0,
	"previews": 0,
	"tester_probes": 0,
	"rooms": 0,
	"production_updates": 0,
}
var _phase_samples := {}
var _latencies := {}
var _operation_errors: Array[Dictionary] = []
var _report_path := DEFAULT_REPORT_PATH
var _settle_msec := 2000
var _started_usec := 0
var _arena: ArenaDefinition = null
var _session: ArenaEditSession = null
var _canvas: ArenaStudioCanvas = null
var _transform_before := {}
var _transform_changed := false
var _preexisting_request := false
var _last_result_existed := false
var _last_result_content := PackedByteArray()
var _last_result_restore_ok := true
var _owned_auxiliary_paths: Array[String] = []
var _retained_state := {}


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_started_usec = Time.get_ticks_usec()
	_apply_arguments()
	var cleanup_before := _clean_fixture_roots()
	var before := ArenaSoakMetrics.sample(
		get_tree(), self, "before_arena", _elapsed_ms()
	)
	_capture_direct_test_state()
	if not cleanup_before:
		_fail("PRECONDITION_CLEANUP_FAILED")
	_setup_authoring_fixture()
	await get_tree().process_frame
	await get_tree().process_frame
	var authoring_baseline := ArenaSoakMetrics.sample(
		get_tree(), self, "authoring_baseline", _elapsed_ms()
	)

	await _run_strokes()
	await _run_transforms()
	_capture_bounded_retained_state()
	await _run_decorations()
	await _run_previews()
	await _run_tester_probes()
	await _run_rooms()
	await _run_production_updates()

	var before_cleanup := ArenaSoakMetrics.sample(
		get_tree(), self, "before_cleanup", _elapsed_ms()
	)
	_cleanup_authoring_fixture()
	_restore_direct_test_state()
	var roots_cleaned := _clean_fixture_roots()
	var auxiliary_cleaned := _clean_auxiliary_paths()
	var cleanup_ok := roots_cleaned and auxiliary_cleaned \
		and _last_result_restore_ok
	cleanup_ok = cleanup_ok and _fixture_roots_are_absent()
	if not _preexisting_request:
		cleanup_ok = cleanup_ok and not FileAccess.file_exists(
			ArenaDirectTestService.REQUEST_PATH
		)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(float(_settle_msec) / 1000.0).timeout
	var after_cleanup := ArenaSoakMetrics.sample(
		get_tree(), self, "after_cleanup", _elapsed_ms()
	)
	var evaluation := ArenaSoakMetrics.evaluate(
		before,
		after_cleanup,
		_phase_samples,
		_latencies,
		_expected_operations,
		_completed_operations,
		cleanup_ok
	)
	var ok := bool(evaluation.get("ok", false)) and _operation_errors.is_empty()
	var report := {
		"schema_version": 1,
		"suite": "ARENA_RELIABILITY_SOAK_V1",
		"ok": ok,
		"verdict": "PASS" if ok else "FAIL",
		"default_counts_exact": _expected_operations == DEFAULT_COUNTS,
		"expected_operations": _expected_operations.duplicate(true),
		"completed_operations": _completed_operations.duplicate(true),
		"duration_ms": snappedf(_elapsed_ms(), 0.001),
		"before_arena": before,
		"authoring_baseline": authoring_baseline,
		"before_cleanup": before_cleanup,
		"after_cleanup": after_cleanup,
		"arena_in_process_delta": evaluation.get(
			"arena_in_process_delta", {}
		),
		"arena_in_process_gate": evaluation,
		"operation_errors": _operation_errors,
		"phase_samples": _phase_samples,
		"latency_samples_ms": _latencies,
		"retained_state": _retained_state,
		"cleanup": {
			"ok": cleanup_ok,
			"user_root_absent": not DirAccess.dir_exists_absolute(
				ProjectSettings.globalize_path(USER_ROOT)
			),
			"integration_root_absent": not DirAccess.dir_exists_absolute(
				ProjectSettings.globalize_path(INTEGRATION_ROOT)
			),
			"preexisting_direct_test_request_preserved": _preexisting_request,
			"last_result_restored": _last_result_restore_ok,
		},
		# Le wrapper remplace ce statut par les diagnostics trouves uniquement
		# apres COMPLETION_MARKER. Ce champ n'influence jamais le delta Arena.
		"shutdown_historical_errors": {
			"collection": "PENDING_EXTERNAL_WRAPPER",
			"gate_affects_arena": false,
			"diagnostics": [],
		},
	}
	_write_report(report)
	print("ARENA_RELIABILITY_SOAK_JSON=%s" % JSON.stringify(report))
	print(COMPLETION_MARKER)
	get_tree().quit(0 if ok else 1)


func _apply_arguments() -> void:
	for argument in OS.get_cmdline_user_args():
		for prefix in COUNT_ARGUMENTS:
			if argument.begins_with(prefix):
				var key := str(COUNT_ARGUMENTS[prefix])
				_expected_operations[key] = clampi(
					int(argument.trim_prefix(prefix)),
					1,
					int(DEFAULT_COUNTS[key])
				)
		if argument.begins_with("--soak-report="):
			var requested := argument.trim_prefix("--soak-report=").strip_edges()
			if not requested.is_empty():
				_report_path = requested
		elif argument.begins_with("--soak-settle-ms="):
			_settle_msec = clampi(
				int(argument.trim_prefix("--soak-settle-ms=")), 100, 5000
			)


func _setup_authoring_fixture() -> void:
	_session = ArenaEditSession.new()
	if not _session.open(_fixture(), "", true, "arena_reliability_soak"):
		_fail("SESSION_OPEN_FAILED")
		return
	_arena = _session.working_arena
	_canvas = ArenaStudioCanvas.new()
	_canvas.name = "ArenaReliabilitySoakCanvas"
	_canvas.size = Vector2(1280, 720)
	add_child(_canvas)
	_canvas.set_arena(_arena)
	_canvas.set_tool(ArenaStudioCanvas.Tool.TRANSFORM_GRID)
	_canvas.stroke_started.connect(_on_transform_started)
	_canvas.transform_commit_requested.connect(_on_transform_commit)
	_canvas.stroke_finished.connect(_on_transform_finished)
	_canvas.stroke_cancelled.connect(_on_transform_cancelled)


func _cleanup_authoring_fixture() -> void:
	if _canvas != null and is_instance_valid(_canvas):
		_canvas.cancel_active_gesture()
		_canvas.clear_overlays()
		_canvas.free()
	_canvas = null
	_arena = null
	_session = null
	_transform_before = {}
	_transform_changed = false


func _run_strokes() -> void:
	if _arena == null:
		return
	var count := int(_expected_operations.strokes)
	for index in range(count):
		var started := Time.get_ticks_usec()
		var cell := Vector2i(index % 12 + 1, index * 5 % 12 + 1)
		var current := _arena.get_cell_definition(cell)
		var terrain := &"water" \
			if current == null or current.terrain_id != &"water" else &"stone"
		var batch := ArenaStrokeBatchService.new()
		batch.begin_stroke(_arena)
		batch.apply_terrain_cells([cell], terrain)
		var result := batch.finish()
		_record_latency("strokes", started)
		if bool(result.get("changed", false)) \
				and int(result.get("runtime_sync_calls", 0)) == 1:
			_completed_operations.strokes += 1
		else:
			_fail("STROKE_FAILED", {"index": index, "result": result})
		if _checkpoint_due(index, count, 10):
			await get_tree().process_frame
			_record_sample("strokes", index + 1)


func _run_transforms() -> void:
	if _arena == null or _canvas == null:
		return
	_canvas.set_tool(ArenaStudioCanvas.Tool.TRANSFORM_GRID)
	var count := int(_expected_operations.transforms)
	for index in range(count):
		var started := Time.get_ticks_usec()
		var history_before := _session.history.get_current_index()
		var start := _canvas._image_native_to_screen(_arena.grid_origin)
		if not _canvas._begin_transform_handle(
				ArenaStudioCanvas.TransformHandle.BODY, start, false, true
			):
			_fail("TRANSFORM_BEGIN_FAILED", {"index": index})
			continue
		var sign_value := 1.0 if index % 2 == 0 else -1.0
		# Meme amplitude que le soak historique de transformation : elle produit
		# une vraie mutation avant de revenir au geste suivant, sans derive nette.
		var position := start + Vector2(3.0, -1.25) * sign_value
		var motion := InputEventMouseMotion.new()
		motion.position = position
		_canvas._handle_mouse_motion(motion)
		_canvas._process(0.0)
		_release_canvas(position)
		_record_latency("transforms", started)
		if _session.history.get_current_index() == history_before + 1:
			_completed_operations.transforms += 1
		else:
			_fail("TRANSFORM_COMMIT_FAILED", {
				"index": index,
				"history_before": history_before,
				"history_after": _session.history.get_current_index(),
			})
		if _checkpoint_due(index, count, 10):
			await get_tree().process_frame
			_record_sample("transforms", index + 1)


func _run_decorations() -> void:
	if _arena == null:
		return
	var count := int(_expected_operations.decorations)
	for index in range(count):
		var started := Time.get_ticks_usec()
		var cell := Vector2i(index % 12 + 1, index * 7 % 12 + 1)
		var placed := ArenaDynamicEditingService.place_decoration(_arena, cell)
		var removed := ArenaDynamicEditingService.remove_special(_arena, cell)
		_record_latency("decorations", started)
		if placed and removed and _arena.decorations.is_empty():
			_completed_operations.decorations += 1
		else:
			_fail("DECORATION_LIFECYCLE_FAILED", {
				"index": index, "placed": placed, "removed": removed,
			})
		if _checkpoint_due(index, count, 4):
			await get_tree().process_frame
			_record_sample("decorations", index + 1)


func _run_previews() -> void:
	if _arena == null:
		return
	var count := int(_expected_operations.previews)
	for index in range(count):
		var started := Time.get_ticks_usec()
		var preview := ArenaRuntimePreview.new()
		preview.name = "ArenaSoakPreview_%02d" % index
		preview.size = Vector2(640, 420)
		preview.show_characters = false
		add_child(preview)
		await get_tree().process_frame
		preview.set_arena(_arena)
		var rebuilt := preview.rebuild_now()
		var parity := preview.parity_with_runtime()
		preview.cleanup_preview()
		preview.free()
		preview = null
		await get_tree().process_frame
		_record_latency("previews", started)
		if rebuilt and bool(parity.get("ok", false)):
			_completed_operations.previews += 1
		else:
			_fail("PREVIEW_LIFECYCLE_FAILED", {
				"index": index, "rebuilt": rebuilt, "parity": parity,
			})
		if _checkpoint_due(index, count, 4):
			_record_sample("previews", index + 1)


func _run_tester_probes() -> void:
	if _arena == null:
		return
	if _preexisting_request:
		_fail("PREEXISTING_DIRECT_TEST_REQUEST", {
			"path": ArenaDirectTestService.REQUEST_PATH,
			"preserved": true,
		})
		return
	var count := int(_expected_operations.tester_probes)
	for index in range(count):
		var started := Time.get_ticks_usec()
		var prepared := ArenaDirectTestService.prepare(
			_arena, null, &"soak_light", {
				"probe_only": true,
				"quit_after_probe": true,
			}
		)
		var probe_result := {}
		var cleaned := false
		if bool(prepared.get("ok", false)):
			var temporary := ResourceLoader.load(
				str(prepared.get("arena_path", "")), "",
				ResourceLoader.CACHE_MODE_IGNORE_DEEP
			) as ArenaDefinition
			var probe_scene := _build_probe_scene(temporary)
			if probe_scene != null:
				probe_result = ArenaRuntimeSceneProbeService.inspect(
					probe_scene,
					prepared.request,
					{
						"topology_hashes_identical": true,
						"produced_bundle_loaded": false,
					}
				)
				probe_scene.free()
				probe_scene = null
			cleaned = ArenaDirectTestService.cleanup_context(prepared.request)
		await get_tree().process_frame
		_record_latency("tester_probes", started)
		if bool(prepared.get("ok", false)) \
				and bool(probe_result.get("ok", false)) and cleaned:
			_completed_operations.tester_probes += 1
		else:
			_fail("TESTER_PROBE_LIFECYCLE_FAILED", {
				"index": index,
				"prepare_ok": bool(prepared.get("ok", false)),
				"prepare_error": str(prepared.get("error", "")),
				"probe": probe_result,
				"cleaned": cleaned,
			})
		if _checkpoint_due(index, count, 4):
			_record_sample("tester_probes", index + 1)


func _run_rooms() -> void:
	if _arena == null:
		return
	var count := int(_expected_operations.rooms)
	for index in range(count):
		var started := Time.get_ticks_usec()
		var ok := _room_lifecycle(index)
		_record_latency("rooms", started)
		if ok:
			_completed_operations.rooms += 1
		else:
			_fail("ROOM_LIFECYCLE_FAILED", {"index": index})
		if _checkpoint_due(index, count, 4):
			await get_tree().process_frame
			_record_sample("rooms", index + 1)


func _run_production_updates() -> void:
	var count := int(_expected_operations.production_updates)
	for index in range(count):
		var started := Time.get_ticks_usec()
		var cycle := _production_update_cycle(index)
		var cycle_cleanup := _cleanup_production_cycle(cycle)
		await get_tree().process_frame
		await get_tree().process_frame
		_record_latency("production_updates", started)
		if bool(cycle.get("ok", false)) and cycle_cleanup:
			_completed_operations.production_updates += 1
		else:
			_fail("PRODUCTION_UPDATE_LIFECYCLE_FAILED", {
				"index": index,
				"result": cycle,
				"cleanup_ok": cycle_cleanup,
			})
		_record_sample("production_updates", index + 1)


func _room_lifecycle(index: int) -> bool:
	var room := ArenaDefinition.new()
	if not RoomDataSnapshotService.restore(
			room, RoomDataSnapshotService.capture(_arena)
		):
		return false
	room.set_identity("Soak room %02d" % index, "soak_room_%02d" % index)
	if not ArenaRuntimeBridge.sync_runtime_resources(room):
		return false
	var projection := ArenaRuntimeProjectionService.build(room)
	var ok := projection != null and projection.grid != null \
		and projection.arena_projection != null \
		and ArenaSnapshotService.arena_fingerprint(room) \
			== ArenaSnapshotService.arena_fingerprint(projection.arena_projection)
	projection = null
	room = null
	return ok


func _production_update_cycle(index: int) -> Dictionary:
	var user_cycle := USER_ROOT.path_join("production/cycle_%02d" % index)
	var integration_cycle := INTEGRATION_ROOT.path_join("cycle_%02d" % index)
	if not _is_owned_fixture_path(user_cycle) \
			or not _is_owned_fixture_path(integration_cycle):
		return {"ok": false, "error": "unsafe_fixture_path"}
	var source := _production_fixture(index)
	var destination := user_cycle.path_join("bundle")
	var produced := ArenaProductionService.produce(source, destination)
	var result := {
		"ok": false,
		"user_cycle": user_cycle,
		"integration_cycle": integration_cycle,
		"auxiliary_paths": [],
		"production_ok": bool(produced.get("ok", false)),
	}
	var transaction := produced.get("transaction", {}) as Dictionary
	if not transaction.is_empty():
		var transaction_path := str(transaction.get("transaction_directory", ""))
		var transaction_registered := _register_auxiliary_path(
			transaction_path, ArenaProductionTransactionService.TRANSACTION_ROOT
		)
		if transaction_registered:
			(result.auxiliary_paths as Array).append(transaction_path)
		ArenaProductionTransactionService.finalize(transaction)
		if not transaction_path.is_empty() and not transaction_registered:
			result["error"] = "unsafe_transaction_fixture_path"
			result["unsafe_path"] = transaction_path
			return result
	if not bool(produced.get("ok", false)):
		result["error"] = str(produced.get("error", "production_failed"))
		return result
	if DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(integration_cycle)
		) != OK:
		result["error"] = "integration_fixture_directory_failed"
		return result
	var target := ArenaDefinition.new()
	if not RoomDataSnapshotService.restore(
			target, RoomDataSnapshotService.capture(source)
		):
		result["error"] = "target_restore_failed"
		return result
	var target_path := integration_cycle.path_join("target_room.tres")
	if ResourceSaver.save(target, target_path) != OK:
		result["error"] = "target_save_failed"
		return result
	var loaded_target := ResourceLoader.load(
		target_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as ArenaDefinition
	if loaded_target == null:
		result["error"] = "target_reload_failed"
		return result
	var run := _run_fixture(loaded_target, index)
	var run_path := integration_cycle.path_join("run.tres")
	if ResourceSaver.save(run, run_path) != OK:
		result["error"] = "run_save_failed"
		return result
	var loaded_run := ResourceLoader.load(
		run_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as RunData
	if loaded_run == null:
		result["error"] = "run_reload_failed"
		return result
	var update := ArenaProductionAttachmentService.attach_and_save(
		str(produced.get("arena_path", "")),
		loaded_run,
		ArenaProductionAttachmentService.UPDATE,
		0
	)
	var recovery_path := str(update.get("room_recovery_path", ""))
	var recovery_registered := _register_auxiliary_path(
		recovery_path, ArenaProductionAttachmentService.RECOVERY_ROOT
	)
	if recovery_registered:
		(result.auxiliary_paths as Array).append(recovery_path)
	if not recovery_path.is_empty() and not recovery_registered:
		result["error"] = "unsafe_recovery_fixture_path"
		result["unsafe_path"] = recovery_path
		return result
	result["update_ok"] = bool(update.get("ok", false))
	result["preserved_gameplay"] = bool(update.get("preserved_gameplay", false))
	result["integrated_room_path"] = str(update.get("integrated_room_path", ""))
	result["ok"] = bool(update.get("ok", false)) \
		and bool(update.get("preserved_gameplay", false)) \
		and str(update.get("integrated_room_path", "")) == target_path
	if not bool(result.ok):
		result["error"] = str(update.get("error", "update_failed"))
	return result


func _cleanup_production_cycle(cycle: Dictionary) -> bool:
	var ok := true
	for path_value in cycle.get("auxiliary_paths", []):
		var path := str(path_value)
		if not path.is_empty():
			ok = _remove_auxiliary_path(path) and ok
	var user_cycle := str(cycle.get("user_cycle", ""))
	var integration_cycle := str(cycle.get("integration_cycle", ""))
	if not user_cycle.is_empty():
		ok = _remove_fixture_tree(user_cycle) and ok
	if not integration_cycle.is_empty():
		ok = _remove_fixture_tree(integration_cycle) and ok
	return ok


func _build_probe_scene(arena: ArenaDefinition) -> SoakProbeScene:
	if arena == null:
		return null
	var state := ArenaRuntimeProjectionService.build(arena)
	if state == null or state.arena_projection == null or state.grid == null:
		return null
	var scene := SoakProbeScene.new()
	scene.name = "ArenaSoakProbeScene"
	scene.room_data = state.arena_projection
	scene.grid = state.grid
	scene.pathfinder = Pathfinder.new(state.grid)
	scene._direct_test_options = {
		"configuration": "soak_light",
		"camera_mode": "STUDIO_MATCH",
		"spawn_heroes": false,
		"spawn_enemies": false,
		"deployment_enabled": false,
	}
	add_child(scene)
	var floor_parent := Node2D.new()
	floor_parent.name = "ArenaTilesLayer"
	floor_parent.y_sort_enabled = false
	scene.add_child(floor_parent)
	var grid_view := PaintedGridView.new()
	grid_view.name = "SharedGridView"
	grid_view.configure(
		scene.room_data.painted_map_visual_data,
		scene.room_data.grid_layout,
		scene.room_data.hero_spawn_zone,
		scene.room_data.enemy_spawn_zone
	)
	grid_view.setup(scene.grid)
	scene.add_child(grid_view)
	var y_sorted_world := Node2D.new()
	y_sorted_world.name = "YSortedWorld"
	y_sorted_world.y_sort_enabled = true
	scene.add_child(y_sorted_world)
	scene.arena_assembly = ArenaVisualAssembler.assemble(
		scene.room_data,
		scene.grid,
		scene.pathfinder,
		grid_view,
		y_sorted_world,
		scene,
		true,
		floor_parent
	)
	scene.camera = Camera2D.new()
	scene.camera.name = "SoakProbeCamera"
	scene.add_child(scene.camera)
	return scene


func _production_fixture(index: int) -> ArenaDefinition:
	var arena := ArenaDefinition.new()
	arena.set_identity(
		"Reliability production %02d" % index,
		"reliability_production_%02d" % index
	)
	arena.visual_mode = ArenaDefinition.VisualMode.MODULAR
	arena.theme_id = &"dynamic_default"
	arena.modular_visual_profile = ArenaModularVisualProfile.new()
	arena.grid_size = Vector2i(5, 4)
	arena.grid_origin = Vector2.ZERO
	arena.axis_x = Vector2(32, 16)
	arena.axis_y = Vector2(-32, 16)
	for y in range(arena.grid_size.y):
		for x in range(arena.grid_size.x):
			ArenaTerrainRegistry.configure_cell(
				arena.ensure_cell(Vector2i(x, y)), &"stone"
			)
	ArenaEditingService.prepare_automatically(arena)
	arena.encounter_definition = _encounter_fixture()
	arena.enemies.assign(arena.encounter_definition.roster_units)
	arena.minimum_wave_count = 1
	arena.maximum_wave_count = 1
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	return arena


func _run_fixture(room: RoomData, index: int) -> RunData:
	var run := RunData.new()
	run.run_name = "Arena reliability soak %02d" % index
	run.room_flow_mode = RunData.RoomFlowMode.SINGLE_ENCOUNTER
	run.maximum_waves_per_room = 1
	run.rooms = [room]
	return run


func _encounter_fixture() -> EncounterDefinition:
	var enemy := UnitData.new()
	enemy.unit_id = &"arena_reliability_soak_enemy"
	enemy.unit_name = "Arena reliability soak enemy"
	enemy.team = 1
	var encounter := EncounterDefinition.new()
	encounter.room_index = 1
	encounter.roster_units = [enemy]
	encounter.roster_counts = PackedInt32Array([1])
	encounter.living_enemy_cap = 1
	encounter.formation_profiles = [&"line"]
	return encounter


func _fixture() -> ArenaDefinition:
	var arena := ArenaDefinition.new()
	arena.set_identity("Arena reliability soak", "arena_reliability_soak")
	arena.visual_mode = ArenaDefinition.VisualMode.MODULAR
	arena.theme_id = &"dynamic_default"
	arena.modular_visual_profile = ArenaModularVisualProfile.new()
	arena.grid_size = Vector2i(14, 14)
	arena.source_image_size = Vector2i(1024, 768)
	arena.background_path = "res://addons/gut/icon.png"
	arena.grid_origin = Vector2(512, 120)
	arena.axis_x = Vector2(32, 16)
	arena.axis_y = Vector2(-32, 16)
	arena.calibration_cells = [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN]
	arena.calibration_pixels = [
		arena.grid_origin,
		arena.grid_origin + arena.axis_x,
		arena.grid_origin + arena.axis_y,
	]
	for y in range(arena.grid_size.y):
		for x in range(arena.grid_size.x):
			ArenaTerrainRegistry.configure_cell(
				arena.ensure_cell(Vector2i(x, y)), &"stone"
			)
	ArenaEditingService.prepare_automatically(arena)
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	return arena


func _on_transform_started(_action_name: String) -> void:
	_transform_before = _arena.to_snapshot() if _arena != null else {}
	_transform_changed = false


func _on_transform_commit(
		snapshot: GridTransformSnapshot,
		cells: Array[Vector2i],
		pixels: Array[Vector2]
	) -> void:
	if _arena == null:
		return
	snapshot.apply_to(_arena)
	_arena.calibration_cells = cells.duplicate()
	_arena.calibration_pixels = pixels.duplicate()
	ArenaRuntimeBridge.sync_runtime_resources(
		_arena, ArenaRuntimeBridge.SyncScope.GRID_TRANSFORM
	)
	_transform_changed = true


func _on_transform_finished(action_name: String) -> void:
	if _transform_changed and _session != null:
		_session.commit(
			action_name, _transform_before, _arena.to_snapshot(), true
		)
	_transform_before = {}
	_transform_changed = false


func _on_transform_cancelled() -> void:
	_transform_before = {}
	_transform_changed = false


func _release_canvas(position: Vector2) -> void:
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = position
	_canvas._handle_mouse_button(release)


func _capture_direct_test_state() -> void:
	_preexisting_request = FileAccess.file_exists(
		ArenaDirectTestService.REQUEST_PATH
	)
	_last_result_existed = FileAccess.file_exists(
		ArenaDirectTestService.LAST_RESULT_PATH
	)
	if _last_result_existed:
		_last_result_content = FileAccess.get_file_as_bytes(
			ArenaDirectTestService.LAST_RESULT_PATH
		)


func _capture_bounded_retained_state() -> void:
	if _session == null:
		_retained_state = {
			"history_available": false,
			"history_bounded": false,
		}
		_fail("TRANSFORM_HISTORY_UNAVAILABLE")
		return
	var action_count := _session.history.get_current_index()
	var entry_count := _session.history.get_history_entries().size()
	var maximum_actions := _session.history.max_steps
	var expected_actions := int(_expected_operations.transforms)
	var bounded := action_count <= maximum_actions \
		and entry_count <= maximum_actions
	var matches_completed := action_count \
		== int(_completed_operations.transforms) \
		and entry_count == int(_completed_operations.transforms)
	_retained_state = {
		"history_available": true,
		"history_actions": action_count,
		"history_entries": entry_count,
		"history_limit": maximum_actions,
		"expected_transform_actions": expected_actions,
		"history_bounded": bounded,
		"history_matches_completed_transforms": matches_completed,
		"memory_growth_policy": (
			"expected_during_transform_then_rechecked_after_cleanup"
		),
	}
	if not bounded:
		_fail("TRANSFORM_HISTORY_UNBOUNDED", _retained_state)
	if not matches_completed:
		_fail("TRANSFORM_HISTORY_COUNT_MISMATCH", _retained_state)


func _restore_direct_test_state() -> void:
	_last_result_restore_ok = true
	if _preexisting_request:
		return
	var last_result_absolute := ProjectSettings.globalize_path(
		ArenaDirectTestService.LAST_RESULT_PATH
	)
	if _last_result_existed:
		DirAccess.make_dir_recursive_absolute(last_result_absolute.get_base_dir())
		var file := FileAccess.open(
			ArenaDirectTestService.LAST_RESULT_PATH, FileAccess.WRITE
		)
		if file != null:
			file.store_buffer(_last_result_content)
			file.close()
		else:
			_last_result_restore_ok = false
	else:
		if FileAccess.file_exists(last_result_absolute):
			_last_result_restore_ok = (
				DirAccess.remove_absolute(last_result_absolute) == OK
			)


func _record_latency(phase: String, started_usec: int) -> void:
	var values: Array = _latencies.get(phase, []) as Array
	values.append(float(Time.get_ticks_usec() - started_usec) / 1000.0)
	_latencies[phase] = values


func _record_sample(phase: String, operation_count: int) -> void:
	var samples: Array = _phase_samples.get(phase, []) as Array
	samples.append(ArenaSoakMetrics.sample(
		get_tree(),
		self,
		"%s_%d" % [phase, operation_count],
		_elapsed_ms()
	))
	_phase_samples[phase] = samples


func _checkpoint_due(index: int, count: int, stride: int) -> bool:
	return (index + 1) % stride == 0 or index + 1 == count


func _elapsed_ms() -> float:
	return float(Time.get_ticks_usec() - _started_usec) / 1000.0


func _fail(classification: String, details: Dictionary = {}) -> void:
	var failure := {
		"classification": classification,
		"elapsed_ms": snappedf(_elapsed_ms(), 0.001),
	}
	failure.merge(details, true)
	_operation_errors.append(failure)


func _clean_fixture_roots() -> bool:
	var user_cleaned := _remove_fixture_tree(USER_ROOT)
	var integration_cleaned := _remove_fixture_tree(INTEGRATION_ROOT)
	return user_cleaned and integration_cleaned


func _fixture_roots_are_absent() -> bool:
	return not DirAccess.dir_exists_absolute(
		ProjectSettings.globalize_path(USER_ROOT)
	) and not DirAccess.dir_exists_absolute(
		ProjectSettings.globalize_path(INTEGRATION_ROOT)
	)


func _remove_fixture_tree(path: String) -> bool:
	if not _is_owned_fixture_path(path):
		return false
	return ArenaProductionTransactionService._remove_tree(path)


func _is_owned_fixture_path(path: String) -> bool:
	return path == USER_ROOT or path.begins_with(USER_ROOT + "/") \
		or path == INTEGRATION_ROOT \
		or path.begins_with(INTEGRATION_ROOT + "/")


func _register_auxiliary_path(path: String, allowed_root: String) -> bool:
	if path.is_empty() or path == allowed_root \
			or not path.begins_with(allowed_root + "/"):
		return false
	if not _owned_auxiliary_paths.has(path):
		_owned_auxiliary_paths.append(path)
	return true


func _remove_auxiliary_path(path: String) -> bool:
	if not _owned_auxiliary_paths.has(path):
		return false
	return ArenaProductionTransactionService._remove_tree(path)


func _clean_auxiliary_paths() -> bool:
	var ok := true
	for path in _owned_auxiliary_paths:
		ok = _remove_auxiliary_path(path) and ok
		ok = not DirAccess.dir_exists_absolute(
			ProjectSettings.globalize_path(path)
		) and ok
	return ok


func _write_report(report: Dictionary) -> void:
	var absolute := ProjectSettings.globalize_path(_report_path)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
		push_error("ARENA_SOAK_REPORT_DIRECTORY_FAILED: %s" % absolute)
		return
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	if file == null:
		push_error("ARENA_SOAK_REPORT_WRITE_FAILED: %s" % absolute)
		return
	file.store_string(JSON.stringify(report, "  "))
	file.close()
