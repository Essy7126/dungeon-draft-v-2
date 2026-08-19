@tool
class_name ArenaVisualAssembler
extends RefCounted

static var _inspection_cache := {}

const WALL_SCENE := preload("res://tools/labs/dynamic_arena/DynamicWall.tscn")


static func assemble(
		arena: ArenaDefinition,
		grid: GridData,
		pathfinder: Pathfinder,
		grid_view: Node2D,
		y_sorted_world: Node2D,
		owner: Node,
		include_modular_tiles := true,
		floor_parent: Node2D = null,
		prepared_render_plan: Dictionary = {},
		prepared_visual_data: PaintedMapVisualData = null
	) -> Dictionary:
	var result := {
		"ok": false,
		"renderer": null,
		"interactive_renderer": null,
		"interactive_parent": null,
		"blocker_service": null,
		"walls": [],
		"decorations": [],
		"terrain_cells": {},
		"render_plan": {},
		"report": null,
		"floor_parent": null,
	}
	if arena == null or grid == null or pathfinder == null or grid_view == null \
			or y_sorted_world == null or owner == null:
		return result
	var render_plan := prepared_render_plan \
		if not prepared_render_plan.is_empty() \
		else ArenaTerrainRenderPlanService.build(arena)
	result.render_plan = render_plan
	var report := ArenaVisualAssemblyReport.new()
	report.visual_mode = arena.visual_mode
	report.floor_policy = int(render_plan.floor_policy)
	report.base_floor_intentionally_painted = bool(
		render_plan.base_floor_intentionally_painted
	)
	report.expected_terrain_cell_count = int(render_plan.expected_terrain_cell_count)
	report.expected_by_terrain_id = render_plan.expected_by_terrain_id.duplicate(true)
	report.skipped_cells = render_plan.skipped_cells.duplicate(true)
	report.skip_reasons = render_plan.skip_reasons.duplicate(true)
	report.errors.assign(render_plan.errors)
	report.warnings.assign(render_plan.warnings)
	for error in render_plan.errors:
		if str(error).begins_with("texture_missing"):
			report.missing_terrain_assets.append(str(error))
	result.report = report
	var terrain_cells := {}
	for entry in render_plan.render_entries:
		terrain_cells[entry.cell] = entry.terrain_id
	result.terrain_cells = terrain_cells
	var resolved_floor_parent := floor_parent
	if resolved_floor_parent == null:
		resolved_floor_parent = Node2D.new()
		resolved_floor_parent.name = "ArenaTilesLayer"
		resolved_floor_parent.y_sort_enabled = false
		owner.add_child(resolved_floor_parent)
	result.floor_parent = resolved_floor_parent
	if include_modular_tiles and not render_plan.render_entries.is_empty():
		var renderer := ArenaTerrainVisualRenderer.new()
		# Nom historique conserve pour les smoke tests et les outils qui cherchaient
		# cette couche, la classe et les metadonnees exposent le nouveau contrat.
		renderer.name = "ArenaFeatureRenderer"
		renderer.set_meta("renderer_role", &"arena_floor")
		owner.add_child(renderer)
		renderer.configure(grid_view, resolved_floor_parent)
		renderer.render_plan(render_plan)
		result.renderer = renderer
		var actual := renderer.actual_render_report()
		report.rendered_terrain_node_count = int(actual.rendered_terrain_node_count)
		report.rendered_by_terrain_id = actual.rendered_by_terrain_id.duplicate(true)
		report.terrain_nodes = actual.cells.duplicate(true)
		for terrain_entry in actual.cells.values():
			report.duplicate_terrain_node_count += maxi(
				0, int(terrain_entry.get("duplication_count", 1)) - 1
			)
		report.errors.append_array(actual.errors)
	var vortex_catalog := ArenaCatalogService.interactive(&"vortex")
	if vortex_catalog != null and vortex_catalog.texture != null \
			and (not arena.vortex_pairs.is_empty() or not arena.vortex_networks.is_empty()):
		var interactive_parent := Node2D.new()
		interactive_parent.name = "ArenaInteractivesLayer"
		interactive_parent.y_sort_enabled = false
		interactive_parent.set_meta("visual_layer", &"arena_spatial_interactive")
		owner.add_child(interactive_parent)
		result.interactive_parent = interactive_parent
		var interactive_entries: Array[Dictionary] = []
		var interactive_cells := {}
		for network in arena.vortex_networks:
			if network == null or not network.enabled:
				continue
			for endpoint in network.unique_cells():
				interactive_cells[endpoint] = true
		for pair in arena.vortex_pairs:
			if pair == null:
				continue
			for endpoint in [pair.entry_cell, pair.exit_cell]:
				interactive_cells[endpoint] = true
		for endpoint in interactive_cells:
				interactive_entries.append({
					"cell": endpoint,
					"terrain_id": &"vortex",
					"texture": vortex_catalog.texture,
					"texture_path": vortex_catalog.texture.resource_path,
					"cell_type": grid.get_type(endpoint),
					"visible": true,
					"visual_layer": &"spatial_interactive",
					"renderer_role": &"arena_interactive",
					"parent_role": &"arena_interactives_layer",
					"node_prefix": "ArenaVortex",
					"topology_hash": str(render_plan.topology_hash),
				})
		var interactive_renderer := ArenaTerrainVisualRenderer.new()
		interactive_renderer.name = "ArenaInteractiveRenderer"
		interactive_renderer.set_meta("renderer_role", &"arena_interactive")
		owner.add_child(interactive_renderer)
		interactive_renderer.configure(grid_view, interactive_parent)
		interactive_renderer.render_plan({"entries": interactive_entries})
		result.interactive_renderer = interactive_renderer
	var blocker_service := DynamicBlockerService.new()
	blocker_service.configure(grid, pathfinder)
	result.blocker_service = blocker_service
	report.expected_wall_count = arena.obstacles.filter(func(value):
		return value != null and value.wall_id != &""
	).size()
	for obstacle in arena.obstacles:
		if obstacle == null or obstacle.wall_id == &"":
			continue
		var config := obstacle.wall_config
		if config == null:
			config = ArenaWallRegistry.config_for(obstacle.wall_id)
		var entry := ArenaWallRegistry.get_entry(obstacle.wall_id)
		if config == null or entry.is_empty() or not blocker_service.can_register_dynamic_blocker(obstacle.cell):
			report.missing_wall_assets.append("%s@%s" % [obstacle.wall_id, obstacle.cell])
			continue
		var wall := WALL_SCENE.instantiate() as DynamicWall
		wall.setup(obstacle.cell, int(entry.variant), config)
		wall.position = y_sorted_world.to_local(
			grid_view.to_global(grid_view.grid_to_local(obstacle.cell))
		)
		y_sorted_world.add_child(wall)
		if blocker_service.register_dynamic_blocker(obstacle.cell, wall):
			wall.set_meta("arena_cell", obstacle.cell)
			wall.set_meta("wall_id", obstacle.wall_id)
			wall.set_meta("renderer_layer", &"wall")
			wall.set_meta("renderer_role", &"dynamic_wall")
			wall.set_meta("parent_role", &"y_sorted_world")
			wall.set_meta("orientation", obstacle.orientation)
			wall.set_meta("blocks_movement", obstacle.blocks_movement)
			wall.set_meta("blocks_line_of_sight", obstacle.blocks_line_of_sight)
			wall.set_meta("blocks_projectiles", obstacle.blocks_projectiles)
			wall.set_meta("blocks_push", obstacle.blocks_push)
			result.walls.append(wall)
		else:
			wall.free()
	report.rendered_wall_count = result.walls.size()
	report.expected_decoration_count = arena.decorations.filter(func(value):
		return value != null and ArenaDecorationLayerRegistry.has(value.layer) \
			and bool(ArenaDecorationLayerRegistry.get_entry(value.layer).runtime)
	).size()
	for definition in arena.decorations:
		if definition == null:
			continue
		if not ArenaDecorationLayerRegistry.has(definition.layer):
			report.errors.append("decoration_layer_unknown:%s" % definition.decoration_id)
			continue
		var layer_entry := ArenaDecorationLayerRegistry.get_entry(definition.layer)
		if not bool(layer_entry.runtime):
			continue
		var decoration: Node2D = null
		if not definition.scene_path.is_empty() and ResourceLoader.exists(definition.scene_path):
			decoration = (load(definition.scene_path) as PackedScene).instantiate() as Node2D
		if decoration == null:
			decoration = _decoration_fallback(definition)
		decoration.name = "Decoration_%s" % definition.decoration_id
		var decoration_parent := _decoration_parent(
			definition, layer_entry, resolved_floor_parent, y_sorted_world
		)
		decoration.position = decoration_parent.to_local(
			grid_view.to_global(grid_view.grid_to_local(definition.cell))
		) + definition.local_offset
		decoration.rotation_degrees = definition.rotation_degrees
		decoration.scale = definition.visual_scale
		decoration.set_meta("arena_decoration_id", definition.decoration_id)
		decoration.set_meta("arena_cell", definition.cell)
		decoration.set_meta("renderer_layer", &"decoration")
		decoration.set_meta("renderer_role", &"decoration")
		decoration.set_meta("decoration_layer", definition.layer)
		decoration.set_meta("parent_role", _decoration_parent_role(definition, layer_entry))
		decoration.set_meta("scene_path", definition.scene_path)
		decoration.set_meta("y_sort", definition.y_sort)
		decoration.set_meta("visual_variant", definition.visual_variant)
		decoration.z_index = int(layer_entry.z_index)
		decoration.y_sort_enabled = bool(layer_entry.y_sorted) and definition.y_sort
		decoration_parent.add_child(decoration)
		result.decorations.append(decoration)
	report.rendered_decoration_count = result.decorations.size()
	var exact := actual_visual_signature(result)
	report.wall_nodes = exact.walls.duplicate(true)
	report.decoration_nodes = exact.decorations.duplicate(true)
	var comparison := compare_expected_to_actual(
		expected_visual_signature(arena, render_plan, prepared_visual_data), exact
	)
	report.errors.append_array(comparison.errors)
	report.finalize()
	result.ok = report.valid
	return result


