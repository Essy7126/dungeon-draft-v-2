class_name DynamicSurfaceVisualAdapter
extends Node

signal cell_visual_updated(cell: Vector2i, surface: int)
signal reaction_visual_updated(cell: Vector2i, reaction_id: StringName, visible: bool)

var surface_service = null
var renderer: ArenaTerrainVisualRenderer = null
var theme_id: StringName = &"forest"
var _visual_parent: Node2D = null
var _base_visibility: Dictionary = {}
var _reaction_generation: Dictionary = {}


func configure(
		service,
		grid_view: Node2D,
		visual_parent: Node2D,
		resolved_theme_id: StringName = &"forest"
	) -> void:
	_disconnect_service()
	_restore_all_base_visuals()
	_reaction_generation.clear()
	surface_service = service
	theme_id = resolved_theme_id
	_visual_parent = visual_parent
	if renderer == null:
		renderer = ArenaTerrainVisualRenderer.new()
		renderer.name = "DynamicSurfaceOverlayRenderer"
		add_child(renderer)
	renderer.configure(grid_view, visual_parent)
	if surface_service != null:
		surface_service.surface_changed.connect(_on_surface_changed)
		surface_service.surface_reaction.connect(_on_surface_reaction)
		for cell in surface_service.state_cells():
			refresh_cell(cell)


func refresh_cell(cell: Vector2i) -> void:
	if renderer == null or surface_service == null:
		return
	var surface_id: StringName = surface_service.get_surface_id(cell)
	var visual_id: StringName = surface_service.get_visual_terrain_id(cell)
	var surface: int = surface_service.get_surface(cell)
	var visual := TerrainSurfaceVisualResolver.resolve(visual_id, theme_id)
	if surface_id == &"none" or not bool(visual.get("ok", false)):
		renderer.remove_cells([cell])
		_set_base_visible(cell, true)
		cell_visual_updated.emit(cell, CellSurfaceState.DynamicSurface.NONE)
		return
	_set_base_visible(cell, false)
	var texture := visual.texture as Texture2D
	_render_visual(cell, visual_id, texture, {
		"visual_layer": &"arena_dynamic_surface",
		"renderer_role": &"dynamic_surface",
		"surface_id": surface_id,
		"visual_terrain_id": visual_id,
		"node_prefix": "ArenaDynamicSurface",
	})
	cell_visual_updated.emit(cell, surface)


func _render_visual(
		cell: Vector2i,
		visual_id: StringName,
		texture: Texture2D,
		metadata: Dictionary
	) -> void:
	if renderer == null or texture == null or surface_service == null \
			or surface_service.grid == null:
		return
	var entry := {
		"cell": cell,
		"visible": true,
		"texture": texture,
		"texture_path": texture.resource_path,
		"terrain_id": visual_id,
		"cell_type": surface_service.grid.get_type(cell),
		"parent_role": &"arena_dynamic_surface_layer",
	}
	entry.merge(metadata, true)
	renderer.update_cells([entry], false)


func node_for_cell(cell: Vector2i) -> Node2D:
	return renderer.node_for_cell(cell) if renderer != null else null


func rendered_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if renderer == null:
		return result
	for key in (renderer.actual_render_report().get("cells", {}) as Dictionary):
		var parts := str(key).split(",")
		if parts.size() == 2:
			result.append(Vector2i(int(parts[0]), int(parts[1])))
	return result


func _on_surface_changed(cell: Vector2i, _previous: int, _surface: int) -> void:
	_reaction_generation[cell] = int(_reaction_generation.get(cell, 0)) + 1
	refresh_cell(cell)


func _on_surface_reaction(fact: Dictionary) -> void:
	var reaction_id := StringName(fact.get("reaction", &""))
	var definition := ArenaCatalogService.surface_visual_for_reaction(reaction_id)
	if definition == null or not definition.runtime_supported \
			or definition.texture == null:
		return
	var cell = fact.get("cell", GridTransformService.INVALID_CELL)
	if not cell is Vector2i or cell == GridTransformService.INVALID_CELL:
		return
	var generation := int(_reaction_generation.get(cell, 0)) + 1
	_reaction_generation[cell] = generation
	_set_base_visible(cell, false)
	_render_visual(cell, definition.stable_id, definition.texture, {
		"visual_layer": &"arena_surface_reaction",
		"renderer_role": &"surface_reaction",
		"surface_id": StringName(fact.get("previous_surface", &"none")),
		"visual_terrain_id": definition.stable_id,
		"reaction_id": reaction_id,
		"node_prefix": "ArenaSurfaceReaction",
	})
	reaction_visual_updated.emit(cell, reaction_id, true)
	if definition.display_duration_seconds > 0.0:
		await get_tree().create_timer(definition.display_duration_seconds).timeout
	else:
		# Aucun temps gameplay n'est inventé : l'asset est exposé pendant une
		# frame complète, puis l'état canonique de la cellule reprend autorité.
		# Deux fronts process garantissent qu'un rendu se place entre les deux,
		# y compris avec le renderer headless utilisé par les tests.
		await get_tree().process_frame
		await get_tree().process_frame
	if int(_reaction_generation.get(cell, -1)) != generation:
		return
	_reaction_generation.erase(cell)
	refresh_cell(cell)
	reaction_visual_updated.emit(cell, reaction_id, false)


func _set_base_visible(cell: Vector2i, visible: bool) -> void:
	for node in _base_visuals(cell):
		var canvas := node as CanvasItem
		if visible:
			if _base_visibility.has(canvas):
				canvas.visible = bool(_base_visibility[canvas])
				_base_visibility.erase(canvas)
		else:
			if not _base_visibility.has(canvas):
				_base_visibility[canvas] = canvas.visible
			canvas.visible = false


func _base_visuals(cell: Vector2i) -> Array[CanvasItem]:
	var result: Array[CanvasItem] = []
	if _visual_parent == null or _visual_parent.get_parent() == null:
		return result
	_collect_base_visuals(_visual_parent.get_parent(), cell, result)
	return result


func _collect_base_visuals(
		node: Node,
		cell: Vector2i,
		result: Array[CanvasItem]
	) -> void:
	if node == _visual_parent:
		return
	if node is CanvasItem \
			and node.get_meta("arena_cell", GridTransformService.INVALID_CELL) == cell \
			and StringName(node.get_meta("renderer_role", &"")) in [
				&"arena_floor", &"terrain_floor"
			]:
		result.append(node as CanvasItem)
	for child in node.get_children():
		_collect_base_visuals(child, cell, result)


func _restore_all_base_visuals() -> void:
	for node in _base_visibility.keys():
		if is_instance_valid(node):
			(node as CanvasItem).visible = bool(_base_visibility[node])
	_base_visibility.clear()


func _disconnect_service() -> void:
	if surface_service != null \
			and surface_service.surface_changed.is_connected(_on_surface_changed):
		surface_service.surface_changed.disconnect(_on_surface_changed)
	if surface_service != null \
			and surface_service.surface_reaction.is_connected(_on_surface_reaction):
		surface_service.surface_reaction.disconnect(_on_surface_reaction)


func _exit_tree() -> void:
	_disconnect_service()
	_restore_all_base_visuals()
	if renderer != null:
		renderer.clear()
