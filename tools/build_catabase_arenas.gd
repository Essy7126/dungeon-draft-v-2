extends Node

## Reproducible Arena Studio pipeline for the three Catabase rooms.

const RUN_PATH := "res://data/runs/odyssey.tres"
const PRESENTATION_PATH := "res://data/maps/painted/catabase_presentation.tres"
const TEST_CONFIGURATION := &"real_encounter"
const BRONZE_BLOCK_SCENE := "res://tools/labs/forest_dynamic_grid/StaticForestWall.tscn"
const ASH_VOID_CELL_SCENE := "res://data/maps/painted/catabase_ash_void_cell.tscn"
const ROOM_ONE_BLOCKED_CELLS: Array[Vector2i] = [
	Vector2i(9, 4), Vector2i(10, 4), Vector2i(4, 5),
	Vector2i(9, 5), Vector2i(10, 5), Vector2i(2, 6),
	Vector2i(3, 6), Vector2i(9, 8), Vector2i(10, 9),
	Vector2i(8, 10), Vector2i(9, 10),
]

const ROOM_SPECS := [
	{
		"arena_id": &"catabase_room_01_frail_hellspawn",
		"background_path": "res://asset/map/painted/greece/map2-_achilles.png",
		"source_image_size": Vector2i(1535, 1024),
		"grid_origin": Vector2(768.0, 201.0),
		"axis_x": Vector2(46.75, 23.5),
		"axis_y": Vector2(-46.75, 23.5),
		"camera_offset": Vector2(0.0, 12.0),
		"camera_zoom": 0.99,
		"anchors": [0, 6, 13],
		"art_direction": "Sanctuaire en lisière — seuil monumental de la Catabase.",
	},
	{
		"arena_id": &"catabase_room_02_ash_gate",
		"background_path": "res://asset/map/painted/catabase/catabase_ash_gate_v1.png",
		"source_image_size": Vector2i(1672, 941),
		"grid_origin": Vector2(836.0, 198.0),
		"axis_x": Vector2(52.0, 26.0),
		"axis_y": Vector2(-52.0, 26.0),
		"camera_offset": Vector2(0.0, 12.0),
		"camera_zoom": 0.99,
		"anchors": [0, 6, 13],
		"art_direction": "Seuil infernal brûlé — porte des Cendres et mêlée resserrée.",
	},
	{
		"arena_id": &"catabase_room_03_judgement",
		"background_path": "res://asset/map/painted/greece/maps_achille_dalle.png",
		"source_image_size": Vector2i(1672, 941),
		"grid_origin": Vector2(840.0, 141.0),
		"axis_x": Vector2(52.0, 26.0),
		"axis_y": Vector2(-52.0, 26.0),
		"camera_offset": Vector2(4.0, 12.0),
		"camera_zoom": 0.99,
		"anchors": [0, 6, 12],
		"art_direction": "Temple symétrique — scène finale du Jugement de Paris.",
	},
]


