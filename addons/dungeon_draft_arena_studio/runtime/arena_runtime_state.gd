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
var terrain_effects: TerrainEffects = null
var surface_service := DynamicSurfaceService.new()


func configure_surfaces(
		configs: Array[SurfaceConfig],
		room_data = null
	) -> void:
	if grid == null:
		return
	terrain_effects = TerrainEffects.new(grid)
	terrain_effects.capture_base_state(room_data, grid)
	surface_service.configure(grid, configs, terrain_effects.runtime_service)
	if not surface_service.surface_changed.is_connected(_on_surface_changed):
		surface_service.surface_changed.connect(_on_surface_changed)


func update_surface(cell: Vector2i, surface: int, source_unit = null) -> Dictionary:
	var result := surface_service.apply_surface_effect(cell, surface, source_unit)
	result["cell"] = cell
	result["grid_type"] = grid.get_type(cell) if grid != null and grid.is_valid(cell) else -1
	return result


func clear_surface(cell: Vector2i) -> bool:
	return surface_service.clear_surface(cell)


func apply_terrain_effect(
		cell: Vector2i,
		effect: TerrainEffectData,
		source_unit = null,
		source_spell: Spell = null,
		duration_override: int = TerrainSurfaceRuntimeService.DURATION_UNSET
	) -> Dictionary:
	return surface_service.apply_terrain_effect(
		cell, effect, source_unit, source_spell, duration_override
	)


func advance_surface_tick() -> void:
	if terrain_effects != null:
		terrain_effects.tick_all_effects()


func _on_surface_changed(cell: Vector2i, previous_surface: int, surface: int) -> void:
	cell_surface_changed.emit(cell, previous_surface, surface)
