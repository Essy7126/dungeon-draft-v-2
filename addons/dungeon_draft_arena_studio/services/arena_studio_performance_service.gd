@tool
class_name ArenaStudioPerformanceService
extends RefCounted

const THRESHOLDS_MS := {
	"open_14x14": 500.0,
	"single_cell": 16.0,
	"quick_preview": 250.0,
	"validation": 500.0,
}

const REQUIRED_SLO_SIZE := Vector2i(14, 14)
const GATE_REQUIRED_SLO := "required_slo"
const GATE_MEASUREMENT_ONLY := "measurement_only"
const VERDICT_PASS := "PASS"
const VERDICT_FAIL := "FAIL"
const VERDICT_MEASUREMENT_ONLY := "MEASUREMENT_ONLY"
const MEASUREMENT_PHASES := [
	{"id": "open", "metric": "open_ms"},
	{"id": "single_cell", "metric": "single_cell_ms"},
	{"id": "hundred_cells", "metric": "hundred_cells_ms"},
	{"id": "quick_preview", "metric": "quick_preview_ms"},
	{"id": "validation", "metric": "validation_ms"},
	{"id": "art_geometry", "metric": "art_geometry_ms"},
	{"id": "export_reference", "metric": "export_reference_ms"},
	{"id": "pan_zoom_1000_events", "metric": "pan_zoom_1000_events_ms"},
	{"id": "cycle_average", "metric": "cycle_average_ms"},
]


static func benchmark_matrix(full_cycles := 20) -> Dictionary:
	var fixtures: Array[Dictionary] = []
	for size in [Vector2i(14, 14), Vector2i(32, 32), Vector2i(64, 64)]:
		fixtures.append(benchmark_fixture(
			size, full_cycles if size == Vector2i(14, 14) else mini(5, full_cycles)
		))
	var report := {
		"measured_at": Time.get_datetime_string_from_system(true),
		"thresholds_ms": THRESHOLDS_MS.duplicate(true),
		"fixtures": fixtures,
		"mouse_motion_full_rebuilds": 0,
		"renderer_policy": "KEEP_NODE_RENDERER_WHILE_THRESHOLDS_PASS",
	}
	report.merge(derive_matrix_gate(fixtures), true)
	return report


static func benchmark_and_save(
		path := "user://dungeon_draft_studio/tests/performance/benchmark_report.json",
		full_cycles := 20
	) -> Dictionary:
	var report := benchmark_matrix(full_cycles)
	if not path.begins_with("user://dungeon_draft_studio/tests/"):
		return {"ok": false, "error": "benchmark_path_outside_test_root"}
	if DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(path.get_base_dir())
	) != OK:
		return {"ok": false, "error": "benchmark_directory_failed"}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "benchmark_report_write_failed"}
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	report["report_path"] = path
	return report


