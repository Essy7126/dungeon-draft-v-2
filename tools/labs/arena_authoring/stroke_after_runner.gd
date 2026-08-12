extends SceneTree

const OUTPUT := "res://artifacts/arena_authoring_speed/stroke_after.json"
const TERRAIN_IDS: Array[StringName] = [
	&"stone", &"neutral", &"water", &"ice", &"lava", &"poison", &"steam",
	&"electrified_water",
]


func _init() -> void:
	var scenarios := []
	for terrain_id in TERRAIN_IDS:
		for count in [1, 10, 50, 100]:
			scenarios.append(_measure(_fixture(14), terrain_id, _linear(count, 14), "stroke"))
		scenarios.append(_measure(
			_fixture(14), terrain_id,
			ArenaStrokeBatchService.rectangle_cells(Vector2i.ZERO, Vector2i(9, 9)),
			"rectangle"
		))
		scenarios.append(_measure(_fixture(14), terrain_id, _linear(196, 14), "fill"))
		scenarios.append(_measure(
			_fixture(14, terrain_id), terrain_id, _linear(100, 14), "repeat"
		))
	var stress := _measure(_fixture(32), &"water", _linear(200, 32), "stress_32x32")
	var report := {
		"schema": "arena_stroke_benchmark_v1",
		"phase": "after_batching",
		"measured_at": Time.get_datetime_string_from_system(true),
		"fixture": "14x14 plus 32x32 stress",
		"scenarios": scenarios,
		"stress": stress,
		"summary": _summarize(scenarios, stress),
	}
	var output_path := ProjectSettings.globalize_path(OUTPUT)
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print(JSON.stringify(report.summary))
	quit(0)


func _fixture(size: int, default_id: StringName = &"stone") -> ArenaDefinition:
	var arena := ArenaDefinition.new()
	arena.set_identity("Benchmark batching", "benchmark_batching")
	arena.visual_mode = ArenaDefinition.VisualMode.MODULAR
	arena.theme_id = &"dynamic_default"
	arena.modular_visual_profile = ArenaModularVisualProfile.new()
	arena.grid_size = Vector2i(size, size)
	for y in range(size):
		for x in range(size):
			ArenaTerrainRegistry.configure_cell(arena.ensure_cell(Vector2i(x, y)), default_id)
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	return arena


func _linear(count: int, width: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for index in range(count):
		result.append(Vector2i(index % width, index / width))
	return result


func _measure(
		arena: ArenaDefinition,
		terrain_id: StringName,
		cells: Array[Vector2i],
		kind: String
	) -> Dictionary:
	ArenaRuntimeBridge.begin_instrumentation()
	var batch := ArenaStrokeBatchService.new()
	batch.begin_stroke(arena)
	var mutation_started := Time.get_ticks_usec()
	var changed := batch.apply_terrain_cells(cells, terrain_id)
	var mutation_ms := float(Time.get_ticks_usec() - mutation_started) / 1000.0
	var result := batch.finish()
	var counters := ArenaRuntimeBridge.end_instrumentation()
	return {
		"kind": kind,
		"terrain_id": String(terrain_id),
		"cells_received": cells.size(),
		"cells_changed": changed.size(),
		"duplicate_cells": int(result.get("duplicate_cell_count", 0)),
		"mutation_ms": mutation_ms,
		"finalization_ms": float(result.get("finalization_ms", 0.0)),
		"total_ms": float(result.get("total_ms", 0.0)),
		"runtime_sync_calls": int(counters.get("sync_runtime_resources", 0)),
		"grid_data_builds": int(counters.get("grid_data_builds", 0)),
		"pathfinder_builds": int(counters.get("pathfinder_builds", 0)),
		"render_plan_builds": 0,
		"refresh_all_calls": 1 if not changed.is_empty() else 0,
		"preview_invalidations": 1 if not changed.is_empty() else 0,
		"undo_actions": 1 if not changed.is_empty() else 0,
	}


func _summarize(scenarios: Array, stress: Dictionary) -> Dictionary:
	var hundred := scenarios.filter(func(value):
		return value.kind == "stroke" and int(value.cells_received) == 100
	)
	var fifty := scenarios.filter(func(value):
		return value.kind == "stroke" and int(value.cells_received) == 50
	)
	return {
		"hundred_cell_runtime_sync_max": _maximum(hundred, "runtime_sync_calls"),
		"hundred_cell_finalization_ms_max": _maximum(hundred, "finalization_ms"),
		"fifty_cell_mutation_ms_max": _maximum(fifty, "mutation_ms"),
		"stress_200_finalization_ms": stress.finalization_ms,
		"runtime_sync_contract_pass": _maximum(hundred, "runtime_sync_calls") <= 1.0,
		"hundred_finalization_contract_pass": _maximum(hundred, "finalization_ms") < 150.0,
		"stress_finalization_contract_pass": float(stress.finalization_ms) < 300.0,
	}


func _maximum(values: Array, key: String) -> float:
	var result := 0.0
	for value in values:
		result = maxf(result, float(value.get(key, 0.0)))
	return result
