extends SceneTree

const OUTPUT := "res://artifacts/arena_authoring_speed/stroke_baseline.json"
const TERRAIN_IDS: Array[StringName] = [
	&"stone", &"neutral", &"water", &"ice", &"lava", &"poison", &"steam",
	&"electrified_water",
]


func _init() -> void:
	var report := {
		"schema": "arena_stroke_benchmark_v1",
		"phase": "before_batching",
		"measured_at": Time.get_datetime_string_from_system(true),
		"fixture": "14x14",
		"scenarios": [],
		"cause_probe": {},
	}
	for terrain_id in TERRAIN_IDS:
		for count in [1, 10, 50, 100]:
			report.scenarios.append(_measure_linear(terrain_id, count, false))
		report.scenarios.append(_measure_rectangle(terrain_id, Vector2i(10, 10)))
		report.scenarios.append(_measure_fill(terrain_id))
		report.scenarios.append(_measure_linear(terrain_id, 100, true))
	report.cause_probe = _summarize(report.scenarios)
	var output_path := ProjectSettings.globalize_path(OUTPUT)
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		push_error("Impossible d'ecrire %s" % OUTPUT)
		quit(1)
		return
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print(JSON.stringify(report.cause_probe))
	quit(0)


func _fixture(default_id: StringName = &"stone") -> ArenaDefinition:
	var arena := ArenaDefinition.new()
	arena.set_identity("Benchmark peinture", "benchmark_peinture")
	arena.visual_mode = ArenaDefinition.VisualMode.MODULAR
	arena.theme_id = &"dynamic_default"
	arena.modular_visual_profile = ArenaModularVisualProfile.new()
	arena.grid_size = Vector2i(14, 14)
	for y in range(14):
		for x in range(14):
			ArenaTerrainRegistry.configure_cell(arena.ensure_cell(Vector2i(x, y)), default_id)
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	return arena


func _measure_linear(terrain_id: StringName, count: int, repeated: bool) -> Dictionary:
	var arena := _fixture(terrain_id if repeated else &"stone")
	var cells: Array[Vector2i] = []
	for index in range(count):
		cells.append(Vector2i(index % 14, index / 14))
	return _measure(arena, terrain_id, cells, "repeat" if repeated else "stroke")


func _measure_rectangle(terrain_id: StringName, size: Vector2i) -> Dictionary:
	var cells: Array[Vector2i] = []
	for y in range(size.y):
		for x in range(size.x):
			cells.append(Vector2i(x, y))
	return _measure(_fixture(), terrain_id, cells, "rectangle")


func _measure_fill(terrain_id: StringName) -> Dictionary:
	var cells: Array[Vector2i] = []
	for y in range(14):
		for x in range(14):
			cells.append(Vector2i(x, y))
	return _measure(_fixture(), terrain_id, cells, "fill")


func _measure(
		arena: ArenaDefinition,
		terrain_id: StringName,
		cells: Array[Vector2i],
		kind: String
	) -> Dictionary:
	ArenaRuntimeBridge.begin_instrumentation()
	var durations := PackedFloat64Array()
	var changed := 0
	var received := 0
	var duplicates := 0
	var seen := {}
	var started := Time.get_ticks_usec()
	for cell in cells:
		received += 1
		if seen.has(cell):
			duplicates += 1
		seen[cell] = true
		var frame_started := Time.get_ticks_usec()
		if ArenaDynamicEditingService.paint_permanent_terrain(arena, cell, terrain_id):
			changed += 1
		durations.append(float(Time.get_ticks_usec() - frame_started) / 1000.0)
	var total_ms := float(Time.get_ticks_usec() - started) / 1000.0
	var counters := ArenaRuntimeBridge.end_instrumentation()
	return {
		"kind": kind,
		"terrain_id": String(terrain_id),
		"cells_received": received,
		"unique_cells": seen.size(),
		"duplicate_cells": duplicates,
		"cells_changed": changed,
		"total_ms": total_ms,
		"max_cell_ms": _maximum_duration(durations),
		"finalization_ms": 0.0,
		"runtime_sync_calls": int(counters.get("sync_runtime_resources", 0)),
		"grid_data_builds": int(counters.get("grid_data_builds", 0)),
		"pathfinder_builds": int(counters.get("pathfinder_builds", 0)),
		"render_plan_builds": 0,
		"refresh_all_calls": 0,
		"preview_invalidations": received,
		"undo_actions": 1 if changed > 0 else 0,
	}


func _summarize(scenarios: Array) -> Dictionary:
	var hundred := scenarios.filter(func(value):
		return value.kind == "stroke" and int(value.cells_received) == 100
	)
	return {
		"observed_sync_policy": "one sync inside paint_terrain per changed cell",
		"hundred_cell_runtime_sync_min": _minimum(hundred, "runtime_sync_calls"),
		"hundred_cell_runtime_sync_max": _maximum(hundred, "runtime_sync_calls"),
		"hundred_cell_total_ms_min": _minimum(hundred, "total_ms"),
		"hundred_cell_total_ms_max": _maximum(hundred, "total_ms"),
	}


func _minimum(values: Array, key: String) -> float:
	var result := INF
	for value in values:
		result = minf(result, float(value.get(key, 0.0)))
	return 0.0 if is_inf(result) else result


func _maximum(values: Array, key: String) -> float:
	var result := 0.0
	for value in values:
		result = maxf(result, float(value.get(key, 0.0)))
	return result


func _maximum_duration(values: PackedFloat64Array) -> float:
	var result := 0.0
	for value in values:
		result = maxf(result, value)
	return result
