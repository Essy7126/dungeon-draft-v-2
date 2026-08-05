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
		include_modular_tiles := true
	) -> Dictionary:
	var result := {
		"ok": false,
		"renderer": null,
		"blocker_service": null,
		"walls": [],
		"decorations": [],
		"terrain_cells": {},
	}
	if arena == null or grid == null or pathfinder == null or grid_view == null \
			or y_sorted_world == null or owner == null:
		return result
	if include_modular_tiles and arena.visual_mode != ArenaDefinition.VisualMode.PAINTED:
		var terrain_cells := _terrain_cells_for(arena)
		result.terrain_cells = terrain_cells
		if not terrain_cells.is_empty() and arena.arena_visual_profile != null:
			var renderer := ArenaFeatureRenderer.new()
			renderer.name = "ArenaFeatureRenderer"
			owner.add_child(renderer)
			renderer.configure(grid_view, y_sorted_world, arena.arena_visual_profile)
			renderer.render(terrain_cells)
			result.renderer = renderer
	var blocker_service := DynamicBlockerService.new()
	blocker_service.configure(grid, pathfinder)
	result.blocker_service = blocker_service
	for obstacle in arena.obstacles:
		if obstacle == null or obstacle.wall_id == &"":
			continue
		var config := obstacle.wall_config
		if config == null:
			config = ArenaWallRegistry.config_for(obstacle.wall_id)
		var entry := ArenaWallRegistry.get_entry(obstacle.wall_id)
		if config == null or entry.is_empty() or not blocker_service.can_register_dynamic_blocker(obstacle.cell):
			continue
		var wall := WALL_SCENE.instantiate() as DynamicWall
		wall.setup(obstacle.cell, int(entry.variant), config)
		wall.position = y_sorted_world.to_local(
			grid_view.to_global(grid_view.grid_to_local(obstacle.cell))
		)
		y_sorted_world.add_child(wall)
		if blocker_service.register_dynamic_blocker(obstacle.cell, wall):
			result.walls.append(wall)
		else:
			wall.free()
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
		y_sorted_world.add_child(decoration)
		result.decorations.append(decoration)
	result.ok = true
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


static func _terrain_cells_for(arena: ArenaDefinition) -> Dictionary:
	var result := {}
	for definition in arena.cells:
		if definition == null or not definition.defined or definition.border:
			continue
		if arena.visual_mode == ArenaDefinition.VisualMode.HYBRID \
				and definition.terrain_id in [&"normal", &"stone"]:
			continue
		result[definition.coordinate] = definition.cell_type
	return result


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
