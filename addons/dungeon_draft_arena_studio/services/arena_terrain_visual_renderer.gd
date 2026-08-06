@tool
class_name ArenaTerrainVisualRenderer
extends Node

var _grid_view: Node2D = null
var _visual_parent: Node2D = null
var _nodes: Dictionary = {}
var _entries: Dictionary = {}
var _texture_cache: Dictionary = {}
var _last_geometry_signature := PackedVector2Array()


func configure(grid_view: Node2D, visual_parent: Node2D) -> void:
	_grid_view = grid_view
	_visual_parent = visual_parent
	set_process(true)


func render_plan(plan: Dictionary) -> Dictionary:
	clear()
	update_cells(plan.get("entries", []))
	return actual_render_report()


func update_cells(entries: Array) -> void:
	if _visual_parent == null:
		return
	for value in entries:
		if not value is Dictionary:
			continue
		var entry := value as Dictionary
		var cell: Vector2i = entry.get("cell", Vector2i.ZERO)
		_entries[cell] = entry.duplicate(false)
		if not bool(entry.get("visible", false)) or entry.get("texture") == null:
			remove_cells([cell])
			continue
		_create_or_update(entry)
	_last_geometry_signature = _geometry_signature()


func remove_cells(cells: Array) -> void:
	for value in cells:
		if not value is Vector2i:
			continue
		var cell := value as Vector2i
		var node_value = _nodes.get(cell)
		if is_instance_valid(node_value):
			(node_value as Node2D).free()
		_nodes.erase(cell)
		_entries.erase(cell)


func clear() -> void:
	for value in _nodes.values():
		if is_instance_valid(value):
			(value as Node2D).free()
	_nodes.clear()
	_entries.clear()


func actual_render_report() -> Dictionary:
	var rendered_by := {}
	var cells := {}
	var errors: Array[String] = []
	for cell in _nodes:
		var root_value = _nodes[cell]
		if not is_instance_valid(root_value):
			errors.append("invalid_node:%s" % cell)
			continue
		var root := root_value as Node2D
		var sprite := root.get_node_or_null("Visual") as Sprite2D
		var terrain_id := str(root.get_meta("terrain_id", &""))
		if sprite == null or sprite.texture == null:
			errors.append("texture_missing:%s" % cell)
			continue
		rendered_by[terrain_id] = int(rendered_by.get(terrain_id, 0)) + 1
		cells["%d,%d" % [cell.x, cell.y]] = {
			"terrain_id": terrain_id,
			"cell_type": int(root.get_meta("cell_type", GridData.CellType.HOLE)),
			"texture_path": sprite.texture.resource_path,
			"position": root.position,
			"transform": sprite.transform,
			"visible": root.visible and sprite.visible,
		}
	return {
		"rendered_terrain_node_count": cells.size(),
		"rendered_by_terrain_id": rendered_by,
		"cells": cells,
		"errors": errors,
		"valid": errors.is_empty(),
	}


func node_for_cell(cell: Vector2i) -> Node2D:
	var value = _nodes.get(cell)
	return value as Node2D if is_instance_valid(value) else null


func texture_for_cell(cell: Vector2i) -> Texture2D:
	var root := node_for_cell(cell)
	var sprite := root.get_node_or_null("Visual") as Sprite2D if root != null else null
	return sprite.texture if sprite != null else null


func _process(_delta: float) -> void:
	var signature := _geometry_signature()
	if _signatures_match(signature, _last_geometry_signature):
		return
	_last_geometry_signature = signature
	for cell in _nodes:
		_update_transform(cell, _nodes[cell] as Node2D)


func _create_or_update(entry: Dictionary) -> void:
	var cell: Vector2i = entry.cell
	var root := node_for_cell(cell)
	if root == null:
		root = Node2D.new()
		root.name = "ArenaTerrain_%d_%d" % [cell.x, cell.y]
		_visual_parent.add_child(root)
		_nodes[cell] = root
		var sprite := Sprite2D.new()
		sprite.name = "Visual"
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		root.add_child(sprite)
	var texture := entry.texture as Texture2D
	var texture_path := str(entry.get("texture_path", ""))
	if not texture_path.is_empty():
		_texture_cache[texture_path] = texture
	var visual := root.get_node("Visual") as Sprite2D
	visual.texture = texture
	visual.modulate = Color.WHITE
	root.set_meta("arena_cell", cell)
	root.set_meta("grid_cell", cell)
	root.set_meta("terrain_id", entry.terrain_id)
	root.set_meta("cell_type", int(entry.cell_type))
	root.set_meta("renderer_layer", entry.visual_layer)
	root.visible = true
	_update_transform(cell, root)


func _update_transform(cell: Vector2i, root: Node2D) -> void:
	if root == null or _visual_parent == null:
		return
	var sprite := root.get_node_or_null("Visual") as Sprite2D
	if sprite == null or sprite.texture == null:
		return
	var polygon := _cell_polygon_in_parent(cell)
	if polygon.size() < 4:
		return
	var center := Vector2.ZERO
	for point in polygon:
		center += point
	center /= float(polygon.size())
	root.position = center
	sprite.transform = ArenaTileProjectionService.sprite_transform(
		sprite.texture, polygon, center
	)


func _cell_polygon_in_parent(cell: Vector2i) -> PackedVector2Array:
	var converted := PackedVector2Array()
	if _grid_view != null and _grid_view.has_method("get_cell_polygon"):
		for point in _grid_view.get_cell_polygon(cell):
			converted.append(_visual_parent.to_local(_grid_view.to_global(point)))
		return converted
	var entry := _entries.get(cell, {}) as Dictionary
	for point in entry.get("polygon", PackedVector2Array()):
		converted.append(point)
	return converted


func _geometry_signature() -> PackedVector2Array:
	if _grid_view == null or _visual_parent == null \
			or not _grid_view.has_method("get_cell_polygon"):
		return PackedVector2Array()
	return _cell_polygon_in_parent(Vector2i.ZERO)


func _signatures_match(first: PackedVector2Array, second: PackedVector2Array) -> bool:
	if first.size() != second.size():
		return false
	for index in range(first.size()):
		if not first[index].is_equal_approx(second[index]):
			return false
	return true
