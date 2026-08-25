@tool
class_name ArenaVortexNetworkService
extends RefCounted


static func migrate_legacy_pairs(arena: ArenaDefinition) -> int:
	if arena == null:
		return 0
	var migrated := 0
	for pair in arena.vortex_pairs:
		if pair == null:
			continue
		var existing := arena.vortex_networks.filter(func(value):
			return value != null and value.cells.has(pair.entry_cell) \
				and value.cells.has(pair.exit_cell)
		)
		if not existing.is_empty():
			continue
		var network := ArenaVortexNetworkDefinition.new()
		network.network_id = pair.pair_id if pair.pair_id != &"" \
			else next_network_id(arena)
		network.display_name = "Vortex migré %s" % network.network_id
		network.cells = [pair.entry_cell, pair.exit_cell]
		network.enabled = pair.runtime_enabled
		network.random_destination = false
		network.production_notes = "Migré automatiquement depuis vortex_pairs."
		arena.vortex_networks.append(network)
		migrated += 1
	return migrated


static func create_network(arena: ArenaDefinition, display_name := "") -> ArenaVortexNetworkDefinition:
	if arena == null:
		return null
	var network := ArenaVortexNetworkDefinition.new()
	network.network_id = next_network_id(arena)
	network.display_name = display_name.strip_edges() if not display_name.strip_edges().is_empty() \
		else "Réseau %d" % (arena.vortex_networks.size() + 1)
	network.editor_color = color_for_id(network.network_id)
	arena.vortex_networks.append(network)
	return network


static func add_cell(
		arena: ArenaDefinition,
		network_id: StringName,
		cell: Vector2i
	) -> bool:
	var network := network_by_id(arena, network_id)
	if network == null or not ArenaDynamicEditingService.is_valid_vortex_cell(arena, cell):
		return false
	var occupied := arena.vortex_network_at(cell)
	if occupied != null and occupied != network:
		return false
	if network.cells.has(cell):
		return false
	network.cells.append(cell)
	return true


static func remove_cell(arena: ArenaDefinition, network_id: StringName, cell: Vector2i) -> bool:
	var network := network_by_id(arena, network_id)
	if network == null or not network.cells.has(cell):
		return false
	network.cells.erase(cell)
	return true


static func delete_network(arena: ArenaDefinition, network_id: StringName) -> bool:
	var network := network_by_id(arena, network_id)
	if network == null:
		return false
	arena.vortex_networks.erase(network)
	return true


static func network_by_id(
		arena: ArenaDefinition,
		network_id: StringName
	) -> ArenaVortexNetworkDefinition:
	if arena == null:
		return null
	for network in arena.vortex_networks:
		if network != null and network.network_id == network_id:
			return network
	return null


static func next_network_id(arena: ArenaDefinition) -> StringName:
	var used := {}
	for network in arena.vortex_networks:
		if network != null:
			used[network.network_id] = true
	var index := 1
	while used.has(StringName("vortex_network_%03d" % index)):
		index += 1
	return StringName("vortex_network_%03d" % index)


static func behavior_summary(network: ArenaVortexNetworkDefinition) -> String:
	if network == null:
		return "Effet vortex absent"
	match network.unique_cells().size():
		0: return "Aucune case placée"
		1: return "Case d'impulsion — +1 déplacement une fois par round"
		2: return "Portail entre deux cases"
		_: return "Portail à plusieurs sorties — %d cases" % network.unique_cells().size()


static func color_for_id(network_id: StringName) -> Color:
	var hue := float(absi(String(network_id).hash()) % 360) / 360.0
	return Color.from_hsv(hue, 0.62, 1.0, 1.0)


static func evaluate_for_ai(
		grid: GridData,
		entry: Vector2i,
		target: Vector2i,
		unit: Unit = null
	) -> Dictionary:
	if grid == null:
		return {"can_use": false, "reason": "grid_missing"}
	var cells := grid.get_vortex_network_cells(entry)
	if cells.size() < 3:
		return {"can_use": cells.size() == 2, "reason": "not_random_network"}
	var candidates := grid.valid_vortex_destinations(entry, unit)
	if candidates.is_empty():
		return {"can_use": false, "reason": "no_valid_destination", "candidates": []}
	var entry_distance := entry.distance_to(target)
	var utilities: Array[float] = []
	var catastrophic := false
	for destination in candidates:
		var danger := _cell_danger(grid, destination)
		var utility := entry_distance - destination.distance_to(target) - danger
		utilities.append(utility)
		catastrophic = catastrophic or danger >= 5.0
	var total := 0.0
	var worst := INF
	for utility in utilities:
		total += utility
		worst = minf(worst, utility)
	var average := total / float(utilities.size())
	return {
		"can_use": average > 0.0 and not catastrophic and worst > -5.0,
		"reason": "safe" if average > 0.0 and not catastrophic and worst > -5.0 \
			else "non_positive_or_catastrophic",
		"average_utility": average,
		"worst_utility": worst,
		"catastrophic_exit": catastrophic,
		"candidates": candidates,
	}


static func _cell_danger(grid: GridData, cell: Vector2i) -> float:
	var stored = grid.get_effect(cell)
	if not stored is Dictionary:
		return 0.0
	var payload := (stored as Dictionary).get("data", {}) as Dictionary
	var effect := payload.get("data") as TerrainEffectData
	return maxf(0.0, effect.ai_danger_weight) \
		if effect != null and effect.dangerous_for_ai else 0.0
