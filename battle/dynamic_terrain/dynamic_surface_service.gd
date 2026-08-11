class_name DynamicSurfaceService
extends RefCounted

## Façade de compatibilité du Lab et des anciennes previews. Elle ne possède
## aucun état : toutes les lectures et mutations délèguent au service runtime
## partagé avec TerrainEffects.

signal surface_changed(cell: Vector2i, previous_surface: int, surface: int)
signal steam_requested(cell: Vector2i)
signal surface_reaction(fact: Dictionary)

var grid: GridData = null
var configs: Dictionary = {}
var runtime_service: TerrainSurfaceRuntimeService = null


func configure(
		grid_data: GridData,
		surface_configs: Array[SurfaceConfig],
		shared_runtime: TerrainSurfaceRuntimeService = null
	) -> void:
	assert(grid_data != null, "DynamicSurfaceService requiert le GridData existant.")
	_disconnect_runtime()
	grid = grid_data
	configs.clear()
	for config in surface_configs:
		if config != null:
			configs[config.surface] = config
	runtime_service = shared_runtime
	if runtime_service == null:
		runtime_service = TerrainSurfaceRuntimeService.new(grid)
		runtime_service.capture_base_state(null, grid)
	elif runtime_service.grid != grid:
		runtime_service.configure(grid)
		runtime_service.capture_base_state(null, grid)
	runtime_service.surface_changed.connect(_on_runtime_surface_changed)
	runtime_service.steam_requested.connect(_on_runtime_steam_requested)
	runtime_service.surface_reaction.connect(_on_runtime_surface_reaction)


func apply_surface_effect(cell: Vector2i, effect: int, source_unit = null) -> Dictionary:
	var terrain_effect := _compatibility_effect(effect, false)
	if terrain_effect == null:
		return {"handled": false, "surface": get_surface(cell), "steam": false}
	var placed := runtime_service.place_effect(cell, terrain_effect, source_unit)
	return {
		"handled": bool(placed.get("changed", false)) \
			or bool(placed.get("same", false)),
		"surface": get_surface(cell),
		"steam": str(placed.get("reaction", "")) == "steam",
		"previous_surface": TerrainSurfaceIdResolver.dynamic_surface(
			StringName((placed.get("terrain_event", {}) as Dictionary).get(
				"previous_surface", &"none"
			))
		),
		"reaction": placed.get("reaction", ""),
		"terrain_event": placed.get("terrain_event", {}),
	}


func apply_terrain_effect(
		cell: Vector2i,
		effect: TerrainEffectData,
		source_unit = null,
		source_spell: Spell = null,
		duration_override: int = TerrainSurfaceRuntimeService.DURATION_UNSET
	) -> Dictionary:
	return runtime_service.place_effect(
		cell, effect, source_unit, source_spell, duration_override
	)


func set_surface(cell: Vector2i, surface: int, source_unit = null) -> bool:
	var terrain_effect := _compatibility_effect(surface, true)
	if terrain_effect == null:
		return false
	return bool(runtime_service.place_effect(
		cell, terrain_effect, source_unit
	).get("changed", false))


func clear_surface(cell: Vector2i) -> bool:
	return runtime_service != null and runtime_service.clear_effect(cell)


func refresh_surface_layer() -> void:
	# L'état et GridData sont synchronisés à chaque mutation par l'autorité
	# runtime. Cette méthode historique reste volontairement idempotente.
	pass


func advance_turn() -> Array[Vector2i]:
	var before := active_cells()
	runtime_service.tick_all_effects()
	var after := active_cells()
	var expired: Array[Vector2i] = []
	for cell in before:
		if not after.has(cell):
			expired.append(cell)
	return expired


func refresh_cell(_cell: Vector2i) -> void:
	# Conservé pour compatibilité ; aucune seconde écriture n'est nécessaire.
	pass


func reset() -> void:
	if runtime_service != null:
		runtime_service.reset()


func has_state(cell: Vector2i) -> bool:
	return runtime_service != null and runtime_service.has_state(cell)


func get_state(cell: Vector2i) -> CellSurfaceState:
	return runtime_service.get_state(cell) if runtime_service != null else null


func get_surface(cell: Vector2i) -> int:
	return runtime_service.get_surface(cell) \
		if runtime_service != null else CellSurfaceState.DynamicSurface.NONE


func get_surface_id(cell: Vector2i) -> StringName:
	return runtime_service.get_surface_id(cell) \
		if runtime_service != null else &"none"


func get_visual_terrain_id(cell: Vector2i) -> StringName:
	return runtime_service.get_visual_terrain_id(cell) \
		if runtime_service != null else &""


func get_remaining_duration(cell: Vector2i) -> int:
	return runtime_service.get_remaining_duration(cell) \
		if runtime_service != null else 0


func get_turn_start_damage(cell: Vector2i) -> int:
	var config := configs.get(get_surface(cell)) as SurfaceConfig
	return config.turn_start_damage if config != null else 0


func is_surface_walkable(cell: Vector2i) -> bool:
	if not has_state(cell):
		return false
	var config := configs.get(get_surface(cell)) as SurfaceConfig
	return config == null or config.walkable


func get_movement_cost(cell: Vector2i) -> int:
	var config := configs.get(get_surface(cell)) as SurfaceConfig
	return config.movement_cost if config != null else 1


func state_count() -> int:
	return runtime_service.state_count() if runtime_service != null else 0


func state_cells() -> Array[Vector2i]:
	return runtime_service.state_cells() \
		if runtime_service != null else [] as Array[Vector2i]


func active_cells() -> Array[Vector2i]:
	return runtime_service.active_surface_cells() \
		if runtime_service != null else [] as Array[Vector2i]


func _compatibility_effect(surface: int, replace_same: bool) -> TerrainEffectData:
	var config := configs.get(surface) as SurfaceConfig
	if config == null or surface == CellSurfaceState.DynamicSurface.NONE:
		return null
	var effect := TerrainEffectData.new()
	effect.effect_name = config.display_name.to_lower()
	effect.surface_id = TerrainSurfaceIdResolver.surface_id_for_dynamic(surface)
	effect.visual_terrain_id = TerrainSurfaceIdResolver.visual_id_for_surface(
		effect.surface_id
	)
	effect.duration = config.duration_turns
	effect.damage = config.turn_start_damage
	effect.trigger = TerrainEffectData.Trigger.TURN_START
	effect.same_surface_policy = (
		TerrainEffectData.SameSurfacePolicy.REPLACE
		if replace_same else TerrainEffectData.SameSurfacePolicy.IGNORE
	)
	return effect


func _on_runtime_surface_changed(
		cell: Vector2i,
		previous_surface: int,
		surface: int
	) -> void:
	surface_changed.emit(cell, previous_surface, surface)


func _on_runtime_steam_requested(cell: Vector2i) -> void:
	steam_requested.emit(cell)


func _on_runtime_surface_reaction(fact: Dictionary) -> void:
	surface_reaction.emit(fact)


func _disconnect_runtime() -> void:
	if runtime_service == null:
		return
	if runtime_service.surface_changed.is_connected(_on_runtime_surface_changed):
		runtime_service.surface_changed.disconnect(_on_runtime_surface_changed)
	if runtime_service.steam_requested.is_connected(_on_runtime_steam_requested):
		runtime_service.steam_requested.disconnect(_on_runtime_steam_requested)
	if runtime_service.surface_reaction.is_connected(_on_runtime_surface_reaction):
		runtime_service.surface_reaction.disconnect(_on_runtime_surface_reaction)
