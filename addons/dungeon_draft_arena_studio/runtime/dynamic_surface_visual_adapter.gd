class_name DynamicSurfaceVisualAdapter
extends Node

signal cell_visual_updated(cell: Vector2i, surface: int)

var surface_service: DynamicSurfaceService = null
var renderer: ArenaTerrainVisualRenderer = null


func configure(
		service: DynamicSurfaceService,
		grid_view: Node2D,
		visual_parent: Node2D
	) -> void:
	_disconnect_service()
	surface_service = service
	if renderer == null:
		renderer = ArenaTerrainVisualRenderer.new()
		renderer.name = "DynamicSurfaceOverlayRenderer"
		add_child(renderer)
	renderer.configure(grid_view, visual_parent)
	if surface_service != null:
		surface_service.surface_changed.connect(_on_surface_changed)
		for cell in surface_service.state_cells():
			refresh_cell(cell)


func refresh_cell(cell: Vector2i) -> void:
	if renderer == null or surface_service == null:
		return
	var surface := surface_service.get_surface(cell)
	var config := surface_service.configs.get(surface) as SurfaceConfig
	if surface == CellSurfaceState.DynamicSurface.NONE or config == null \
			or config.texture == null:
		renderer.remove_cells([cell])
		cell_visual_updated.emit(cell, CellSurfaceState.DynamicSurface.NONE)
		return
	renderer.update_cells([{
		"cell": cell,
		"visible": true,
		"texture": config.texture,
		"texture_path": config.texture.resource_path,
		"terrain_id": StringName("dynamic_%s" % config.display_name.to_lower()),
		"cell_type": surface_service.grid.get_type(cell),
		"visual_layer": &"dynamic_surface_overlay",
	}])
	cell_visual_updated.emit(cell, surface)


func node_for_cell(cell: Vector2i) -> Node2D:
	return renderer.node_for_cell(cell) if renderer != null else null


func _on_surface_changed(cell: Vector2i, _previous: int, _surface: int) -> void:
	refresh_cell(cell)


func _disconnect_service() -> void:
	if surface_service != null \
			and surface_service.surface_changed.is_connected(_on_surface_changed):
		surface_service.surface_changed.disconnect(_on_surface_changed)


func _exit_tree() -> void:
	_disconnect_service()
	if renderer != null:
		renderer.clear()
