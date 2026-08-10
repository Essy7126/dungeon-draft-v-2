@tool
class_name ArenaProductionReadinessService
extends RefCounted


static func build(
		arena: ArenaDefinition,
		target_bundle_path: String,
		options: Dictionary = {}
	) -> ArenaProductionReadinessCertificate:
	var certificate := ArenaProductionReadinessCertificate.new()
	certificate.generated_at = Time.get_datetime_string_from_system(true)
	certificate.target_bundle_path = target_bundle_path
	certificate.run_path = str(options.get("run_path", ""))
	certificate.room_index = int(options.get("room_index", -1))
	certificate.action = StringName(options.get("action", "NONE"))
	if arena == null:
		certificate.validation_errors.append("arena_missing")
		certificate.recompute_ready()
		return certificate
	certificate.arena_fingerprint = ArenaSnapshotService.arena_fingerprint(arena)
	certificate.gameplay_fingerprint = ArenaSnapshotService.gameplay_fingerprint(arena)
	var render_plan := ArenaTerrainRenderPlanService.build(arena)
	certificate.render_plan_fingerprint = ArenaEditSession.fingerprint(
		_stable_render_plan(render_plan)
	)
	certificate.art_manifest_fingerprint = str(options.get(
		"art_manifest_fingerprint", ""
	))
	var validation := options.get("validation") as ArenaValidationReport
	if validation == null:
		validation = ArenaValidator.validate(arena, false)
	for message in validation.messages:
		if message.severity == ArenaValidationMessage.Severity.ERROR:
			certificate.validation_errors.append(str(message.code))
	certificate.accepted_warnings.assign(options.get("accepted_warnings", []))
	var visual := options.get("visual_report") as ArenaVisualAssemblyReport
	if visual == null:
		visual = ArenaVisualAssembler.inspect(arena)
	certificate.expected_tiles = visual.expected_terrain_cell_count
	certificate.rendered_tiles = visual.rendered_terrain_node_count
	certificate.expected_walls = visual.expected_wall_count
	certificate.rendered_walls = visual.rendered_wall_count
	certificate.duplicate_tiles = int(options.get("duplicate_tiles", 0))
	var runtime_state := ArenaRuntimeProjectionService.build(arena)
	var parity := ArenaRuntimeProjectionService.parity_report(arena, runtime_state)
	var tactical := ArenaTacticalMetricsService.analyze(arena, runtime_state)
	var camps := tactical.get("camps", {}) as Dictionary
	var spawn_metrics := tactical.get("spawns", {}) as Dictionary
	certificate.pathfinding_valid = bool(tactical.get("ok", false)) \
		and int(camps.get("unreachable_pair_count", 1)) == 0
	certificate.spawn_contract_valid = (
		int(spawn_metrics.get("required_hero_spawns", 0)) == 3
		and int(camps.get("enemy_spawn_pool", []).size()) > 0
	)
	certificate.preview_logic_valid = bool(options.get(
		"preview_logic_valid", parity.get("ok", false)
	))
	certificate.preview_art_valid = bool(options.get(
		"preview_art_valid", visual.valid
	))
	certificate.preview_game_valid = bool(options.get(
		"preview_game_valid", parity.get("ok", false)
	))
	var runtime_result = options.get(
		"runtime_test_result", ArenaDirectTestService.load_last_result()
	)
	var current_runtime_result := runtime_result as Dictionary \
		if runtime_result is Dictionary else {}
	var runtime_result_matches := not current_runtime_result.is_empty() \
		and str(current_runtime_result.get("working_fingerprint", "")) \
			== certificate.arena_fingerprint \
		and bool(current_runtime_result.get("fingerprints_identical", false))
	certificate.runtime_test_valid = bool(options.get(
		"runtime_test_valid",
		bool(current_runtime_result.get("ok", false)) \
			if runtime_result_matches else parity.get("ok", false)
	))
	if runtime_result_matches:
		certificate.runtime_test_result_path = ArenaDirectTestService.LAST_RESULT_PATH
		certificate.runtime_test_fingerprint = str(
			current_runtime_result.get("runtime_fingerprint", "")
		)
		certificate.runtime_test_generated_at = str(
			current_runtime_result.get("generated_at", "")
		)
	certificate.art_alignment_confirmed = bool(options.get(
		"art_alignment_confirmed", visual.valid
	))
	var coverage := ArenaRuntimeFieldCoverageService.scan()
	certificate.coverage_gate_valid = bool(coverage.production_gate_valid)
	var destination := ArenaBundleInspectionService.inspect(target_bundle_path)
	certificate.destination_conflict_state = StringName(destination.get("state", "UNKNOWN"))
	certificate.destination_fingerprint = _destination_fingerprint(destination)
	certificate.recompute_ready()
	return certificate


static func remains_valid(certificate: ArenaProductionReadinessCertificate) -> bool:
	if certificate == null:
		return false
	var arena := load(certificate.target_bundle_path.path_join("arena.tres")) \
		as ArenaDefinition if FileAccess.file_exists(
			certificate.target_bundle_path.path_join("arena.tres")
		) else null
	if arena == null:
		return false
	var destination := ArenaBundleInspectionService.inspect(
		certificate.target_bundle_path
	)
	return certificate.matches(arena, _destination_fingerprint(destination))


static func _stable_render_plan(plan: Dictionary) -> Dictionary:
	var entries: Array = []
	for entry in plan.get("entries", []):
		entries.append({
			"cell": entry.get("cell", Vector2i.ZERO),
			"terrain_id": str(entry.get("terrain_id", &"")),
			"texture_path": str(entry.get("texture_path", "")),
			"cell_type": int(entry.get("cell_type", GridData.CellType.HOLE)),
			"polygon": entry.get("polygon", PackedVector2Array()),
			"visible": bool(entry.get("visible", false)),
			"visual_layer": str(entry.get("visual_layer", &"")),
		})
	return {
		"visual_mode": int(plan.get("visual_mode", ArenaDefinition.VisualMode.PAINTED)),
		"floor_policy": int(plan.get(
			"floor_policy", ArenaModularVisualProfile.HybridFloorPolicy.NONE
		)),
		"base_terrain_id": str(plan.get("base_terrain_id", &"")),
		"entries": entries,
	}


static func _destination_fingerprint(inspection: Dictionary) -> String:
	return JSON.stringify({
		"state": str(inspection.get("state", "UNKNOWN")),
		"files": inspection.get("files", {}),
		"foreign_files": inspection.get("foreign_files", []),
		"manifest": inspection.get("manifest", {}),
	}).sha256_text()
