class_name ArenaDirectTestProbe
extends Node

const MAX_FRAMES := 360

var request := {}
var provenance := {}
var elapsed_frames := 0


func configure(request_data: Dictionary, provenance_data: Dictionary) -> void:
	request = request_data.duplicate(true)
	provenance = provenance_data.duplicate(true)
	name = "ArenaDirectTestProbe"
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	elapsed_frames += 1
	var scene := get_tree().current_scene
	if scene != null and _has_property(scene, &"arena_assembly") \
			and _has_property(scene, &"grid"):
		var grid := scene.get(&"grid") as GridData
		var assembly = scene.get(&"arena_assembly")
		if grid != null and assembly is Dictionary \
				and (assembly as Dictionary).get("report") != null:
			_finalize(inspect_runtime_scene(scene, request, provenance))
			return
	if elapsed_frames >= MAX_FRAMES:
		var timeout_result := provenance.duplicate(true)
		timeout_result.merge({
			"ok": false,
			"runtime_scene_inspected": false,
			"error": "runtime_scene_timeout",
		}, true)
		_finalize(timeout_result)


static func inspect_runtime_scene(
		scene: Node,
		request_data: Dictionary,
		provenance_data: Dictionary
	) -> Dictionary:
	var result := provenance_data.duplicate(true)
	var assembly := scene.get(&"arena_assembly") as Dictionary
	var report := assembly.get("report") as ArenaVisualAssemblyReport
	var floor_layers := _nodes_named(scene, &"ArenaTilesLayer")
	var terrain_renderers := _terrain_renderers(scene)
	var floor_nodes := 0
	var misplaced_floor_nodes := 0
	var floor_y_sort_valid := true
	var rendered_floor_cells: Array[String] = []
	var duplicate_cells: Array[String] = []
	for layer_value in floor_layers:
		var layer := layer_value as Node2D
		if layer == null:
			continue
		floor_y_sort_valid = floor_y_sort_valid and not layer.y_sort_enabled
		for child in layer.get_children():
			if child.has_meta("arena_cell"):
				floor_nodes += 1
	for renderer_value in terrain_renderers:
		var renderer := renderer_value as ArenaTerrainVisualRenderer
		if renderer == null:
			continue
		var renderer_report := renderer.actual_render_report()
		for key in (renderer_report.get("cells", {}) as Dictionary):
			var cell_entry := (
				renderer_report.get("cells", {}) as Dictionary
			)[key] as Dictionary
			if str(cell_entry.get("renderer_role", "")) == "arena_floor":
				rendered_floor_cells.append(str(key))
				if int(cell_entry.get("duplication_count", 1)) > 1:
					duplicate_cells.append(str(key))
			var parent_name := str((cell_entry as Dictionary).get("parent", ""))
			if str(cell_entry.get("renderer_role", "")) == "arena_floor" \
					and parent_name != "ArenaTilesLayer":
				misplaced_floor_nodes += 1
	rendered_floor_cells = ArenaTopologySignatureService.normalized_keys(
		rendered_floor_cells
	)

	var options := scene.get(&"_direct_test_options") as Dictionary
	var requested_configuration := str(request_data.get("configuration", ""))
	var configuration_consumed := (
		str(options.get("configuration", "")) == requested_configuration
	)
	var camera_mode := str(options.get("camera_mode", ""))
	var camera := scene.get(&"camera") as Camera2D
	var room := scene.get(&"room_data") as ArenaDefinition
	var runtime_fingerprint := (
		ArenaSnapshotService.arena_fingerprint(room) if room != null else ""
	)
	var working_fingerprint := str(request_data.get("working_fingerprint", ""))
	var temporary_fingerprint := str(request_data.get("temporary_fingerprint", ""))
	var fingerprints_identical := not working_fingerprint.is_empty() \
		and working_fingerprint == temporary_fingerprint \
		and working_fingerprint == runtime_fingerprint
	var expected_tiles := report.expected_terrain_cell_count if report != null else 0
	var rendered_tiles := report.rendered_terrain_node_count if report != null else 0
	var duplicate_tiles := report.duplicate_terrain_node_count if report != null else -1
	var expected_renderer_count := 1 if expected_tiles > 0 else 0
	var produced_not_loaded := not bool(
		provenance_data.get("produced_bundle_loaded", true)
	)
	var expected_floor_cells := ArenaTopologySignatureService.normalized_keys(
		request_data.get(
			"expected_floor_cells",
			(report.terrain_nodes as Dictionary).keys() if report != null else []
		)
	)
	var removed_cells := ArenaTopologySignatureService.normalized_keys(
		request_data.get("removed_cells", [])
	)
	var floor_parity := ArenaTopologyParityReport.compare_floor_sets(
		expected_floor_cells, rendered_floor_cells, removed_cells, duplicate_cells
	)
	var runtime_topology := ArenaTopologySignatureService.build(room)
	var requested_topology_hash := str(request_data.get("working_topology_hash", ""))
	var topology_hashes_identical: bool = int(request_data.get("contract_version", 0)) < 3 \
		or (not requested_topology_hash.is_empty() \
			and requested_topology_hash == runtime_topology.topology_hash \
			and bool(provenance_data.get("topology_hashes_identical", false)))
	var debug_reports: Array[Dictionary] = []
	var debug_filled_cells: Array[String] = []
	for grid_view_value in _painted_grid_views(scene):
		var painted := grid_view_value as PaintedGridView
		var debug_report := painted.render_option_report()
		debug_reports.append(debug_report)
		debug_filled_cells.append_array(debug_report.filled_cells)
	debug_filled_cells = ArenaTopologySignatureService.normalized_keys(
		debug_filled_cells
	)
	var removed_debug_fills := ArenaTopologySignatureService.intersection(
		removed_cells, debug_filled_cells
	)
	var representations := _scene_representations(scene)
	var scene_tree_valid := floor_layers.size() == 1 \
		and terrain_renderers.size() == expected_renderer_count \
		and floor_y_sort_valid \
		and misplaced_floor_nodes == 0 \
		and expected_tiles == rendered_tiles \
		and floor_nodes == rendered_tiles \
		and duplicate_tiles == 0 \
		and floor_parity.valid \
		and removed_debug_fills.is_empty()
	result.merge({
		"ok": scene_tree_valid and configuration_consumed \
			and camera_mode == "STUDIO_MATCH" and fingerprints_identical \
			and produced_not_loaded and camera != null \
			and topology_hashes_identical,
		"runtime_scene_inspected": true,
		"scene_path": scene.scene_file_path,
		"scene_script": (
			scene.get_script().resource_path if scene.get_script() != null else ""
		),
		"floor_layer_count": floor_layers.size(),
		"floor_renderer_count": terrain_renderers.size(),
		"expected_floor_renderer_count": expected_renderer_count,
		"floor_y_sort_valid": floor_y_sort_valid,
		"floor_node_count": floor_nodes,
		"expected_tile_count": expected_tiles,
		"rendered_tile_count": rendered_tiles,
		"expected_floor_cells": expected_floor_cells,
		"rendered_floor_cells": rendered_floor_cells,
		"expected_floor_hash": floor_parity.expected_floor_hash,
		"rendered_floor_hash": floor_parity.rendered_floor_hash,
		"missing_cells": floor_parity.missing_cells,
		"unexpected_cells": floor_parity.unexpected_cells,
		"removed_cells_rendered": floor_parity.removed_cells_rendered,
		"duplicate_cells": floor_parity.duplicate_cells,
		"duplicate_tile_count": duplicate_tiles,
		"misplaced_floor_node_count": misplaced_floor_nodes,
		"configuration_consumed": configuration_consumed,
		"camera_mode": camera_mode,
		"camera_position": camera.position if camera != null else Vector2.ZERO,
		"camera_zoom": camera.zoom if camera != null else Vector2.ZERO,
		"runtime_fingerprint": runtime_fingerprint,
		"fingerprints_identical": fingerprints_identical,
		"runtime_topology_hash": runtime_topology.topology_hash,
		"topology_hashes_identical": topology_hashes_identical,
		"runtime_hole_cells": ArenaRuntimeBridge.runtime_signature(room).get(
			"runtime_hole_cells", []
		) if room != null else [],
		"debug_layer_reports": debug_reports,
		"debug_filled_cells": debug_filled_cells,
		"removed_debug_fills": removed_debug_fills,
		"scene_tree_representations": representations,
		"produced_bundle_loaded": not produced_not_loaded,
		"visual_report": report.to_dict() if report != null else {},
	}, true)
	return result


