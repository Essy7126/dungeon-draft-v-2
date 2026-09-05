extends RefCounted

const ValidationPaths := preload("res://tools/registered_terrain_validation/validation_paths.gd")

# This oracle deliberately does not call ArenaTileProjectionService or its
# expected signature. It measures live Sprite2D rectangles in viewport pixels.
const STONE := "res://tools/labs/dynamic_arena/assets/normalized/stone.png"
const PIXEL_TOLERANCE := 0.05
const DIRECTIONS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

static func sprite_polygon(sprite: Sprite2D) -> PackedVector2Array:
	var rect := sprite.get_rect()
	var fractions := PackedVector2Array([Vector2(0.5, 0), Vector2(1, 0.5), Vector2(0.5, 1), Vector2(0, 0.5)])
	var result := PackedVector2Array()
	for fraction: Vector2 in fractions:
		result.append(sprite.get_global_transform_with_canvas() * (rect.position + rect.size * fraction))
	return result

static func analytic_polygon(arena: ArenaDefinition, view: Node2D, cell: Vector2i) -> PackedVector2Array:
	var visual := arena.painted_map_visual_data
	var center := arena.grid_origin + float(cell.x) * arena.axis_x + float(cell.y) * arena.axis_y
	var result := PackedVector2Array()
	for corner: Vector2 in [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)]:
		var native := center + corner.x * arena.axis_x + corner.y * arena.axis_y
		result.append(view.get_global_transform_with_canvas() * (visual.image_offset + native * visual.image_scale))
	return result