static func benchmark_fixture(size: Vector2i, cycles := 20) -> Dictionary:
	var memory_before := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var objects_before := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var started := Time.get_ticks_usec()
	var fixture_build := _fixture(size)
	var arena := fixture_build.arena as ArenaDefinition
	var preparation := fixture_build.preparation as Dictionary
	var open_subphases := fixture_build.open_breakdown_ms as Dictionary
	var open_ms := _elapsed(started)
	ArenaTerrainRenderPlanService.clear_cache()
	started = Time.get_ticks_usec()
	var plan := ArenaTerrainRenderPlanService.build(arena)
	var preview_ms := _elapsed(started)
	started = Time.get_ticks_usec()
	ArenaTerrainRegistry.configure_cell(arena.ensure_cell(Vector2i(1, 1)), &"water")
	var one_cell_ms := _elapsed(started)
	started = Time.get_ticks_usec()
	for index in range(mini(100, size.x * size.y)):
		ArenaTerrainRegistry.configure_cell(
			arena.ensure_cell(Vector2i(index % size.x, index / size.x)),
			&"ice" if index % 2 == 0 else &"stone"
		)
	var hundred_cells_ms := _elapsed(started)
	ArenaValidator.clear_cache()
	started = Time.get_ticks_usec()
	var validation := ArenaValidator.validate(arena, false)
	var validation_ms := _elapsed(started)
	ArenaArtProjectionRenderer.clear_geometry_cache()
	started = Time.get_ticks_usec()
	var geometry := ArenaArtProjectionRenderer.geometry_report(arena)
	var geometry_ms := _elapsed(started)
	started = Time.get_ticks_usec()
	var export_reference := ArenaArtProjectionRenderer.render_pass(arena, &"reference_clean")
	var export_reference_ms := _elapsed(started)
	started = Time.get_ticks_usec()
	var simulated_camera := Vector2.ZERO
	var simulated_zoom := 1.0
	for index in range(1000):
		simulated_camera += Vector2(0.125, -0.0625)
		simulated_zoom = clampf(simulated_zoom * 1.00001, 0.1, 4.0)
	var pan_zoom_ms := _elapsed(started)
	var cycle_durations := PackedFloat64Array()
	var cycle_memory_before := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var cycle_objects_before := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	for _cycle in range(maxi(1, cycles)):
		started = Time.get_ticks_usec()
		var clone := ArenaDefinition.new()
		ArenaSnapshotService.restore(clone, ArenaSnapshotService.capture(arena))
		ArenaTerrainRenderPlanService.build(clone)
		cycle_durations.append(_elapsed(started))
		clone = null
	var cycle_memory_after := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var cycle_objects_after := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var key := "%dx%d" % [size.x, size.y]
	var measurements := {
		"open_ms": open_ms,
		"single_cell_ms": one_cell_ms,
		"hundred_cells_ms": hundred_cells_ms,
		"quick_preview_ms": preview_ms,
		"validation_ms": validation_ms,
		"art_geometry_ms": geometry_ms,
		"export_reference_ms": export_reference_ms,
		"pan_zoom_1000_events_ms": pan_zoom_ms,
		"cycle_average_ms": _average(cycle_durations),
	}
	var execution_valid := bool(plan.get("ok", false)) and not geometry.is_empty()
	var report := {
		"fixture": key,
		"cells": size.x * size.y,
		"open_ms": measurements.open_ms,
		"single_cell_ms": measurements.single_cell_ms,
		"hundred_cells_ms": measurements.hundred_cells_ms,
		"quick_preview_ms": measurements.quick_preview_ms,
		"validation_ms": measurements.validation_ms,
		"art_geometry_ms": measurements.art_geometry_ms,
		"export_reference_ms": measurements.export_reference_ms,
		"export_reference_size": export_reference.get_size(),
		"pan_zoom_1000_events_ms": measurements.pan_zoom_1000_events_ms,
		"cycle_count": cycle_durations.size(),
		"cycle_durations_ms": cycle_durations,
		"cycle_average_ms": measurements.cycle_average_ms,
		"memory_delta_bytes": cycle_memory_after - cycle_memory_before,
		"object_delta": cycle_objects_after - cycle_objects_before,
		"total_memory_delta_bytes": cycle_memory_after - memory_before,
		"total_object_delta": cycle_objects_after - objects_before,
		"allocation_growth_detected": cycle_objects_after - cycle_objects_before > 8,
		"validation_errors": validation.error_count(),
		"camera_probe": {"position": simulated_camera, "zoom": simulated_zoom},
	}
	report.merge(derive_fixture_gate(size, measurements, execution_valid), true)
	var phase_breakdown := report.breakdown as Dictionary
	var open_breakdown := phase_breakdown.open as Dictionary
	open_breakdown["runtime_sync_calls"] = int(preparation.get("runtime_sync_calls", 0))
	open_breakdown["grid_data_builds"] = int(preparation.get("grid_data_builds", 0))
	open_breakdown["runtime_projection_reused_for_grid"] = bool(
		preparation.get("runtime_projection_reused_for_grid", false)
	)
	open_breakdown["subphases_ms"] = open_subphases.duplicate(true)
	open_breakdown["unattributed_ms"] = maxf(
		0.0, open_ms - float(open_subphases.get("total", 0.0))
	)
	var preview_breakdown := phase_breakdown.quick_preview as Dictionary
	preview_breakdown["visual_contract_checks"] = int(
		plan.get("visual_contract_checks", 0)
	)
	preview_breakdown["visual_contract_reuses"] = int(
		plan.get("visual_contract_reuses", 0)
	)
	var validation_breakdown := phase_breakdown.validation as Dictionary
	validation_breakdown["derived_inputs"] = (
		validation.metrics.get("derivation_breakdown", {}) as Dictionary
	).duplicate(true)
	return report


