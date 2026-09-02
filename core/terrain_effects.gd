class_name TerrainEffects
extends RefCounted

## Façade de compatibilité du combat. Toute l'autorité d'état, de durée,
## d'interaction et de restauration vit dans TerrainSurfaceRuntimeService.

signal surface_applied(fact: Dictionary)
signal surface_replaced(fact: Dictionary)
signal surface_refreshed(fact: Dictionary)
signal surface_cleared(fact: Dictionary)
signal surface_reaction(fact: Dictionary)
signal duration_changed(fact: Dictionary)

const LogDefinitions = preload("res://debug/log_definitions.gd")
const CAT: LogDefinitions.LogCategory = LogDefinitions.LogCategory.TERRAIN
const DURATION_UNSET := TerrainSurfaceRuntimeService.DURATION_UNSET

var _grid: GridData
var runtime_service: TerrainSurfaceRuntimeService


func _init(grid: GridData) -> void:
	_grid = grid
	runtime_service = TerrainSurfaceRuntimeService.new(grid)
	runtime_service.surface_applied.connect(
		func(fact: Dictionary): surface_applied.emit(fact)
	)
	runtime_service.surface_replaced.connect(
		func(fact: Dictionary): surface_replaced.emit(fact)
	)
	runtime_service.surface_refreshed.connect(
		func(fact: Dictionary): surface_refreshed.emit(fact)
	)
	runtime_service.surface_cleared.connect(
		func(fact: Dictionary): surface_cleared.emit(fact)
	)
	runtime_service.surface_reaction.connect(
		func(fact: Dictionary): surface_reaction.emit(fact)
	)
	runtime_service.duration_changed.connect(
		func(fact: Dictionary): duration_changed.emit(fact)
	)


func capture_base_state(room_data = null, grid: GridData = null) -> Dictionary:
	return runtime_service.capture_base_state(room_data, grid)


func place_effect(
		cell: Vector2i,
		effect: TerrainEffectData,
		caster = null,
		source_spell: Spell = null,
		duration_override: int = DURATION_UNSET
	) -> Dictionary:
	return runtime_service.place_effect(
		cell, effect, caster, source_spell, duration_override
	)


func clear_effect(cell: Vector2i) -> bool:
	return runtime_service.clear_effect(cell)


func get_effect_data(cell: Vector2i) -> TerrainEffectData:
	return runtime_service.get_effect_data(cell)


func get_ai_danger_weight(cell: Vector2i) -> float:
	return runtime_service.get_ai_danger_weight(cell)


func on_turn_start(unit: Unit) -> void:
	runtime_service.on_turn_start(unit)


func on_enter_cell(unit: Unit, cell: Vector2i) -> Dictionary:
	return runtime_service.on_enter_cell(unit, cell)


func begin_unit_resolution(unit: Unit, reason: StringName = &"movement") -> StringName:
	return runtime_service.begin_unit_resolution(unit, reason)


func end_unit_resolution(unit: Unit) -> void:
	runtime_service.end_unit_resolution(unit)


func consume_last_entry_result(unit: Unit) -> Dictionary:
	return runtime_service.consume_last_entry_result(unit)


## Consomme la résolution synchrone déclenchée par GridData.relocate_unit().
## Un terrain (notamment un vortex) peut avoir déplacé l'unité une seconde fois
## avant le retour de relocate_unit : la case réellement occupée est alors la
## destination autoritaire pour les rapports et la présentation.
func consume_relocation_result(
		unit: Unit,
		requested_destination: Vector2i
	) -> Dictionary:
	var result := consume_last_entry_result(unit)
	if result.is_empty():
		result = {
			"entry_cell": requested_destination,
			"destination": requested_destination,
		}
	var resolved_destination: Vector2i = result.get(
		"destination", requested_destination
	) as Vector2i
	if _grid != null and unit != null:
		var occupied_cell := _grid.find_unit(unit)
		if occupied_cell != Vector2i(-1, -1):
			resolved_destination = occupied_cell
	result["requested_destination"] = requested_destination
	result["destination"] = resolved_destination
	return result


func tick_all_effects() -> void:
	runtime_service.tick_all_effects()


func reset() -> void:
	runtime_service.reset()


func can_receive_surface(cell: Vector2i, effect: TerrainEffectData = null) -> bool:
	return runtime_service.can_receive_surface(cell, effect)


func surface_eligibility(cell: Vector2i, effect: TerrainEffectData = null) -> Dictionary:
	return runtime_service.eligibility_report(cell, effect)


func get_surface_state(cell: Vector2i) -> CellSurfaceState:
	return runtime_service.get_state(cell)


func get_surface_id(cell: Vector2i) -> StringName:
	return runtime_service.get_surface_id(cell)


func get_visual_terrain_id(cell: Vector2i) -> StringName:
	return runtime_service.get_visual_terrain_id(cell)


func get_remaining_duration(cell: Vector2i) -> int:
	return runtime_service.get_remaining_duration(cell)


func get_base_state(cell: Vector2i) -> Dictionary:
	return runtime_service.get_base_state(cell)


func active_surface_cells() -> Array[Vector2i]:
	return runtime_service.active_surface_cells()