static func structural_signature(arena: ArenaDefinition) -> Dictionary:
	var runtime := ArenaRuntimeBridge.runtime_signature(arena)
	var walls := []
	for obstacle in arena.obstacles:
		if obstacle != null and obstacle.wall_id != &"":
			walls.append({"cell": obstacle.cell, "wall_id": str(obstacle.wall_id)})
	var terrains := {}
	for cell in arena.cells:
		if cell != null and cell.defined:
			terrains["%d,%d" % [cell.coordinate.x, cell.coordinate.y]] = str(cell.terrain_id)
	return {
		"runtime": runtime,
		"walls": walls,
		"terrains": terrains,
		"spawns": arena.spawns.map(func(value): return value.to_dict()),
		"bounds": arena.painted_map_visual_data.grid_bounds_display() \
			if arena.painted_map_visual_data != null else Rect2(),
	}


static func expected_visual_signature(
		arena: ArenaDefinition,
		prepared_render_plan: Dictionary = {},
		prepared_visual_data: PaintedMapVisualData = null
	) -> Dictionary:
	var plan := prepared_render_plan \
		if not prepared_render_plan.is_empty() \
		else ArenaTerrainRenderPlanService.build(arena)
	var visual_data := prepared_visual_data
	if visual_data == null:
		var runtime_state := ArenaRuntimeProjectionService.build(arena)
		visual_data = runtime_state.visual_data if runtime_state != null else null
	var terrains := {}
	for entry in plan.render_entries:
		var polygon: PackedVector2Array = visual_data.cell_polygon_display(entry.cell) \
			if visual_data != null else entry.polygon
		var center := Vector2.ZERO
		for point in polygon:
			center += point
		if not polygon.is_empty():
			center /= float(polygon.size())
		terrains["%d,%d" % [entry.cell.x, entry.cell.y]] = {
			"coordinate": entry.cell,
			"terrain_id": str(entry.terrain_id),
			"cell_type": int(entry.cell_type),
			"texture_path": str(entry.texture_path),
			"parent_role": "arena_tiles_layer",
			"renderer_role": "arena_floor",
			"topology_hash": str(entry.get("topology_hash", "")),
			"position": center,
			"transform": ArenaTileProjectionService.sprite_transform(
				entry.texture, polygon, center
			),
			"polygon": polygon,
			"layer": str(entry.visual_layer),
			"duplication_count": 1,
		}
	var walls := {}
	for obstacle in arena.obstacles:
		if obstacle == null or obstacle.wall_id == &"":
			continue
		walls["%d,%d" % [obstacle.cell.x, obstacle.cell.y]] = {
			"cell": obstacle.cell,
			"wall_id": str(obstacle.wall_id),
			"orientation": obstacle.orientation,
			"texture_path": str(ArenaWallRegistry.get_entry(
				obstacle.wall_id
			).get("visual", "")),
			"parent_role": "y_sorted_world",
			"position": visual_data.cell_to_display(obstacle.cell) \
				if visual_data != null else Vector2(obstacle.cell),
			"blocks_movement": obstacle.blocks_movement,
			"blocks_line_of_sight": obstacle.blocks_line_of_sight,
			"blocks_projectiles": obstacle.blocks_projectiles,
			"blocks_push": obstacle.blocks_push,
		}
	var decorations := {}
	for definition in arena.decorations:
		if definition == null:
			continue
		if not ArenaDecorationLayerRegistry.has(definition.layer) \
				or not bool(ArenaDecorationLayerRegistry.get_entry(definition.layer).runtime):
			continue
		var base_position := visual_data.cell_to_display(definition.cell) \
			if visual_data != null else Vector2(definition.cell)
		decorations[str(definition.decoration_id)] = {
			"id": str(definition.decoration_id),
			"cell": definition.cell,
			"visual_variant": str(definition.visual_variant),
			"scene_path": definition.scene_path,
			"layer": str(definition.layer),
			"y_sort": definition.y_sort,
			"parent_role": str(_expected_decoration_parent_role(definition)),
			"position_offset": definition.local_offset,
			"position": base_position + definition.local_offset,
			"rotation_degrees": definition.rotation_degrees,
			"scale": definition.visual_scale,
		}
	return {
		"terrains": terrains,
		"walls": walls,
		"decorations": decorations,
		"expected_terrain_cell_count": terrains.size(),
		"expected_wall_count": walls.size(),
		"plan_valid": bool(plan.ok),
	}