static func run(battle: Node, arena: ArenaDefinition, grid: GridData, view: Node2D, renderer: ArenaTerrainVisualRenderer) -> Dictionary:
	var errors: Array[String] = []
	var floor := {}
	for definition in arena.cells:
		if definition != null and definition.defined and definition.cell_type != GridData.CellType.HOLE:
			floor[definition.coordinate] = true
	var polygons := {}
	var vertex_count := 0
	var vertex_error := 0.0
	var grid_polygon_error := 0.0
	var pick_count := 0
	var rejected_pick_count := 0
	var pick_failures := 0
	var void_count := 0
	var visual_inverse := view.get_global_transform_with_canvas().affine_inverse()
	for y in range(grid.rows):
		for x in range(grid.cols):
			var cell := Vector2i(x, y)
			var root := renderer.node_for_cell(cell)
			if not floor.has(cell):
				void_count += 1
				if root != null or grid.is_terrain_interactable(cell):
					errors.append("void_has_floor_or_input:%s" % cell)
				var absent_polygon := analytic_polygon(arena, view, cell)
				var center := (absent_polygon[0] + absent_polygon[2]) * 0.5
				if view._valid_cell_at(visual_inverse * center) != Vector2i(-1, -1):
					errors.append("void_center_accepts_pick:%s" % cell)
				continue
			var sprite := root.get_node_or_null("Visual") as Sprite2D if root != null else null
			if sprite == null or sprite.texture == null:
				errors.append("missing_real_sprite:%s" % cell)
				continue
			if sprite.texture.resource_path != STONE or sprite.region_enabled or sprite.flip_h or sprite.flip_v:
				errors.append("unexpected_sprite_texture_contract:%s" % cell)
			var measured := sprite_polygon(sprite)
			var expected := analytic_polygon(arena, view, cell)
			var grid_polygon: PackedVector2Array = view.get_cell_polygon(cell)
			polygons[cell] = measured
			for index in range(4):
				vertex_count += 1
				vertex_error = maxf(vertex_error, measured[index].distance_to(expected[index]))
				grid_polygon_error = maxf(grid_polygon_error, measured[index].distance_to(view.get_global_transform_with_canvas() * grid_polygon[index]))
			var rect := sprite.get_rect()
			for u: float in [-0.4, 0.0, 0.4]:
				for v: float in [-0.4, 0.0, 0.4]:
					# Nine strictly interior points originate in the sprite itself.
					var fraction := Vector2(0.5 + 0.5 * (u - v), 0.5 + 0.5 * (u + v))
					var screen := sprite.get_global_transform_with_canvas() * (rect.position + rect.size * fraction)
					var wanted := cell if grid.is_terrain_interactable(cell) else Vector2i(-1, -1)
					var picked: Vector2i = view._valid_cell_at(visual_inverse * screen)
					pick_count += 1
					if wanted == Vector2i(-1, -1):
						rejected_pick_count += 1
					if picked != wanted:
						pick_failures += 1
	var adjacency_count := 0
	var adjacency_error := 0.0
	for cell: Vector2i in polygons:
		var a: PackedVector2Array = polygons[cell]
		for direction: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
			if not polygons.has(cell + direction):
				continue
			var b: PackedVector2Array = polygons[cell + direction]
			var first := 1 if direction == Vector2i.RIGHT else 3
			var second := 3 if direction == Vector2i.RIGHT else 1
			adjacency_error = maxf(adjacency_error, a[first].distance_to(b[0]))
			adjacency_error = maxf(adjacency_error, a[2].distance_to(b[second]))
			adjacency_count += 1
	var source_sprites := _count_source_sprites(battle)
	if source_sprites != floor.size():
		errors.append("duplicated_or_missing_source_sprites:%d_expected_%d" % [source_sprites, floor.size()])
	if bool(view.get("draw_base_cells")) or bool(view.get("draw_logic_types")):
		errors.append("grid_diagnostic_floor_overdraw")
	if vertex_error > PIXEL_TOLERANCE or grid_polygon_error > PIXEL_TOLERANCE:
		errors.append("sprite_grid_vertex_error:%.6f/%.6fpx" % [vertex_error, grid_polygon_error])
	if adjacency_error > PIXEL_TOLERANCE:
		errors.append("adjacent_sprite_edge_gap:%.6fpx" % adjacency_error)
	if pick_failures > 0:
		errors.append("sprite_interior_pick_failures:%d" % pick_failures)
	var unit_report := check_unit_footprints(battle, renderer)
	errors.append_array(unit_report.errors)
	var platform_report := _check_platform(battle, floor, grid, view, renderer)
	errors.append_array(platform_report.errors)
	var prop_error := 0.0
	var prop_count := 0
	var assembly: Dictionary = battle.get("arena_assembly")
	for prop: Node2D in assembly.get("decorations", []):
		var cell: Vector2i = prop.get_meta("arena_cell", Vector2i(-1, -1))
		if not polygons.has(cell):
			errors.append("prop_without_floor:%s" % cell)
			continue
		var polygon: PackedVector2Array = polygons[cell]
		prop_error = maxf(prop_error, (prop.get_global_transform_with_canvas() * Vector2.ZERO).distance_to((polygon[0] + polygon[2]) * 0.5))
		prop_count += 1
	if prop_error > PIXEL_TOLERANCE:
		errors.append("prop_anchor_misaligned:%.6fpx" % prop_error)
	return {
		"ok": errors.is_empty(), "errors": errors, "pixel_tolerance": PIXEL_TOLERANCE,
		"oracle": "actual Sprite2D.get_rect vertices transformed to viewport; direct arena affine independent of projection service",
		"actual_stone_sprite_count_entire_scene": source_sprites,
		"floor_cells": floor.size(), "void_cells": void_count,
		"sprite_vertex_cases": vertex_count, "sprite_vs_analytic_max_error_px": vertex_error,
		"sprite_vs_grid_highlight_max_error_px": grid_polygon_error,
		"adjacent_shared_edges": adjacency_count, "adjacent_edge_max_error_px": adjacency_error,
		"sprite_interior_pick_cases": pick_count, "blocked_interior_pick_cases": rejected_pick_count,
		"sprite_interior_pick_failures": pick_failures,
		"unit_footprints": unit_report, "platform": platform_report,
		"prop_anchor_cases": prop_count, "prop_anchor_max_error_px": prop_error,
	}

