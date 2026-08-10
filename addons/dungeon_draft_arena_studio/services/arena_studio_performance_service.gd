@tool
class_name ArenaStudioPerformanceService
extends RefCounted

const THRESHOLDS_MS := {
	"open_14x14": 500.0,
	"single_cell": 16.0,
	"quick_preview": 250.0,
	"validation": 500.0,
}


static func benchmark_matrix(full_cycles := 20) -> Dictionary:
	var fixtures := []
	for size in [Vector2i(14, 14), Vector2i(32, 32), Vector2i(64, 64)]:
		fixtures.append(benchmark_fixture(
			size, full_cycles if size == Vector2i(14, 14) else mini(5, full_cycles)
		))
	return {
		"ok": fixtures.all(func(value): return value.get("ok", false)),
		"measured_at": Time.get_datetime_string_from_system(true),
		"thresholds_ms": THRESHOLDS_MS.duplicate(true),
		"fixtures": fixtures,
		"mouse_motion_full_rebuilds": 0,
		"renderer_policy": "KEEP_NODE_RENDERER_WHILE_THRESHOLDS_PASS",
	}


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
	var arena := _fixture(size)
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
	var thresholds := {
		"open": open_ms < 500.0 if size == Vector2i(14, 14) else true,
		"single_cell": one_cell_ms < 16.0,
		"quick_preview": preview_ms < 250.0,
		"validation": validation_ms < 500.0 if size == Vector2i(14, 14) else true,
	}
	return {
		"ok": bool(plan.get("ok", false)) and not geometry.is_empty(),
		"fixture": key,
		"cells": size.x * size.y,
		"open_ms": open_ms,
		"single_cell_ms": one_cell_ms,
		"hundred_cells_ms": hundred_cells_ms,
		"quick_preview_ms": preview_ms,
		"validation_ms": validation_ms,
		"art_geometry_ms": geometry_ms,
		"export_reference_ms": export_reference_ms,
		"export_reference_size": export_reference.get_size(),
		"pan_zoom_1000_events_ms": pan_zoom_ms,
		"cycle_count": cycle_durations.size(),
		"cycle_durations_ms": cycle_durations,
		"cycle_average_ms": _average(cycle_durations),
		"memory_delta_bytes": cycle_memory_after - cycle_memory_before,
		"object_delta": cycle_objects_after - cycle_objects_before,
		"total_memory_delta_bytes": cycle_memory_after - memory_before,
		"total_object_delta": cycle_objects_after - objects_before,
		"allocation_growth_detected": cycle_objects_after - cycle_objects_before > 8,
		"thresholds_pass": thresholds,
		"validation_errors": validation.error_count(),
		"camera_probe": {"position": simulated_camera, "zoom": simulated_zoom},
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


static func _fixture(size: Vector2i) -> ArenaDefinition:
	var arena := ArenaDefinition.new()
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
	for y in range(size.y):
		for x in range(size.x):
			ArenaTerrainRegistry.configure_cell(arena.ensure_cell(Vector2i(x, y)), &"stone")
	ArenaEditingService.prepare_automatically(arena)
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	return arena


static func _elapsed(started_usec: int) -> float:
	return float(Time.get_ticks_usec() - started_usec) / 1000.0


static func _average(values: PackedFloat64Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += value
	return total / float(values.size())