static func actual_visual_signature(assembly: Dictionary) -> Dictionary:
	var renderer := assembly.get("renderer") as ArenaTerrainVisualRenderer
	var terrain_report := renderer.actual_render_report() if renderer != null else {
		"rendered_terrain_node_count": 0,
		"rendered_by_terrain_id": {},
		"cells": {},
		"errors": [],
	}
	var walls := {}
	for value in assembly.get("walls", []):
		var wall := value as DynamicWall
		if wall == null:
			continue
		var cell: Vector2i = wall.get_meta("arena_cell", wall.get_cell())
		var wall_id := StringName(wall.get_meta("wall_id", &""))
		walls["%d,%d" % [cell.x, cell.y]] = {
			"cell": cell,
			"wall_id": str(wall_id),
			"texture_path": str(ArenaWallRegistry.get_entry(wall_id).get("visual", "")),
			"position": wall.position,
			"transform": wall.transform,
			"parent": wall.get_parent().name if wall.get_parent() != null else &"",
			"parent_role": str(wall.get_meta("parent_role", &"")),
			"renderer_role": str(wall.get_meta("renderer_role", &"")),
			"orientation": wall.get_meta("orientation", Vector2i.DOWN),
			"blocks_movement": bool(wall.get_meta("blocks_movement", false)),
			"blocks_line_of_sight": bool(wall.get_meta("blocks_line_of_sight", false)),
			"blocks_projectiles": bool(wall.get_meta("blocks_projectiles", false)),
			"blocks_push": bool(wall.get_meta("blocks_push", false)),
			"visible": wall.visible,
		}
	var decorations := {}
	for value in assembly.get("decorations", []):
		if not is_instance_valid(value):
			continue
		var decoration := value as Node2D
		var decoration_id := str(decoration.get_meta("arena_decoration_id", &""))
		decorations[decoration_id] = {
			"id": decoration_id,
			"cell": decoration.get_meta("arena_cell", Vector2i.ZERO),
			"visual_variant": str(decoration.get_meta("visual_variant", &"")),
			"scene_path": str(decoration.get_meta("scene_path", "")),
			"position": decoration.position,
			"transform": decoration.transform,
			"rotation_degrees": decoration.rotation_degrees,
			"scale": decoration.scale,
			"layer": str(decoration.get_meta("decoration_layer", &"")),
			"y_sort": bool(decoration.get_meta("y_sort", false)),
			"parent": decoration.get_parent().name if decoration.get_parent() != null else &"",
			"parent_role": str(decoration.get_meta("parent_role", &"")),
			"visible": decoration.visible,
		}
	var signature := {
		"terrains": terrain_report.get("cells", {}),
		"walls": walls,
		"decorations": decorations,
		"rendered_terrain_node_count": int(terrain_report.get("rendered_terrain_node_count", 0)),
		"rendered_wall_count": walls.size(),
		"errors": terrain_report.get("errors", []),
	}
	var plan := assembly.get("render_plan", {}) as Dictionary
	var topology := plan.get("topology", {}) as Dictionary
	var floor_parity := ArenaTopologyParityReport.compare_floor_sets(
		plan.get("expected_floor_cells", []),
		(terrain_report.get("cells", {}) as Dictionary).keys(),
		topology.get("removed_cells", [])
	)
	signature["topology_hash"] = str(plan.get("topology_hash", ""))
	signature["expected_floor_hash"] = floor_parity.expected_floor_hash
	signature["rendered_floor_hash"] = floor_parity.rendered_floor_hash
	signature["missing_cells"] = floor_parity.missing_cells
	signature["unexpected_cells"] = floor_parity.unexpected_cells
	signature["removed_cells_rendered"] = floor_parity.removed_cells_rendered
	return signature


