extends RefCounted

## Read-only terrain estimates. Resolution and resource spending remain in the
## existing movement/terrain/spell services; in particular this never rolls a TP.
static func cell_risk(ai, cell: Vector2i) -> float:
	var grid: GridData = ai.get_grid()
	var terrain: TerrainEffects = ai.get_spell_caster()._terrain
	var risk := maxf(0.0, float(grid.get_terrain_properties(cell).get("ai_danger_weight", 0.0)))
	if terrain == null:
		return risk
	risk = maxf(risk, terrain.get_ai_danger_weight(cell))
	var effect := terrain.get_effect_data(cell)
	if effect == null:
		return risk
	var consequence := float(effect.damage) / 5.0
	if effect.applied_status != null:
		var status := effect.applied_status
		consequence += status.mp_reduction + status.ap_reduction * 2.0 + float(status.damage_per_turn) / 5.0
		if status.skips_turn:
			consequence += 6.0
	if is_electrified(ai, cell):
		consequence += 8.0
	return maxf(risk, consequence)


static func is_electrified(ai, cell: Vector2i) -> bool:
	var terrain: TerrainEffects = ai.get_spell_caster()._terrain
	if terrain == null:
		return false
	var effect := terrain.get_effect_data(cell)
	return effect != null and (effect.surface_id == &"electrified_water" \
		or effect.visual_terrain_id == &"electrified_water")


static func path_info(ai, unit: Unit, path: Array) -> Dictionary:
	var grid: GridData = ai.get_grid()
	if path.size() < 2:
		return {}
	var cost: int = ai.get_pathfinder().path_movement_cost(path, unit)
	if cost > unit.current_mp:
		return {}
	var risk := 0.0
	var damage := 0
	var destination: Vector2i = path.back()
	var random_exits: Array[Vector2i] = []
	for index in range(1, path.size()):
		var cell: Vector2i = path[index]
		# Voluntary entry consumes the activation. Never queue spells after it,
		# even when the entry cost alone would leave enough AP and MP.
		if is_electrified(ai, cell):
			return {}
		risk += cell_risk(ai, cell)
		var effect := _entry_effect(ai, cell)
		if effect != null:
			damage += effect.damage
		# Paired links already include their actual exit in Pathfinder's path.
		# A network path ends at its entry, not at one arbitrarily chosen exit.
		if index == path.size() - 1 and grid.get_vortex_destination(cell) == Vector2i(-1, -1) \
				and grid.get_vortex_network_cells(cell).size() >= 2:
			if not grid.can_unit_use_vortex_network(cell, unit):
				return {}
			var exits: Array[Vector2i] = grid.valid_vortex_destinations(cell, unit)
			if exits.is_empty():
				return {}
			if exits.size() == 1:
				destination = exits[0]
				if is_electrified(ai, destination):
					return {}
				risk += cell_risk(ai, destination)
				var exit_effect := _entry_effect(ai, destination)
				if exit_effect != null:
					damage += exit_effect.damage
			else:
				# Every possible exit must be safe. No random state is inspected.
				for exit in exits:
					if cell_risk(ai, exit) > 0.0:
						return {}
				random_exits = exits
	if damage >= unit.current_hp + unit.current_shield:
		return {}
	return {"cost": cost, "risk": risk, "cell": destination, "random_exits": random_exits}


static func push_bonus(ai, target: Unit, origin: Vector2i, distance: int) -> float:
	if target.mastery_combat_adapter != null and target.mastery_combat_adapter.blocks_control(target, &"push"):
		return 0.0
	# Read resistance without consuming the once-per-activation reduction.
	if not target._forced_movement_reduction_used:
		distance = maxi(0, distance - target.first_forced_movement_reduction_per_activation)
	if distance <= 0:
		return 0.0
	var grid: GridData = ai.get_grid()
	var raw := target.grid_pos - origin
	var direction := Vector2i(signi(raw.x), 0) if absi(raw.x) >= absi(raw.y) else Vector2i(0, signi(raw.y))
	var landing := target.grid_pos
	for _step in range(distance):
		var next := landing + direction
		if not grid.is_walkable(next, target):
			break
		landing = next
	if landing == target.grid_pos:
		return 0.0
	# Terrain does apply on the entered cell before a vortex relocates it.
	# Do not speculate about an additional outcome at a random exit.
	var effect := _entry_effect(ai, landing)
	if effect == null:
		return 0.0
	var benefit := float(effect.damage)
	if effect.applied_status != null:
		var status := effect.applied_status
		if not target.has_status(status.get_effective_status_id()):
			benefit += 8.0 * status.mp_reduction + 12.0 * status.ap_reduction + status.damage_per_turn
			if status.skips_turn:
				benefit += 24.0
	if is_electrified(ai, landing) and not target.has_status(&"shock"):
		benefit += 24.0
	return minf(40.0, benefit)


static func _entry_effect(ai, cell: Vector2i) -> TerrainEffectData:
	var terrain: TerrainEffects = ai.get_spell_caster()._terrain
	if terrain == null:
		return null
	var state := terrain.get_surface_state(cell)
	if state == null:
		return null
	if state.is_dynamic():
		var effect := state.active_effect
		if effect != null and effect.trigger in [TerrainEffectData.Trigger.ON_ENTER, TerrainEffectData.Trigger.PASSIVE]:
			return effect
	elif state.base_apply_on_enter:
		return state.base_effect
	return null