static func derive_fixture_gate(
		size: Vector2i,
		measurements: Dictionary,
		execution_valid := true
	) -> Dictionary:
	var budgets := _required_budgets_for(size)
	var measurement_valid := bool(execution_valid)
	var measurement_errors: Array[String] = []
	if not execution_valid:
		measurement_errors.append("execution_invalid")
	var thresholds_pass := {}
	var breakdown := {}
	for phase_value in MEASUREMENT_PHASES:
		var phase := phase_value as Dictionary
		var phase_id := str(phase.id)
		var metric_key := str(phase.metric)
		var raw_measurement: Variant = measurements.get(metric_key, null)
		var has_measurement := (
			measurements.has(metric_key)
			and (raw_measurement is int or raw_measurement is float)
		)
		var measured_ms := float(raw_measurement) if has_measurement else NAN
		var phase_measurement_valid := (
			has_measurement and is_finite(measured_ms) and measured_ms >= 0.0
		)
		if not phase_measurement_valid:
			measurement_valid = false
			measurement_errors.append("invalid_measurement:%s" % metric_key)
		var required_slo := budgets.has(phase_id)
		var budget_ms: Variant = budgets.get(phase_id, null)
		var phase_slo_pass: Variant = null
		if required_slo:
			phase_slo_pass = (
				phase_measurement_valid and measured_ms < float(budget_ms)
			)
			thresholds_pass[phase_id] = phase_slo_pass
		var phase_status := VERDICT_MEASUREMENT_ONLY
		if not phase_measurement_valid:
			phase_status = "INVALID"
		elif required_slo:
			phase_status = VERDICT_PASS if bool(phase_slo_pass) else VERDICT_FAIL
		breakdown[phase_id] = {
			"metric": metric_key,
			"measured_ms": measured_ms if phase_measurement_valid else null,
			"measurement_valid": phase_measurement_valid,
			"required_slo": required_slo,
			"budget_ms": budget_ms,
			"comparison": "<" if required_slo else null,
			"slo_pass": phase_slo_pass,
			"status": phase_status,
		}
	var measurement_only := budgets.is_empty()
	var slo_pass: Variant = null
	if not measurement_only:
		var all_required_slos_pass := thresholds_pass.size() == budgets.size()
		for passed in thresholds_pass.values():
			if passed != true:
				all_required_slos_pass = false
				break
		slo_pass = all_required_slos_pass
	var ok := measurement_valid and (measurement_only or bool(slo_pass))
	var verdict := VERDICT_FAIL
	if measurement_only and measurement_valid:
		verdict = VERDICT_MEASUREMENT_ONLY
	elif ok:
		verdict = VERDICT_PASS
	var measurement_status := "MEASUREMENT_VALID" if measurement_valid else "MEASUREMENT_INVALID"
	var slo_status := "NOT_APPLICABLE"
	if not measurement_only:
		slo_status = "SLO_PASS" if bool(slo_pass) else "SLO_FAIL"
	return {
		"ok": ok,
		"verdict": verdict,
		"gate_mode": GATE_MEASUREMENT_ONLY if measurement_only else GATE_REQUIRED_SLO,
		"measurement_only": measurement_only,
		"execution_valid": bool(execution_valid),
		"measurement_valid": measurement_valid,
		"measurement_status": measurement_status,
		"slo_pass": slo_pass,
		"slo_status": slo_status,
		"required_slo_count": budgets.size(),
		"budgets_ms": budgets,
		"thresholds_pass": thresholds_pass,
		"measurement_errors": measurement_errors,
		"breakdown": breakdown,
	}