static func compare_expected_to_actual(
		expected: Dictionary,
		actual: Dictionary
	) -> Dictionary:
	var errors: Array[String] = []
	var expected_terrains := expected.get("terrains", {}) as Dictionary
	var actual_terrains := actual.get("terrains", {}) as Dictionary
	for key in expected_terrains:
		if not actual_terrains.has(key):
			errors.append("terrain_node_missing:%s" % key)
			continue
		var wanted := expected_terrains[key] as Dictionary
		var rendered := actual_terrains[key] as Dictionary
		for field in [
			"coordinate", "terrain_id", "cell_type", "texture_path",
			"parent_role", "renderer_role", "position", "transform",
			"polygon", "layer",
		]:
			if wanted.get(field) != rendered.get(field):
				errors.append("terrain_%s_mismatch:%s" % [field, key])
		if int(rendered.get("duplication_count", 0)) != 1:
			errors.append("terrain_duplicate:%s" % key)
		if not bool(rendered.get("visible", false)):
			errors.append("terrain_hidden:%s" % key)
	for key in actual_terrains:
		if not expected_terrains.has(key):
			errors.append("unexpected_terrain_node:%s" % key)
	var expected_walls := expected.get("walls", {}) as Dictionary
	var actual_walls := actual.get("walls", {}) as Dictionary
	for key in expected_walls:
		if not actual_walls.has(key):
			errors.append("wall_node_missing:%s" % key)
		else:
			var wanted_wall := expected_walls[key] as Dictionary
			var rendered_wall := actual_walls[key] as Dictionary
			for field in [
				"wall_id", "orientation", "texture_path", "parent_role",
				"position",
				"blocks_movement", "blocks_line_of_sight",
				"blocks_projectiles", "blocks_push",
			]:
				if wanted_wall.get(field) != rendered_wall.get(field):
					errors.append("wall_%s_mismatch:%s" % [field, key])
	var expected_decorations := expected.get("decorations", {}) as Dictionary
	var actual_decorations := actual.get("decorations", {}) as Dictionary
	for key in expected_decorations:
		if not actual_decorations.has(key):
			errors.append("decoration_node_missing:%s" % key)
			continue
		var wanted_decoration := expected_decorations[key] as Dictionary
		var actual_decoration := actual_decorations[key] as Dictionary
		for field in [
			"cell", "visual_variant", "scene_path", "layer", "y_sort",
			"parent_role", "position", "rotation_degrees", "scale",
		]:
			if wanted_decoration.get(field) != actual_decoration.get(field):
				errors.append("decoration_%s_mismatch:%s" % [field, key])
		if not bool(actual_decoration.get("visible", false)):
			errors.append("decoration_hidden:%s" % key)
	return {
		"ok": errors.is_empty() and bool(expected.get("plan_valid", false)),
		"errors": errors,
		"expected": expected,
		"actual": actual,
	}