func _ready() -> void:
	var arguments := OS.get_cmdline_user_args()
	var room_index := _integer_argument(arguments, "--room=", -1)
	if room_index < 0 or room_index >= ROOM_SPECS.size():
		_finish(false, {"error": "usage", "usage": "--room=0|1|2 --plan|--prepare-runtime|--integrate"})
		return
	var run_data := ResourceLoader.load(RUN_PATH, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as RunData
	if run_data == null or room_index >= run_data.rooms.size():
		_finish(false, {"error": "catabase_run_missing", "room": room_index})
		return
	var arena := _build_arena(run_data, room_index)
	if arena == null:
		_finish(false, {"error": "arena_build_failed", "room": room_index})
		return
	var validation := ArenaValidator.validate(arena, false, run_data)
	var render_plan := ArenaTerrainRenderPlanService.build(arena)
	var payload := {
		"room": room_index + 1,
		"arena_id": str(arena.arena_id),
		"room_name": arena.display_name,
		"background_path": arena.background_path,
		"grid_size": [arena.grid_size.x, arena.grid_size.y],
		"calibration_rms": (arena.painted_map_visual_data as PaintedMapVisualData).calibration_rms(),
		"validation_ok": validation.is_valid(),
		"validation_errors": validation.error_count(),
		"validation_warnings": validation.warning_count(),
		"render_plan_ok": bool(render_plan.get("ok", false)),
		"rendered_floor_count": int(render_plan.get("expected_terrain_cell_count", 0)),
		"neutral_floor_count": int((render_plan.get("expected_by_terrain_id", {}) as Dictionary).get("neutral", 0)),
		"decoration_count": arena.decorations.size(),
	}
	if not validation.is_valid() or not bool(render_plan.get("ok", false)):
		payload["error"] = "candidate_invalid"
		payload["render_errors"] = render_plan.get("errors", [])
		_finish(false, payload)
		return
	if arguments.has("--plan"):
		var plan := ArenaProductionService.plan(arena, _destination(arena), null, {"target_run": run_data})
		payload["can_produce"] = bool(plan.get("can_produce", false))
		payload["destination"] = plan.get("destination", "")
		_finish(bool(plan.get("can_produce", false)), payload)
	elif arguments.has("--prepare-runtime"):
		var preparation := ArenaDirectTestService.prepare(
			arena, run_data, TEST_CONFIGURATION,
			{
				"integration_action": ArenaProductionAttachmentService.UPDATE,
				"target_room_index": room_index,
				"probe_only": true,
				"quit_after_probe": true,
			}
		)
		payload["runtime_preparation_ok"] = bool(preparation.get("ok", false))
		payload["gameplay_preserved"] = bool(preparation.get("gameplay_preserved", false))
		payload["canonical_sources_unchanged"] = bool(preparation.get("canonical_sources_unchanged", false))
		payload["runtime_probe_key"] = preparation.get("runtime_probe_key", "")
		_finish(bool(preparation.get("ok", false)), payload)
	elif arguments.has("--integrate"):
		_integrate(arena, run_data, room_index, payload)
	else:
		payload["error"] = "mode_missing"
		_finish(false, payload)


func _build_arena(run_data: RunData, room_index: int) -> ArenaDefinition:
	var room := run_data.rooms[room_index] as RoomData
	if room == null or room.resource_path.is_empty():
		return null
	var arena: ArenaDefinition = null
	if room is ArenaDefinition:
		arena = ArenaDefinition.new()
		if not RoomDataSnapshotService.restore(arena, RoomDataSnapshotService.capture(room)):
			return null
	else:
		arena = ArenaLegacyImporter.import_room(room.resource_path)
	if arena == null:
		return null
	var spec := ROOM_SPECS[room_index] as Dictionary
	arena.set_identity(room.room_name, str(spec.arena_id))
	arena.visual_mode = ArenaDefinition.VisualMode.HYBRID
	arena.theme_id = &"painted_default"
	arena.background_path = str(spec.background_path)
	arena.source_image_size = spec.source_image_size
	arena.grid_origin = spec.grid_origin
	arena.axis_x = spec.axis_x
	arena.axis_y = spec.axis_y
	arena.image_offset = Vector2.ZERO
	arena.image_scale = Vector2.ONE
	arena.foreground_path = ""
	arena.occlusion_mask_path = ""
	arena.foreground_offset = Vector2.ZERO
	arena.foreground_scale = Vector2.ONE
	arena.foreground_occluder_polygon = PackedVector2Array()
	arena.foreground_occluder_sort_y = 0.0
	arena.foreground_full_hide_rect = Rect2()
	arena.camera_offset = spec.camera_offset
	arena.camera_zoom = float(spec.camera_zoom)
	arena.presentation_profile_path = PRESENTATION_PATH
	arena.modular_visual_profile = _neutral_floor_profile()
	_set_calibration(arena, spec.anchors as Array)
	for definition in arena.cells:
		if definition != null and definition.defined \
				and not ArenaTopologySignatureService.is_void_definition(definition):
			definition.terrain_id = &"neutral"
	_configure_decorations(arena, room_index)
	arena.production_notes = (
		"Catabase — composition produite avec Dungeon Draft Studio.\n"
		+ str(spec.art_direction) + "\n"
		+ "Socle central : dalle Neutre beige sur toutes les cases définies.\n"
		+ "Relief et espaces non jouables matérialisés sans modifier la topologie.\n"
		+ "Topologie, obstacles, spawns et gameplay préservés depuis %s."
	) % room.resource_path
	ArenaTerrainRenderPlanService.clear_cache()
	return arena if ArenaRuntimeBridge.sync_runtime_resources(arena) else null


func _configure_decorations(arena: ArenaDefinition, room_index: int) -> void:
	var retained: Array[ArenaDecorationDefinition] = []
	for existing in arena.decorations:
		if existing != null and not str(existing.decoration_id).begins_with("catabase_"):
			retained.append(existing)
	arena.decorations = retained
	if room_index == 0:
		for cell in ROOM_ONE_BLOCKED_CELLS:
			var block := ArenaDecorationDefinition.new()
			block.decoration_id = StringName("catabase_bronze_block_%02d_%02d" % [cell.x, cell.y])
			block.scene_path = BRONZE_BLOCK_SCENE
			block.visual_variant = &"bronze_block"
			block.cell = cell
			block.visual_scale = Vector2.ONE * 1.36
			block.layer = &"y_sorted_props"
			block.y_sort = true
			arena.decorations.append(block)
	elif room_index == 1:
		for y_value in range(arena.grid_size.y):
			for x_value in range(arena.grid_size.x):
				var cell := Vector2i(x_value, y_value)
				var definition := arena.get_cell_definition(cell)
				if definition != null and not ArenaTopologySignatureService.is_void_definition(definition):
					continue
				var cover := ArenaDecorationDefinition.new()
				cover.decoration_id = StringName("catabase_ash_void_%02d_%02d" % [cell.x, cell.y])
				cover.scene_path = ASH_VOID_CELL_SCENE
				cover.visual_variant = &"ash_void"
				cover.cell = cell
				# Children draw at z=-20, but the root stays outside ArenaTilesLayer
				# so runtime terrain accounting remains exactly 134 nodes.
				cover.layer = &"y_sorted_props"
				cover.y_sort = false
				arena.decorations.append(cover)


func _neutral_floor_profile() -> ArenaModularVisualProfile:
	var profile := ArenaModularVisualProfile.new()
	profile.theme_id = &"painted_default"
	profile.base_terrain_id = &"neutral"
	profile.hybrid_floor_policy = ArenaModularVisualProfile.HybridFloorPolicy.ALL_DEFINED
	return profile


func _set_calibration(arena: ArenaDefinition, anchors: Array) -> void:
	arena.calibration_cells.clear()
	arena.calibration_pixels.clear()
	for y_value in anchors:
		for x_value in anchors:
			var cell := Vector2i(int(x_value), int(y_value))
			arena.calibration_cells.append(cell)
			arena.calibration_pixels.append(
				arena.grid_origin + arena.axis_x * float(cell.x) + arena.axis_y * float(cell.y)
			)


func _integrate(arena: ArenaDefinition, run_data: RunData, room_index: int, payload: Dictionary) -> void:
	var candidate_result := ArenaDirectTestService.build_candidate(
		arena, run_data, ArenaProductionAttachmentService.UPDATE, room_index
	)
	var proof_candidate := candidate_result.get("candidate") as ArenaDefinition
	var runtime_proof := ArenaDirectTestService.matching_runtime_result(
		proof_candidate, TEST_CONFIGURATION
	) if proof_candidate != null else {}
	if runtime_proof.is_empty():
		payload["error"] = "matching_runtime_proof_missing"
		_finish(false, payload)
		return
	var gate_options := {
		"validation_profile": ArenaIntegrationGatePolicy.Profile.PRODUCTION,
		"manual_test_performed": true,
		"runtime_scene_result": runtime_proof,
		"art_alignment_confirmed": true,
		"publish_draft_gameplay": false,
	}
	var plan := ArenaIntegrationService.plan(
		arena, run_data, ArenaProductionAttachmentService.UPDATE, room_index,
		_destination(arena), null, gate_options
	)
	if not bool(plan.get("ok", false)) or not bool(plan.get("can_integrate", false)):
		payload["error"] = "integration_plan_blocked"
		payload["blocking_errors"] = (plan.get("gate_report", {}) as Dictionary).get("blocking_errors", [])
		_finish(false, payload)
		return
	var result := ArenaIntegrationService.integrate_with_options(
		arena, run_data, ArenaProductionAttachmentService.UPDATE, room_index,
		_destination(arena), null, {}, {"gate_options": gate_options}
	)
	var attachment := result.get("attachment", {}) as Dictionary
	payload["integration_ok"] = bool(result.get("ok", false))
	payload["integration_status"] = str(result.get("status", ""))
	payload["integrated_room_path"] = result.get("integrated_room_path", "")
	payload["gameplay_preserved"] = bool(attachment.get("preserved_gameplay", false))
	_finish(bool(result.get("ok", false)), payload)


func _destination(arena: ArenaDefinition) -> String:
	return ArenaProductionService.DEFAULT_ROOT.path_join(str(arena.arena_id))


func _integer_argument(arguments: PackedStringArray, prefix: String, fallback: int) -> int:
	for argument in arguments:
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix).to_int()
	return fallback


func _finish(success: bool, payload: Dictionary) -> void:
	payload["ok"] = success
	print("CATABASE_ARENA_BUILD=" + JSON.stringify(payload))
	get_tree().quit(0 if success else 1)
