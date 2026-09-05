extends RefCounted

# Room III's deliberately stricter art contract. This proves layer absence and
# live joint configuration, not the visual quality of imagery baked into Land.
const EXPECTED_FLOOR_COUNT := 217
const EXPECTED_TACTICAL_OBSTACLES := 12
const UNIFORM_TOLERANCE := 0.000001

static func run(battle: Node, arena: ArenaDefinition, grid: GridData, renderer: ArenaTerrainVisualRenderer) -> Dictionary:
	var errors: Array[String] = []
	var terrain := battle.get_node_or_null("GreekTerrainComposition") as Node2D
	if terrain == null:
		return {"ok": false, "errors": ["quiet_center_terrain_missing"]}
	var raw_plan: Variant = terrain.get("plan")
	var raw_external: Variant = terrain.get("_external_decor")
	if not raw_plan is Dictionary or not raw_plan.get("world_decor") is Array or not raw_external is Array:
		return {"ok": false, "errors": ["quiet_center_world_decor_contract_missing"]}
	var plan: Dictionary = raw_plan
	var declared: Array = plan.get("world_decor", [])
	var external: Array = raw_external
	if not declared.is_empty() or not external.is_empty():
		errors.append("quiet_center_cosmetic_decor_declared_or_instantiated")
	var tagged_nodes: Array[String] = []
	_collect_cosmetic_nodes(battle, tagged_nodes)
	if not tagged_nodes.is_empty():
		errors.append("quiet_center_live_cosmetic_nodes:%d" % tagged_nodes.size())
	var assembly: Dictionary = battle.get("arena_assembly")
	var allowed_roots: Array[Node] = []
	var floor_parent := assembly.get("floor_parent") as Node
	if floor_parent != null:
		allowed_roots.append(floor_parent)
	var units: Dictionary = battle.get("_unit_views")
	for value: Variant in units.values():
		var unit_root := value as Node
		if is_instance_valid(unit_root):
			allowed_roots.append(unit_root)
	var obstacle_cells: Dictionary = {}
	for obstacle in arena.obstacles:
		if obstacle != null and obstacle.blocks_movement:
			obstacle_cells[obstacle.cell] = true
	var tactical_nodes: Array[Dictionary] = []
	var observed_obstacle_cells: Dictionary = {}
	for field: String in ["walls", "decorations"]:
		for value: Variant in assembly.get(field, []):
			var node := value as Node2D
			if not is_instance_valid(node):
				errors.append("quiet_center_tactical_node_missing")
				continue
			var cell: Vector2i = node.get_meta("arena_cell", Vector2i(-1, -1))
			var valid: bool = obstacle_cells.has(cell) and grid.is_valid(cell) and not grid.is_walkable(cell)
			if not valid:
				errors.append("quiet_center_decoration_without_tactical_obstacle:%s" % cell)
			else:
				allowed_roots.append(node)
				observed_obstacle_cells[cell] = true
			tactical_nodes.append({"path": str(node.get_path()), "cell": [cell.x, cell.y], "legitimate_blocking_obstacle": valid})
	if obstacle_cells.size() != EXPECTED_TACTICAL_OBSTACLES or observed_obstacle_cells.size() != obstacle_cells.size():
		errors.append("quiet_center_twelve_tactical_obstacles_not_preserved")
	var external_sprites: Array[String] = []
	_collect_unclassified_sprites(terrain, allowed_roots, external_sprites)
	var world := battle.get_node_or_null("YSortedWorld")
	if world == null:
		errors.append("quiet_center_y_sorted_world_missing")
	else:
		_collect_unclassified_sprites(world, allowed_roots, external_sprites)
	if not external_sprites.is_empty():
		errors.append("quiet_center_unclassified_world_sprites:%d" % external_sprites.size())
	for path: String in ["PaintedBackground/BackgroundSprite", "PaintedForeground/ForegroundSprite"]:
		var legacy := battle.get_node_or_null(path) as CanvasItem
		if legacy != null and legacy.is_visible_in_tree():
			errors.append("quiet_center_legacy_painted_sprite_visible:" + path)
	var details := terrain.get_node_or_null("GroundDetails")
	var detail_style: Dictionary = plan.get("ground_details", {})
	var detail_fills: Variant = details.get("_fills") if details != null else null
	if bool(detail_style.get("enabled", true)) or not detail_fills is Array or not detail_fills.is_empty():
		errors.append("quiet_center_ground_details_not_disabled_or_still_drawn")
	var land := terrain.get_node_or_null("Land") as Polygon2D
	var land_z: int = _effective_z(land) if land != null else 0
	if land == null or not land.is_visible_in_tree() or land.texture == null:
		errors.append("quiet_center_live_land_missing")
	var checked := 0
	var neutral_joints := 0
	var floors_above_land := 0
	var invalid_joint_cells: Array = []
	for definition in arena.cells:
		if definition == null or not definition.defined or definition.cell_type == GridData.CellType.HOLE:
			continue
		var tile := renderer.node_for_cell(definition.coordinate)
		var sprite := tile.get_node_or_null("Visual") as Sprite2D if tile != null else null
		var material := sprite.material as ShaderMaterial if sprite != null else null
		checked += 1
		var weight: Variant = material.get_shader_parameter("interior_joint_land_weight") if material != null else null
		if (weight is float or weight is int) and absf(float(weight)) <= UNIFORM_TOLERANCE:
			neutral_joints += 1
		else:
			invalid_joint_cells.append([definition.coordinate.x, definition.coordinate.y])
		if sprite != null and land != null and _effective_z(sprite) > land_z:
			floors_above_land += 1
	if checked != EXPECTED_FLOOR_COUNT or neutral_joints != checked:
		errors.append("quiet_center_live_interior_joints_not_neutral:%d_of_%d" % [neutral_joints, checked])
	if floors_above_land != checked:
		errors.append("quiet_center_land_not_below_all_floor_sprites")
	return {
		"ok": errors.is_empty(), "errors": errors,
		"scope": "Room III only: no separate cosmetic world decor; twelve gameplay obstacles remain; live floor materials do not sample the land painting into interior joints.",
		"art_review_limit": "The flat painting rendered by Land still requires GPU visual review. Node and uniform checks do not certify the painting's composition or quietness.",
		"declared_world_decor_count": declared.size(), "runtime_external_decor_count": external.size(),
		"live_cosmetic_node_paths": tagged_nodes, "unclassified_world_sprite_paths": external_sprites,
		"tactical_obstacle_cells": obstacle_cells.size(), "tactical_obstacle_cells_with_visuals": observed_obstacle_cells.size(), "tactical_nodes": tactical_nodes,
		"ground_details_declared_enabled": bool(detail_style.get("enabled", true)),
		"ground_detail_fill_count": detail_fills.size() if detail_fills is Array else -1,
		"live_floor_materials_checked": checked, "interior_joint_land_weight_expected": 0.0,
		"neutral_interior_joint_materials": neutral_joints, "invalid_joint_cells": invalid_joint_cells,
		"land_effective_z_index": land_z, "floor_sprites_above_land": floors_above_land,
		"land_texture_path": land.texture.resource_path if land != null and land.texture != null else "",
	}

static func _collect_cosmetic_nodes(node: Node, result: Array[String]) -> void:
	if str(node.name).begins_with("WorldDecor_") or node.has_meta("terrain_decor_id") or node.has_meta("peripheral_prop_without_gameplay_blocker") or node.is_in_group("painted_foreground_occluders"):
		result.append(str(node.get_path()))
	for child: Node in node.get_children():
		_collect_cosmetic_nodes(child, result)

static func _collect_unclassified_sprites(node: Node, allowed_roots: Array[Node], result: Array[String]) -> void:
	if allowed_roots.has(node):
		return
	if node is Sprite2D:
		result.append(str(node.get_path()))
	for child: Node in node.get_children():
		_collect_unclassified_sprites(child, allowed_roots, result)

static func _effective_z(node: CanvasItem) -> int:
	var result: int = node.z_index
	var current: CanvasItem = node
	while current.z_as_relative:
		var parent := current.get_parent() as CanvasItem
		if parent == null:
			break
		result += parent.z_index
		current = parent
	return result