static func inspect(
		arena: ArenaDefinition,
		prepared_runtime_state: ArenaRuntimeState = null,
		prepared_render_plan: Dictionary = {}
	) -> ArenaVisualAssemblyReport:
	if arena == null:
		var missing := ArenaVisualAssemblyReport.new()
		missing.errors.append("arena_missing")
		missing.finalize()
		return missing
	# Une dérivation injectée appartient au snapshot courant de l'appelant : elle
	# contourne volontairement le cache global pour ne créer aucun faux hit stale.
	var use_global_cache := (
		prepared_runtime_state == null and prepared_render_plan.is_empty()
	)
	var cache_key := ""
	if use_global_cache:
		cache_key = ArenaSnapshotService.arena_fingerprint(arena)
		if _inspection_cache.has(cache_key):
			var cached := _report_from_dict(_inspection_cache[cache_key] as Dictionary)
			cached.set_meta("cache_hit", true)
			return cached
	var runtime_state := prepared_runtime_state \
		if prepared_runtime_state != null \
		else ArenaRuntimeProjectionService.build(arena)
	var projection := runtime_state.arena_projection \
		if runtime_state != null else null
	var grid := runtime_state.grid if runtime_state != null else null
	if grid == null:
		var failed := ArenaVisualAssemblyReport.new()
		failed.errors.append("grid_build_failed")
		failed.finalize()
		return failed
	var root := Node2D.new()
	var grid_view := PaintedGridView.new()
	grid_view.configure(
		projection.painted_map_visual_data,
		projection.grid_layout,
		projection.hero_spawn_zone,
		projection.enemy_spawn_zone
	)
	grid_view.setup(grid)
	root.add_child(grid_view)
	var floor := Node2D.new()
	floor.name = "ArenaTilesLayer"
	floor.y_sort_enabled = false
	root.add_child(floor)
	var world := Node2D.new()
	world.name = "YSortedWorld"
	world.y_sort_enabled = true
	root.add_child(world)
	var assembly := assemble(
		projection, grid, Pathfinder.new(grid), grid_view, world, root, true, floor,
		prepared_render_plan, runtime_state.visual_data
	)
	var report := assembly.report as ArenaVisualAssemblyReport
	root.free()
	report.set_meta("cache_hit", false)
	if use_global_cache:
		_inspection_cache[cache_key] = report.to_dict()
	return report


