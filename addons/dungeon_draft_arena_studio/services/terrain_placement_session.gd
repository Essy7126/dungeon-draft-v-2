@tool
class_name TerrainPlacementSession
extends RefCounted

## Geste composite pour les contenus qui demandent plusieurs clics. La working
## copy peut servir de preview, mais une seule paire before/after est remise à
## l'historique lors de la finalisation. Échap restaure exactement `before`.

var definition: TerrainPlaceableDefinition = null
var before_snapshot := {}
var placed_cells: Array[Vector2i] = []
var vortex_network_id: StringName = &""
var active := false


func begin(arena: ArenaDefinition, value: TerrainPlaceableDefinition) -> bool:
	if arena == null or value == null:
		return false
	definition = value
	before_snapshot = arena.to_snapshot().duplicate(true)
	placed_cells.clear()
	vortex_network_id = &""
	active = true
	return true


func add_cell(arena: ArenaDefinition, cell: Vector2i) -> Dictionary:
	if not active or arena == null or definition == null:
		return {"changed": false, "complete": false, "reason": "inactive"}
	if definition.placement_kind not in [
		TerrainPlaceableDefinition.PlacementKind.VORTEX_IMPULSE,
		TerrainPlaceableDefinition.PlacementKind.VORTEX_PORTAL_TWO,
		TerrainPlaceableDefinition.PlacementKind.VORTEX_PORTAL_MULTI,
	]:
		return {"changed": false, "complete": false, "reason": "not_multi_click"}
	if not ArenaDynamicEditingService.is_valid_vortex_cell(arena, cell):
		return {"changed": false, "complete": false, "reason": "invalid_cell"}
	if vortex_network_id == &"":
		var network := ArenaVortexNetworkService.create_network(
			arena, definition.display_name
		)
		if network == null:
			return {"changed": false, "complete": false, "reason": "network_failed"}
		vortex_network_id = network.network_id
	if not ArenaVortexNetworkService.add_cell(arena, vortex_network_id, cell):
		return {"changed": false, "complete": false, "reason": "occupied"}
	placed_cells.append(cell)
	return {
		"changed": true,
		"complete": _finite_complete(),
		"count": placed_cells.size(),
		"minimum": definition.minimum_cells,
		"network_id": vortex_network_id,
	}


func remove_cell(arena: ArenaDefinition, cell: Vector2i) -> bool:
	if not active or arena == null or vortex_network_id == &"":
		return false
	if not ArenaVortexNetworkService.remove_cell(arena, vortex_network_id, cell):
		return false
	placed_cells.erase(cell)
	return true


func can_finish() -> bool:
	return active and definition != null \
		and placed_cells.size() >= definition.minimum_cells


func finish(arena: ArenaDefinition) -> Dictionary:
	if arena == null or not can_finish():
		return {"ok": false, "reason": "minimum_not_reached"}
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	var result := {
		"ok": true,
		"action_name": "Placer %s" % definition.display_name,
		"before": before_snapshot.duplicate(true),
		"after": arena.to_snapshot().duplicate(true),
		"network_id": vortex_network_id,
	}
	_clear()
	return result


func cancel(arena: ArenaDefinition) -> bool:
	if not active or arena == null or before_snapshot.is_empty():
		return false
	var authoring := arena.authoring_document
	var restored := arena.restore_snapshot(before_snapshot)
	arena.authoring_document = authoring
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	_clear()
	return restored


func instruction() -> String:
	if not active or definition == null:
		return ""
	var count := placed_cells.size()
	if definition.maximum_cells == 1:
		return "Cliquez la case à utiliser."
	if definition.maximum_cells == 2:
		return "Choisissez la seconde case." if count == 1 \
			else "Choisissez la première case."
	if count < definition.minimum_cells:
		return "Choisissez encore %d case(s)." % (definition.minimum_cells - count)
	return "%d cases reliées — ajoutez une sortie ou terminez le placement." % count


func _finite_complete() -> bool:
	return definition != null and definition.maximum_cells > 0 \
		and placed_cells.size() >= definition.maximum_cells


func _clear() -> void:
	definition = null
	before_snapshot = {}
	placed_cells.clear()
	vortex_network_id = &""
	active = false