static func derive_matrix_gate(fixtures: Array) -> Dictionary:
	var measurement_valid := not fixtures.is_empty()
	var required_slo_fixtures := 0
	var measurement_only_fixtures := 0
	var all_required_slos_pass := true
	var invalid_fixtures: Array[String] = []
	var failed_slo_fixtures: Array[String] = []
	for fixture_value in fixtures:
		if not fixture_value is Dictionary:
			measurement_valid = false
			invalid_fixtures.append("<invalid_fixture>")
			continue
		var fixture := fixture_value as Dictionary
		var fixture_id := str(fixture.get("fixture", "<unknown>"))
		if not bool(fixture.get("measurement_valid", false)):
			measurement_valid = false
			invalid_fixtures.append(fixture_id)
		if bool(fixture.get("measurement_only", false)):
			measurement_only_fixtures += 1
		else:
			required_slo_fixtures += 1
			if fixture.get("slo_pass", null) != true:
				all_required_slos_pass = false
				failed_slo_fixtures.append(fixture_id)
	var slo_pass := required_slo_fixtures > 0 and all_required_slos_pass
	var ok := measurement_valid and slo_pass
	var measurement_status := "MEASUREMENT_VALID" if measurement_valid else "MEASUREMENT_INVALID"
	return {
		"ok": ok,
		"verdict": VERDICT_PASS if ok else VERDICT_FAIL,
		"measurement_valid": measurement_valid,
		"measurement_status": measurement_status,
		"slo_pass": slo_pass,
		"slo_status": "SLO_PASS" if slo_pass else "SLO_FAIL",
		"required_slo_fixtures": required_slo_fixtures,
		"measurement_only_fixtures": measurement_only_fixtures,
		"invalid_fixtures": invalid_fixtures,
		"failed_slo_fixtures": failed_slo_fixtures,
	}


static func reference_graph_measurement(
		graph: StudioReferenceGraphService,
		force := true
	) -> Dictionary:
	if graph == null:
		return {"ok": false, "error": "graph_missing"}
	var report := graph.scan(force)
	return {
		"ok": report.get("ok", false),
		"duration_ms": report.get("duration_ms", 0.0),
		"nodes": report.get("nodes", 0),
		"edges": report.get("edges", 0),
		"memory_delta_bytes": report.get("memory_delta_bytes", 0),
		"object_delta": report.get("object_delta", 0),
		"under_250_ms": report.get("under_ui_threshold", false),
	}


static func _fixture(size: Vector2i) -> Dictionary:
	var total_started: int = Time.get_ticks_usec()
	var phase_started: int = total_started
	var arena := ArenaDefinition.new()
	var definition_construction_ms := _elapsed(phase_started)
	phase_started = Time.get_ticks_usec()
	arena.set_identity("Performance %dx%d" % [size.x, size.y], "performance_%dx%d" % [size.x, size.y])
	arena.visual_mode = ArenaDefinition.VisualMode.MODULAR
	arena.theme_id = &"dynamic_default"
	arena.modular_visual_profile = ArenaModularVisualProfile.new()
	arena.modular_visual_profile.theme_id = arena.theme_id
	arena.source_image_size = Vector2i(1280, 720)
	arena.grid_size = size
	arena.grid_origin = Vector2(640, 48)
	arena.axis_x = Vector2(16, 8)
	arena.axis_y = Vector2(-16, 8)
	var configuration_ms := _elapsed(phase_started)
	phase_started = Time.get_ticks_usec()
	for y in range(size.y):
		for x in range(size.x):
			ArenaTerrainRegistry.configure_cell(arena.ensure_cell(Vector2i(x, y)), &"stone")
	var cell_population_ms := _elapsed(phase_started)
	phase_started = Time.get_ticks_usec()
	var preparation := ArenaEditingService.prepare_automatically(arena)
	var automatic_preparation_ms := _elapsed(phase_started)
	return {
		"arena": arena,
		"preparation": preparation,
		"open_breakdown_ms": {
			"definition_construction": definition_construction_ms,
			"configuration": configuration_ms,
			"cell_population": cell_population_ms,
			"automatic_preparation": automatic_preparation_ms,
			"preparation": (
				preparation.get("breakdown_ms", {}) as Dictionary
			).duplicate(true),
			"total": _elapsed(total_started),
		},
	}


static func _required_budgets_for(size: Vector2i) -> Dictionary:
	# Les tailles 32x32 et 64x64 publient leurs mesures sans inventer de SLO.
	if size != REQUIRED_SLO_SIZE:
		return {}
	return {
		"open": float(THRESHOLDS_MS.open_14x14),
		"single_cell": float(THRESHOLDS_MS.single_cell),
		"quick_preview": float(THRESHOLDS_MS.quick_preview),
		"validation": float(THRESHOLDS_MS.validation),
	}


static func _elapsed(started_usec: int) -> float:
	return float(Time.get_ticks_usec() - started_usec) / 1000.0


static func _average(values: PackedFloat64Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += value
	return total / float(values.size())