func _finalize(result: Dictionary) -> void:
	var result_path := str(request.get(
		"result_path", ArenaDirectTestService.LAST_RESULT_PATH
	))
	var absolute := ProjectSettings.globalize_path(result_path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var file := FileAccess.open(result_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(result, "  "))
		file.close()
	var console_result := result.duplicate(true)
	console_result.erase("visual_report")
	print("ARENA_STUDIO_RUNTIME_PROBE ", JSON.stringify(console_result))
	if bool(request.get("cleanup_on_load", false)):
		ArenaDirectTestService.cleanup_context(request)
	queue_free()


static func _nodes_named(root: Node, wanted_name: StringName) -> Array[Node]:
	var result: Array[Node] = []
	if root.name == wanted_name:
		result.append(root)
	for child in root.get_children():
		result.append_array(_nodes_named(child, wanted_name))
	return result


static func _terrain_renderers(root: Node) -> Array[Node]:
	var result: Array[Node] = []
	if root is ArenaTerrainVisualRenderer \
			and StringName(root.get_meta("renderer_role", &"arena_floor")) == &"arena_floor":
		result.append(root)
	for child in root.get_children():
		result.append_array(_terrain_renderers(child))
	return result


static func _painted_grid_views(root: Node) -> Array[Node]:
	var result: Array[Node] = []
	if root is PaintedGridView:
		result.append(root)
	for child in root.get_children():
		result.append_array(_painted_grid_views(child))
	return result


static func _scene_representations(root: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if root.has_meta("arena_cell") or root.has_meta("grid_cell"):
		var cell = root.get_meta(
			"arena_cell", root.get_meta("grid_cell", GridTransformService.INVALID_CELL)
		)
		if cell is Vector2i:
			result.append({
				"cell": ArenaTopologySignatureService.coordinate_key(cell),
				"node_path": str(root.get_path()),
				"node_class": root.get_class(),
				"renderer_role": str(root.get_meta("renderer_role", "")),
				"renderer_layer": str(root.get_meta("renderer_layer", "")),
				"visible": bool(root.get("visible")) \
					if root is CanvasItem else true,
			})
	for child in root.get_children():
		result.append_array(_scene_representations(child))
	return result


static func _has_property(object: Object, property_name: StringName) -> bool:
	for property in object.get_property_list():
		if StringName(property.name) == property_name:
			return true
	return false
