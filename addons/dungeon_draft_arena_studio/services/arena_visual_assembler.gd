@tool
class_name ArenaVisualAssembler
extends RefCounted

const WALL_SCENE := preload("res://tools/labs/dynamic_arena/DynamicWall.tscn")


static func assemble(
		arena: ArenaDefinition,
		grid: GridData,
		pathfinder: Pathfinder,
		grid_view: Node2D,
		y_sorted_world: Node2D,
		owner: Node,
		include_modular_tiles := true,
		floor_parent: Node2D = null
	) -> Dictionary:
	var result := {
		"ok": false,
		"renderer": null,
		"blocker_service": null,
		"walls": [],
		"decorations": [],
		"terrain_cells": {},
		"render_plan": {},
		"report": null,
	}
	if arena == null or grid == null or pathfinder == null or grid_view == null \
			or y_sorted_world == null or owner == null:
		return result
	var render_plan := ArenaTerrainRenderPlanService.build(arena)
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
	if include_modular_tiles and not render_plan.render_entries.is_empty():
		var renderer := ArenaTerrainVisualRenderer.new()
		# Nom historique conserve pour les smoke tests et les outils qui cherchaient
		# cette couche, la classe et les metadonnees exposent le nouveau contrat.
		renderer.name = "ArenaFeatureRenderer"
		owner.add_child(renderer)
		renderer.configure(
			grid_view, floor_parent if floor_parent != null else y_sorted_world
		)
		renderer.render_plan(render_plan)
		result.renderer = renderer
		var actual := renderer.actual_render_report()
		report.rendered_terrain_node_count = int(actual.rendered_terrain_node_count)
		report.rendered_by_terrain_id = actual.rendered_by_terrain_id.duplicate(true)
		report.errors.append_array(actual.errors)
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
			result.walls.append(wall)
		else:
			wall.free()
	report.rendered_wall_count = result.walls.size()
	report.expected_decoration_count = arena.decorations.filter(func(value):
		return value != null
	).size()
	for definition in arena.decorations:
		if definition == null:
			continue
		var decoration: Node2D = null
		if not definition.scene_path.is_empty() and ResourceLoader.exists(definition.scene_path):
			decoration = (load(definition.scene_path) as PackedScene).instantiate() as Node2D
		if decoration == null:
			decoration = _decoration_fallback(definition)
		decoration.name = "Decoration_%s" % definition.decoration_id
		decoration.position = y_sorted_world.to_local(
			grid_view.to_global(grid_view.grid_to_local(definition.cell))
		) + definition.local_offset
		decoration.rotation_degrees = definition.rotation_degrees
		decoration.scale = definition.visual_scale
		decoration.set_meta("arena_decoration_id", definition.decoration_id)
		decoration.set_meta("arena_cell", definition.cell)
		decoration.set_meta("renderer_layer", &"decoration")
		decoration.set_meta("visual_variant", definition.visual_variant)
		y_sorted_world.add_child(decoration)
		result.decorations.append(decoration)
	report.rendered_decoration_count = result.decorations.size()
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


static func expected_visual_signature(arena: ArenaDefinition) -> Dictionary:
	var plan := ArenaTerrainRenderPlanService.build(arena)
	var terrains := {}
	for entry in plan.render_entries:
		terrains["%d,%d" % [entry.cell.x, entry.cell.y]] = {
			"terrain_id": str(entry.terrain_id),
			"cell_type": int(entry.cell_type),
			"texture_path": str(entry.texture_path),
		}
	var walls := {}
	for obstacle in arena.obstacles:
		if obstacle == null or obstacle.wall_id == &"":
			continue
		walls["%d,%d" % [obstacle.cell.x, obstacle.cell.y]] = {
			"wall_id": str(obstacle.wall_id),
			"texture_path": str(ArenaWallRegistry.get_entry(
				obstacle.wall_id
			).get("visual", "")),
		}
	var decorations := {}
	for definition in arena.decorations:
		if definition == null:
			continue
		decorations[str(definition.decoration_id)] = {
			"cell": definition.cell,
			"visual_variant": str(definition.visual_variant),
			"scene_path": definition.scene_path,
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
			"wall_id": str(wall_id),
			"texture_path": str(ArenaWallRegistry.get_entry(wall_id).get("visual", "")),
			"position": wall.position,
			"visible": wall.visible,
		}
	var decorations := {}
	for value in assembly.get("decorations", []):
		if not is_instance_valid(value):
			continue
		var decoration := value as Node2D
		var decoration_id := str(decoration.get_meta("arena_decoration_id", &""))
		decorations[decoration_id] = {
			"cell": decoration.get_meta("arena_cell", Vector2i.ZERO),
			"visual_variant": str(decoration.get_meta("visual_variant", &"")),
			"position": decoration.position,
			"visible": decoration.visible,
		}
	return {
		"terrains": terrain_report.get("cells", {}),
		"walls": walls,
		"decorations": decorations,
		"rendered_terrain_node_count": int(terrain_report.get("rendered_terrain_node_count", 0)),
		"rendered_wall_count": walls.size(),
		"errors": terrain_report.get("errors", []),
	}


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
		for field in ["terrain_id", "cell_type", "texture_path"]:
			if wanted.get(field) != rendered.get(field):
				errors.append("terrain_%s_mismatch:%s" % [field, key])
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
		elif (expected_walls[key] as Dictionary).get("wall_id") \
				!= (actual_walls[key] as Dictionary).get("wall_id"):
			errors.append("wall_id_mismatch:%s" % key)
	var expected_decorations := expected.get("decorations", {}) as Dictionary
	var actual_decorations := actual.get("decorations", {}) as Dictionary
	for key in expected_decorations:
		if not actual_decorations.has(key):
			errors.append("decoration_node_missing:%s" % key)
			continue
		var wanted_decoration := expected_decorations[key] as Dictionary
		var actual_decoration := actual_decorations[key] as Dictionary
		for field in ["cell", "visual_variant"]:
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


static func inspect(arena: ArenaDefinition) -> ArenaVisualAssemblyReport:
	if arena == null:
		var missing := ArenaVisualAssemblyReport.new()
		missing.errors.append("arena_missing")
		missing.finalize()
		return missing
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	var grid := ArenaRuntimeBridge.build_grid(arena)
	if grid == null:
		var failed := ArenaVisualAssemblyReport.new()
		failed.errors.append("grid_build_failed")
		failed.finalize()
		return failed
	var root := Node2D.new()
	var grid_view := PaintedGridView.new()
	grid_view.configure(
		arena.painted_map_visual_data,
		arena.grid_layout,
		arena.hero_spawn_zone,
		arena.enemy_spawn_zone
	)
	grid_view.setup(grid)
	root.add_child(grid_view)
	var world := Node2D.new()
	world.y_sort_enabled = true
	root.add_child(world)
	var assembly := assemble(
		arena, grid, Pathfinder.new(grid), grid_view, world, root, true
	)
	var report := assembly.report as ArenaVisualAssemblyReport
	root.free()
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