static func clear_inspection_cache() -> void:
	_inspection_cache.clear()


static func inspection_cache_size() -> int:
	return _inspection_cache.size()


static func _report_from_dict(data: Dictionary) -> ArenaVisualAssemblyReport:
	var report := ArenaVisualAssemblyReport.new()
	report.visual_mode = int(data.get("visual_mode", ArenaDefinition.VisualMode.PAINTED))
	report.floor_policy = int(data.get(
		"floor_policy", ArenaModularVisualProfile.HybridFloorPolicy.NONE
	))
	report.base_floor_intentionally_painted = bool(data.get("base_floor_intentionally_painted", false))
	report.expected_terrain_cell_count = int(data.get("expected_terrain_cell_count", 0))
	report.rendered_terrain_node_count = int(data.get("rendered_terrain_node_count", 0))
	report.expected_by_terrain_id = (data.get("expected_by_terrain_id", {}) as Dictionary).duplicate(true)
	report.rendered_by_terrain_id = (data.get("rendered_by_terrain_id", {}) as Dictionary).duplicate(true)
	report.expected_wall_count = int(data.get("expected_wall_count", 0))
	report.rendered_wall_count = int(data.get("rendered_wall_count", 0))
	report.expected_decoration_count = int(data.get("expected_decoration_count", 0))
	report.rendered_decoration_count = int(data.get("rendered_decoration_count", 0))
	report.duplicate_terrain_node_count = int(data.get("duplicate_terrain_node_count", 0))
	report.terrain_nodes = (data.get("terrain_nodes", {}) as Dictionary).duplicate(true)
	report.wall_nodes = (data.get("wall_nodes", {}) as Dictionary).duplicate(true)
	report.decoration_nodes = (data.get("decoration_nodes", {}) as Dictionary).duplicate(true)
	report.missing_terrain_assets.assign(data.get("missing_terrain_assets", []))
	report.missing_wall_assets.assign(data.get("missing_wall_assets", []))
	report.skipped_cells = (data.get("skipped_cells", []) as Array).duplicate(true)
	report.skip_reasons = (data.get("skip_reasons", {}) as Dictionary).duplicate(true)
	report.warnings.assign(data.get("warnings", []))
	report.errors.assign(data.get("errors", []))
	report.valid = bool(data.get("valid", false))
	return report