static func check_unit_footprints(battle: Node, renderer: ArenaTerrainVisualRenderer) -> Dictionary:
	var errors: Array[String] = []
	var max_error := 0.0
	var vertex_count := 0
	var widths: Array = []
	var views: Dictionary = battle.get("_unit_views")
	for unit: Unit in views:
		var view := views[unit] as Node2D
		var root := renderer.node_for_cell(unit.grid_pos)
		var sprite := root.get_node_or_null("Visual") as Sprite2D if root != null else null
		if view == null or sprite == null:
			errors.append("unit_or_floor_view_missing")
			continue
		var footprint: PackedVector2Array = view._active_cell_footprint()
		var polygon := sprite_polygon(sprite)
		if footprint.size() != 4:
			errors.append("unit_footprint_not_four_corners:%s" % unit.unit_id)
			continue
		var screen := PackedVector2Array()
		for index in range(4):
			screen.append(view.get_global_transform_with_canvas() * footprint[index])
			max_error = maxf(max_error, screen[index].distance_to(polygon[index]))
			vertex_count += 1
		widths.append({"unit": str(unit.unit_id), "footprint_width_px": screen[1].distance_to(screen[3]), "tile_width_px": polygon[1].distance_to(polygon[3])})
	if max_error > PIXEL_TOLERANCE:
		errors.append("unit_active_outline_or_shadow_mismatch:%.6fpx" % max_error)
	return {"errors": errors, "vertex_cases": vertex_count, "max_error_px": max_error, "measured_widths": widths}

static func _count_source_sprites(node: Node) -> int:
	var count := 0
	if node is Sprite2D and node.texture != null and node.texture.resource_path == STONE:
		count += 1
	for child in node.get_children():
		count += _count_source_sprites(child)
	return count

static func _check_platform(battle: Node, floor: Dictionary, grid: GridData, view: Node2D, renderer: ArenaTerrainVisualRenderer) -> Dictionary:
	var errors: Array[String] = []
	var platform := battle.get_node_or_null("GreekPlatformRisersAndPits") as Node2D
	if platform == null:
		return {"errors": ["platform_missing"]}
	var geometry: Dictionary = platform.geometry_report()
	var pits: Array = geometry.pit_cells
	var arena := battle.get("room_data") as ArenaDefinition
	var annotation := _semantic_pit_annotation(arena, grid, floor, renderer)
	errors.append_array(annotation.errors)
	errors.append_array(geometry.get("pit_semantic_annotation_errors", []))
	var expected_pits: Dictionary = annotation.cells
	var boundary_expected := 0
	var wall_expected := 0
	var riser_expected := 0
	for cell: Vector2i in expected_pits:
		for index in range(4):
			if not expected_pits.has(cell + DIRECTIONS[index]):
				boundary_expected += 1
				if index in [0, 3] and floor.has(cell + DIRECTIONS[index]):
					wall_expected += 1
	for cell: Vector2i in floor:
		for index in [1, 2]:
			if not floor.has(cell + DIRECTIONS[index]) and not expected_pits.has(cell + DIRECTIONS[index]):
				riser_expected += 1
	var internal_walls := 0
	var max_error := 0.0
	var edge_count := 0
	for edge: Dictionary in geometry.pit_wall_edges:
		if expected_pits.has(edge.neighbor) or not floor.has(edge.neighbor):
			internal_walls += 1
	for edge: Dictionary in geometry.pit_boundary_edges + geometry.perimeter_riser_edges:
		var measured: PackedVector2Array = platform._edge_points(edge)
		var base: PackedVector2Array = view.get_cell_polygon(edge.cell)
		for endpoint in range(2):
			var wanted: Vector2 = view.get_global_transform_with_canvas() * base[(int(edge.edge_index) + endpoint) % 4]
			var actual: Vector2 = platform.get_global_transform_with_canvas() * measured[endpoint]
			max_error = maxf(max_error, actual.distance_to(wanted))
			edge_count += 1
		# A pit edge must also coincide with the real neighboring floor sprite.
		if floor.has(edge.neighbor):
			var tile := renderer.node_for_cell(edge.neighbor)
			var sprite := tile.get_node_or_null("Visual") as Sprite2D if tile != null else null
			if sprite != null:
				var neighbor := sprite_polygon(sprite)
				for endpoint in range(2):
					var actual: Vector2 = platform.get_global_transform_with_canvas() * measured[endpoint]
					var nearest := INF
					for corner: Vector2 in neighbor:
						nearest = minf(nearest, actual.distance_to(corner))
					max_error = maxf(max_error, nearest)
	if internal_walls > 0 or geometry.pit_wall_edges.size() != wall_expected:
		errors.append("pit_internal_or_missing_walls")
	if geometry.pit_boundary_edges.size() != boundary_expected or geometry.perimeter_riser_edges.size() != riser_expected:
		errors.append("platform_boundary_count_mismatch")
	if pits.size() != expected_pits.size():
		errors.append("rendered_pit_count_differs_from_semantic_annotation")
	for cell: Vector2i in expected_pits:
		if not pits.has(cell):
			errors.append("annotated_canonical_void_missing_pit:%s" % cell)
	if geometry.pit_components.size() != int(annotation.connected_components):
		errors.append("pit_union_component_count_mismatch")
	if max_error > PIXEL_TOLERANCE:
		errors.append("platform_edge_alignment:%.6fpx" % max_error)
	return {"errors": errors, "authority": geometry.authority, "pit_components": geometry.pit_components.size(), "pit_cells": pits.size(), "expected_annotated_void_cells": expected_pits.size(), "expected_annotation_groups": annotation.groups, "expected_connected_components": annotation.connected_components, "semantic_annotation_scope": "Artwork classification only; every annotated cell independently verified HOLE with no live floor sprite", "pit_union_boundary_edges": boundary_expected, "visible_pit_walls": wall_expected, "internal_pit_walls": internal_walls, "perimeter_forward_boundary_edges": riser_expected, "rendered_perimeter_risers": geometry.get("rendered_perimeter_risers",0), "peripheral_drop_native_px": geometry.get("peripheral_drop_native_px",0.0), "edge_vertex_cases": edge_count, "edge_max_error_px": max_error}

