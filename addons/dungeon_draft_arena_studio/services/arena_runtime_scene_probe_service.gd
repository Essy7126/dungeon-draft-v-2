@tool
class_name ArenaRuntimeSceneProbeService
extends RefCounted

## Read-only inspector for the real battle SceneTree used by Arena Studio.
## It never instantiates canonical resources and never advances a run.

const PRODUCED_PREFIX := "res://data/arenas/produced/"


static func is_ready_for_inspection(scene: Node) -> bool:
	if scene == null:
		return false
	if _has_property(scene, &"runtime_ready_state"):
		return bool(scene.get(&"runtime_ready_state"))
	# Compatibility for small in-memory fixtures and pre-contract battle scenes.
	var grid_value: Variant = _property(scene, &"grid", null)
	var assembly_value: Variant = _property(scene, &"arena_assembly", {})
	return grid_value is GridData \
		and assembly_value is Dictionary \
		and (assembly_value as Dictionary).get("report") != null


static func inspect(
		scene: Node,
		request_data: Dictionary = {},
		provenance_data: Dictionary = {}
	) -> Dictionary:
	var started_usec := Time.get_ticks_usec()
	var result := provenance_data.duplicate(true)
	var errors: Array[Dictionary] = []
	var warnings: Array[Dictionary] = []
	if scene == null:
		_add_diagnostic(
			errors, &"SCENE_NOT_INSTANTIATED", &"scene",
			"La scène de combat n'a pas ete instanciee."
		)
		result.merge({
			"ok": false,
			"runtime_scene_inspected": false,
			"battle_scene_path": "",
			"script_parse_ok": false,
			"scene_instantiated": false,
			"runtime_ready": false,
			"grid_ready": false,
			"pathfinder_ready": false,
			"render_ready": false,
			"spawn_ready": false,
			"produced_bundle_loaded": bool(
				provenance_data.get("produced_bundle_loaded", false)
			),
			"errors": errors,
			"warnings": warnings,
			"duration_ms": float(Time.get_ticks_usec() - started_usec) / 1000.0,
		}, true)
		return result

	var scene_script := scene.get_script() as Script
	var script_parse_ok := scene_script != null and scene_script.can_instantiate()
	var actual_scene_path := scene.scene_file_path
	var room := _property(scene, &"room_data", null) as ArenaDefinition
	var expected_scene_path := str(request_data.get(
		"expected_battle_scene_path", request_data.get("battle_scene_path", "")
	))
	if expected_scene_path.is_empty() and room != null and room.battle_scene != null:
		expected_scene_path = room.battle_scene.resource_path
	var scene_exact := actual_scene_path.is_empty() \
		or expected_scene_path.is_empty() \
		or actual_scene_path == expected_scene_path
	if actual_scene_path.is_empty():
		_add_diagnostic(
			warnings, &"SCENE_PATH_UNAVAILABLE", &"scene",
			"La fixture en memoire ne porte pas de scene_file_path."
		)

	var runtime_ready := is_ready_for_inspection(scene)
	var strict_runtime_contract := bool(
		request_data.get("require_runtime_ready", false)
	) or _has_property(scene, &"runtime_ready_state")
	var grid := _property(scene, &"grid", null) as GridData
	var grid_ready := grid != null
	var pathfinder_value: Variant = _property(scene, &"pathfinder", null)
	var pathfinder_ready := pathfinder_value is Pathfinder

	var assembly_value: Variant = _property(scene, &"arena_assembly", {})
	var assembly: Dictionary = (
		assembly_value as Dictionary if assembly_value is Dictionary else {}
	)
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
		var renderer_cells := renderer_report.get("cells", {}) as Dictionary
		for key in renderer_cells:
			var cell_entry := renderer_cells[key] as Dictionary
			if str(cell_entry.get("renderer_role", "")) == "arena_floor":
				rendered_floor_cells.append(str(key))
				if int(cell_entry.get("duplication_count", 1)) > 1:
					duplicate_cells.append(str(key))
			var parent_name := str(cell_entry.get("parent", ""))
			if str(cell_entry.get("renderer_role", "")) == "arena_floor" \
					and parent_name != "ArenaTilesLayer":
				misplaced_floor_nodes += 1
	rendered_floor_cells = ArenaTopologySignatureService.normalized_keys(
		rendered_floor_cells
	)

	var options_value: Variant = _property(scene, &"_direct_test_options", {})
	var options: Dictionary = (
		options_value as Dictionary if options_value is Dictionary else {}
	)
	var requested_configuration := str(request_data.get("configuration", ""))
	var configuration_consumed := (
		str(options.get("configuration", "")) == requested_configuration
	)
	var camera_mode := str(options.get("camera_mode", ""))
	var camera := _property(scene, &"camera", null) as Camera2D
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
	var produced_bundle_loaded := _depends_on_produced_bundle(
		room, request_data, provenance_data
	)
	var illustration_required := bool(request_data.get(
		"illustration_required",
		room != null and room.visual_mode != ArenaDefinition.VisualMode.MODULAR
	))
	var illustration_loaded := false
	if room != null:
		var runtime_state := ArenaRuntimeBridge.build_runtime_projection(room)
		illustration_loaded = runtime_state != null \
			and runtime_state.painted_map_visual_data != null \
			and runtime_state.painted_map_visual_data.load_background_texture() != null
	var expected_encounter_path := str(request_data.get("encounter_path", ""))
	var loaded_encounter_path := room.encounter_definition.resource_path \
		if room != null and room.encounter_definition != null else ""
	var encounter_preserved_and_loaded := (
		bool(request_data.get("gameplay_preserved", false))
		and not expected_encounter_path.is_empty()
		and loaded_encounter_path == expected_encounter_path
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
	var requested_topology_hash := str(
		request_data.get("working_topology_hash", "")
	)
	var topology_hashes_identical: bool = int(
		request_data.get("contract_version", 0)
	) < 3 or (
		not requested_topology_hash.is_empty() \
		and requested_topology_hash == str(runtime_topology.topology_hash) \
		and bool(provenance_data.get("topology_hashes_identical", false))
	)
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
	var render_ready := floor_layers.size() == 1 \
		and terrain_renderers.size() == expected_renderer_count \
		and floor_y_sort_valid \
		and misplaced_floor_nodes == 0 \
		and expected_tiles == rendered_tiles \
		and floor_nodes == rendered_tiles \
		and duplicate_tiles == 0 \
		and floor_parity.valid \
		and removed_debug_fills.is_empty()

	var spawn_report := _spawn_report(scene, options)
	var spawn_ready := bool(spawn_report.get("ready", false))
	if not script_parse_ok:
		_add_diagnostic(
			errors, &"SCRIPT_PARSE_FAILED", &"script",
			"Le script de la scène runtime n'est pas instanciable."
		)
	if not scene_exact:
		_add_diagnostic(
			errors, &"BATTLE_SCENE_MISMATCH", &"scene",
			"La scène runtime chargee n'est pas celle declaree par l'arène.",
			{"expected": expected_scene_path, "actual": actual_scene_path}
		)
	if strict_runtime_contract and not runtime_ready:
		_add_diagnostic(
			errors, &"RUNTIME_NOT_READY", &"runtime",
			"La scène n'a pas publié son état de disponibilité différé."
		)
	if not grid_ready:
		_add_diagnostic(
			errors, &"GRID_NOT_READY", &"grid",
			"GridData n'est pas disponible dans la scène runtime."
		)
	if strict_runtime_contract and not pathfinder_ready:
		_add_diagnostic(
			errors, &"PATHFINDER_NOT_READY", &"pathfinder",
			"Pathfinder n'est pas disponible dans la scène runtime."
		)
	if not render_ready:
		_add_diagnostic(
			errors, &"RENDER_NOT_READY", &"render",
			"Le rendu du sol ne respecte pas le contrat de topologie.",
			{
				"floor_layer_count": floor_layers.size(),
				"renderer_count": terrain_renderers.size(),
				"expected_tiles": expected_tiles,
				"rendered_tiles": rendered_tiles,
			}
		)
	if strict_runtime_contract and not spawn_ready:
		_add_diagnostic(
			errors, &"SPAWN_NOT_READY", &"spawn",
			"Les personnages demandes ne sont pas prets dans la scène runtime.",
			spawn_report
		)
	if produced_bundle_loaded:
		_add_diagnostic(
			errors, &"PRODUCED_BUNDLE_LOADED", &"provenance",
			"La sonde de jeu a détecté une dépendance au dossier de production figé."
		)
	if illustration_required and not illustration_loaded:
		_add_diagnostic(
			errors, &"ILLUSTRATION_NOT_LOADED", &"render",
			"L'illustration peinte ou hybride n'a pas produit de Texture2D runtime."
		)
	if requested_configuration == "real_encounter" \
			and bool(request_data.get("gameplay_preserved", false)) \
			and not encounter_preserved_and_loaded:
		_add_diagnostic(
			errors, &"PRESERVED_ENCOUNTER_NOT_LOADED", &"encounter",
			"La rencontre conservée par UPDATE n'est pas celle chargée par le combat.",
			{"expected": expected_encounter_path, "actual": loaded_encounter_path}
		)

	var legacy_contract_valid := render_ready and configuration_consumed \
		and camera_mode == "STUDIO_MATCH" and fingerprints_identical \
		and not produced_bundle_loaded and camera != null \
		and topology_hashes_identical
	var runtime_contract_valid := not strict_runtime_contract or (
		runtime_ready and pathfinder_ready and spawn_ready
	)
	result.merge({
		"ok": errors.is_empty() and legacy_contract_valid \
			and runtime_contract_valid and grid_ready and scene_exact,
		"probe_pending": false,
		"runtime_scene_inspected": true,
		"configuration": requested_configuration,
		"runtime_probe_key": str(request_data.get("runtime_probe_key", "")),
		"battle_scene_path": actual_scene_path,
		"expected_battle_scene_path": expected_scene_path,
		"scene_path": actual_scene_path,
		"scene_exact": scene_exact,
		"scene_script": scene_script.resource_path if scene_script != null else "",
		"script_parse_ok": script_parse_ok,
		"scene_instantiated": true,
		"runtime_ready": runtime_ready,
		"runtime_contract_enforced": strict_runtime_contract,
		"grid_ready": grid_ready,
		"pathfinder_ready": pathfinder_ready,
		"render_ready": render_ready,
		"spawn_ready": spawn_ready,
		"spawn_report": spawn_report,
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
		"illustration_required": illustration_required,
		"illustration_loaded": illustration_loaded,
		"gameplay_preserved": bool(request_data.get("gameplay_preserved", false)),
		"expected_encounter_path": expected_encounter_path,
		"loaded_encounter_path": loaded_encounter_path,
		"encounter_preserved_and_loaded": encounter_preserved_and_loaded,
		"canonical_sources_unchanged": bool(request_data.get(
			"canonical_sources_unchanged", false
		)),
		"camera_mode": camera_mode,
		"camera_position": camera.position if camera != null else Vector2.ZERO,
		"camera_zoom": camera.zoom if camera != null else Vector2.ZERO,
		"runtime_fingerprint": runtime_fingerprint,
		"fingerprints_identical": fingerprints_identical,
		"runtime_topology_hash": str(runtime_topology.topology_hash),
		"topology_hashes_identical": topology_hashes_identical,
		"runtime_hole_cells": ArenaRuntimeBridge.runtime_signature(room).get(
			"runtime_hole_cells", []
		) if room != null else [],
		"debug_layer_reports": debug_reports,
		"debug_filled_cells": debug_filled_cells,
		"removed_debug_fills": removed_debug_fills,
		"scene_tree_representations": representations,
		"produced_bundle_loaded": produced_bundle_loaded,
		"visual_report": report.to_dict() if report != null else {},
		"errors": errors,
		"warnings": warnings,
		"duration_ms": float(Time.get_ticks_usec() - started_usec) / 1000.0,
	}, true)
	return result


static func _spawn_report(scene: Node, options: Dictionary) -> Dictionary:
	var heroes_requested := bool(options.get("spawn_heroes", false))
	var enemies_requested := bool(options.get("spawn_enemies", false))
	var deployment_enabled := bool(options.get("deployment_enabled", false))
	var units_value: Variant = _property(scene, &"units", [])
	var hero_count := 0
	var enemy_count := 0
	if units_value is Array:
		for value in units_value:
			var unit := value as Unit
			if unit == null:
				continue
			if unit.team == 0:
				hero_count += 1
			elif unit.team == 1:
				enemy_count += 1
	var deployment_value: Variant = _property(scene, &"_deployment", null)
	var deployment_ready := deployment_enabled and deployment_value != null
	var heroes_ready := not heroes_requested or hero_count > 0 or deployment_ready
	var enemies_ready := not enemies_requested or enemy_count > 0
	return {
		"ready": heroes_ready and enemies_ready,
		"heroes_requested": heroes_requested,
		"enemies_requested": enemies_requested,
		"deployment_enabled": deployment_enabled,
		"deployment_ready": deployment_ready,
		"hero_count": hero_count,
		"enemy_count": enemy_count,
		"heroes_ready": heroes_ready,
		"enemies_ready": enemies_ready,
	}


static func _depends_on_produced_bundle(
		room: ArenaDefinition,
		request_data: Dictionary,
		provenance_data: Dictionary
	) -> bool:
	if bool(provenance_data.get("produced_bundle_loaded", false)):
		return true
	var paths: Array[String] = []
	for value in [
		request_data.get("arena_path", ""),
		provenance_data.get("arena_path_loaded", ""),
		room.resource_path if room != null else "",
	]:
		var path := str(value)
		if not path.is_empty() and not paths.has(path):
			paths.append(path)
	for path in paths:
		if path.begins_with(PRODUCED_PREFIX):
			return true
		if not ResourceLoader.exists(path):
			continue
		for dependency in ResourceLoader.get_dependencies(path):
			if str(dependency).contains(PRODUCED_PREFIX):
				return true
	return false


static func _add_diagnostic(
		target: Array[Dictionary],
		code: StringName,
		domain: StringName,
		message: String,
		details: Dictionary = {}
	) -> void:
	target.append({
		"code": code,
		"domain": domain,
		"message": message,
		"details": details.duplicate(true),
	})


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
			and StringName(root.get_meta(
				"renderer_role", &"arena_floor"
			)) == &"arena_floor":
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
		var cell: Variant = root.get_meta(
			"arena_cell",
			root.get_meta("grid_cell", GridTransformService.INVALID_CELL)
		)
		if cell is Vector2i:
			result.append({
				"cell": ArenaTopologySignatureService.coordinate_key(cell),
				"node_path": str(root.get_path()),
				"node_class": root.get_class(),
				"renderer_role": str(root.get_meta("renderer_role", "")),
				"renderer_layer": str(root.get_meta("renderer_layer", "")),
				"visible": bool(root.get("visible")) if root is CanvasItem else true,
			})
	for child in root.get_children():
		result.append_array(_scene_representations(child))
	return result


static func _property(
		object: Object,
		property_name: StringName,
		fallback: Variant
	) -> Variant:
	if object == null or not _has_property(object, property_name):
		return fallback
	return object.get(property_name)


static func _has_property(object: Object, property_name: StringName) -> bool:
	if object == null:
		return false
	for property in object.get_property_list():
		if StringName(property.name) == property_name:
			return true
	return false