static func _decoration_fallback(definition: ArenaDecorationDefinition) -> Node2D:
	var root := Node2D.new()
	var marker := Polygon2D.new()
	marker.polygon = PackedVector2Array([
		Vector2(0, -18), Vector2(12, 0), Vector2(0, 18), Vector2(-12, 0)
	])
	marker.color = Color(0.85, 0.58, 1.0, 0.85)
	root.add_child(marker)
	root.set_meta("fallback", true)
	return root


static func _decoration_parent(
		definition: ArenaDecorationDefinition,
		layer_entry: Dictionary,
		floor_parent: Node2D,
		y_sorted_world: Node2D
	) -> Node2D:
	var role := _decoration_parent_role(definition, layer_entry)
	return floor_parent if role == &"floor" else y_sorted_world


static func _decoration_parent_role(
		definition: ArenaDecorationDefinition,
		layer_entry: Dictionary
	) -> StringName:
	var role := StringName(layer_entry.get("parent_role", &"y_sorted_world"))
	if role == &"conditional":
		return &"y_sorted_world" if definition.y_sort else &"floor"
	return role


static func _expected_decoration_parent_role(
		definition: ArenaDecorationDefinition
	) -> StringName:
	if not ArenaDecorationLayerRegistry.has(definition.layer):
		return &"unknown"
	return _decoration_parent_role(
		definition, ArenaDecorationLayerRegistry.get_entry(definition.layer)
	)