static func farthest_walkable_route(grid: GridData, pathfinder: Pathfinder, hero: Unit) -> Array:
	var candidates: Array[Vector2i] = []
	for y in range(grid.rows):
		for x in range(grid.cols):
			var cell := Vector2i(x, y)
			if grid.is_walkable(cell, hero) and cell != hero.grid_pos:
				candidates.append(cell)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return grid.manhattan(hero.grid_pos, a) > grid.manhattan(hero.grid_pos, b))
	for cell: Vector2i in candidates:
		var route := pathfinder.find_path(hero.grid_pos, cell, hero)
		if not route.is_empty():
			return route
	return []

static func _semantic_pit_annotation(arena: ArenaDefinition, grid: GridData, floor: Dictionary, renderer: ArenaTerrainVisualRenderer) -> Dictionary:
	var errors: Array[String] = []
	var cells := {}
	var groups := 0
	var path := ValidationPaths.manifest_path(arena)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if not parsed is Dictionary:
		return {"errors": ["pit_semantic_annotation_missing_or_invalid"], "cells": cells, "groups": 0, "connected_components": 0}
	for annotation: Dictionary in parsed.get("pits", []):
		groups += 1
		for pair: Array in annotation.get("cells", []):
			if pair.size() != 2:
				errors.append("pit_semantic_coordinate_invalid")
				continue
			var cell := Vector2i(int(pair[0]),int(pair[1]))
			if cells.has(cell):
				errors.append("pit_semantic_duplicate:%s" % cell)
			if not grid.is_valid(cell) or floor.has(cell) or grid.get_type(cell) != GridData.CellType.HOLE \
					or grid.is_terrain_interactable(cell) or renderer.node_for_cell(cell) != null:
				errors.append("annotated_pit_not_live_void:%s" % cell)
			cells[cell] = true
	# Independent depth-first connectivity over annotations; a component touching
	# exterior remains a recess because its semantic classification is explicit.
	var visited := {}
	var connected_components := 0
	for start: Vector2i in cells:
		if visited.has(start):
			continue
		connected_components += 1
		var stack: Array[Vector2i] = [start]
		while not stack.is_empty():
			var cell := stack.pop_back() as Vector2i
			if visited.has(cell):
				continue
			visited[cell] = true
			for direction: Vector2i in DIRECTIONS:
				if cells.has(cell + direction) and not visited.has(cell + direction):
					stack.append(cell + direction)
	return {"errors": errors, "cells": cells, "groups": groups, "connected_components": connected_components}
