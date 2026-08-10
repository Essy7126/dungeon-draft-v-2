class_name ArenaRuntimeState
extends RefCounted

signal cell_surface_changed(cell: Vector2i, previous_surface: int, surface: int)

var source_fingerprint := ""
var arena_projection: ArenaDefinition = null
var grid: GridData = null
var layout: RoomGridLayout = null
var visual_data: PaintedMapVisualData = null
var visual_profile: ArenaVisualProfile = null
var hero_spawns: Array[Vector2i] = []
var enemy_spawns: Array[Vector2i] = []
var surface_resolution := {}
var surface_service := DynamicSurfaceService.new()


func configure_surfaces(configs: Array[SurfaceConfig]) -> void:
	if grid == null:
		return
	surface_service.configure(grid, configs)
	if not surface_service.surface_changed.is_connected(_on_surface_changed):
		surface_service.surface_changed.connect(_on_surface_changed)


func update_surface(cell: Vector2i, surface: int, source_unit = null) -> Dictionary:
	var result := surface_service.apply_surface_effect(cell, surface, source_unit)
	result["cell"] = cell
	result["grid_type"] = grid.get_type(cell) if grid != null and grid.is_valid(cell) else -1
	return result


func clear_surface(cell: Vector2i) -> bool:
	return surface_service.clear_surface(cell)


func _on_surface_changed(cell: Vector2i, previous_surface: int, surface: int) -> void:
	cell_surface_changed.emit(cell, previous_surface, surface)
