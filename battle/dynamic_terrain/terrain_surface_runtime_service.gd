class_name TerrainSurfaceRuntimeService
extends RefCounted

const LogDefinitions = preload("res://debug/log_definitions.gd")
const CAT: LogDefinitions.LogCategory = LogDefinitions.LogCategory.TERRAIN
const REACTION_DAMAGE := 20
const DURATION_UNSET := -999999
const SHOCK_STATUS_PATH := "res://data/status/core/choc.tres"

signal surface_applied(fact: Dictionary)
signal surface_replaced(fact: Dictionary)
signal surface_refreshed(fact: Dictionary)
signal surface_cleared(fact: Dictionary)
signal surface_reaction(fact: Dictionary)
signal duration_changed(fact: Dictionary)

## Signaux de compatibilité consommés par les previews historiques.
signal surface_changed(cell: Vector2i, previous_surface: int, surface: int)
signal steam_requested(cell: Vector2i)

var grid: GridData = null
var _states: Dictionary = {}
var _base_capture_complete := false
var _resolution_serial := 0
var _active_resolution_by_unit := {}
var _applied_resolution_keys := {}
var _last_entry_results := {}
var _vortex_relocation_guard := {}
var combat_seed := 0
var round_index := 1
var _void_impulse_round_by_unit := {}
var _electrified_trigger_by_unit := {}
var _electrical_region_resolver := ElectricalTerrainRegionResolver.new()


func _init(grid_data: GridData = null) -> void:
	if grid_data != null:
		configure(grid_data)


func configure(grid_data: GridData) -> void:
	assert(grid_data != null, "TerrainSurfaceRuntimeService requiert GridData.")
	if grid != null and grid.occupancy_changed.is_connected(_on_occupancy_changed):
		grid.occupancy_changed.disconnect(_on_occupancy_changed)
	grid = grid_data
	grid.occupancy_changed.connect(_on_occupancy_changed)
	_states.clear()
	_base_capture_complete = false
	_active_resolution_by_unit.clear()
	_applied_resolution_keys.clear()
	_last_entry_results.clear()
	_vortex_relocation_guard.clear()
	_void_impulse_round_by_unit.clear()
	_electrified_trigger_by_unit.clear()
	_electrical_region_resolver.reset()


func configure_resolution_context(seed_value: int, current_round: int) -> void:
	combat_seed = seed_value
	round_index = maxi(1, current_round)
	_electrical_region_resolver.begin_round(round_index)


func capture_base_state(room_data = null, grid_data: GridData = null) -> Dictionary:
	if grid_data != null and grid_data != grid:
		configure(grid_data)
	if grid == null:
		return {"ok": false, "error": "grid_missing", "captured": 0}
	if _has_active_surfaces():
		return {"ok": false, "error": "active_surfaces_present", "captured": 0}
	_states.clear()
	var skipped: Array[Dictionary] = []
	if room_data is ArenaDefinition:
		var arena := room_data as ArenaDefinition
		for definition in arena.cells:
			if definition == null:
				continue
			var cell := definition.coordinate
			var reason := _arena_definition_ineligible_reason(arena, definition)
			if not reason.is_empty():
				skipped.append({"cell": cell, "reason": reason})
				continue
			_capture_cell(
				cell,
				definition.terrain_id,
				arena.obstacle_at(cell) != null,
				ArenaCatalogService.terrain(definition.terrain_id)
			)
	else:
		for y in range(grid.rows):
			for x in range(grid.cols):
				var cell := Vector2i(x, y)
				if not grid.is_terrain_interactable(cell):
					skipped.append({"cell": cell, "reason": "non_interactable"})
					continue
				_capture_cell(cell, _terrain_id_for_cell_type(grid.get_type(cell)))
	_base_capture_complete = true
	return {
		"ok": true,
		"captured": _states.size(),
		"skipped": skipped,
		"cells": state_cells(),
	}


func place_effect(
		cell: Vector2i,
		effect: TerrainEffectData,
		caster = null,
		source_spell: Spell = null,
		duration_override: int = DURATION_UNSET
	) -> Dictionary:
	var result := {
		"changed": false,
		"reaction": "",
		"same": false,
		"terrain_event": {},
	}
	var eligibility := eligibility_report(cell, effect)
	if not bool(eligibility.eligible):
		result["reason"] = eligibility.reason
		return result
	var incoming_ids := TerrainSurfaceIdResolver.resolve(effect)
	var incoming_id := StringName(incoming_ids.surface_id)
	var state := get_state(cell)
	if state != null and state.is_dynamic():
		if state.surface_id == incoming_id:
			return _handle_same_surface(
				cell, state, effect, caster, source_spell,
				duration_override, result
			)
		var interaction := TerrainInteractionResolver.resolve_ids(
			state.surface_id, incoming_id
		)
		var reaction := StringName(interaction.reaction)
		if reaction not in [&"replace", &"apply"]:
			return _apply_reaction(
				cell, state, effect, incoming_id, reaction, caster,
				source_spell, result
			)
	var event := _apply_effect(
		cell, effect, caster, source_spell, duration_override,
		&"apply" if state == null or not state.is_dynamic() else &"replace"
	)
	result["changed"] = true
	result["terrain_event"] = event
	return result


func clear_effect(cell: Vector2i, reason: StringName = &"cleared") -> bool:
	var state := get_state(cell)
	if state == null:
		return false
	var previous_id := state.surface_id
	var previous_dynamic := state.dynamic_surface
	var previous_effect := state.active_effect
	grid.set_type(cell, state.base_cell_type)
	grid.clear_surface_properties(cell)
	state.clear_dynamic()
	_write_grid_effect(cell, state)
	if previous_id == &"none":
		return false
	var fact := _fact(
		cell, previous_id, &"none", &"none", reason,
		0, previous_effect, state
	)
	surface_cleared.emit(fact)
	surface_changed.emit(
		cell, previous_dynamic, CellSurfaceState.DynamicSurface.NONE
	)
	return true


func reset() -> void:
	for cell in active_surface_cells():
		clear_effect(cell, &"reset")


func eligibility_report(cell: Vector2i, effect: TerrainEffectData = null) -> Dictionary:
	if grid == null:
		return {"eligible": false, "reason": "grid_missing", "cell": cell}
	if not grid.is_valid(cell):
		return {"eligible": false, "reason": "out_of_bounds", "cell": cell}
	if effect == null:
		return {"eligible": false, "reason": "effect_missing", "cell": cell}
	if not _states.has(cell):
		if _base_capture_complete:
			return {
				"eligible": false,
				"reason": "absent_from_captured_topology",
				"cell": cell,
			}
		if not grid.is_terrain_interactable(cell):
			return {
				"eligible": false,
				"reason": "non_interactable",
				"cell": cell,
			}
		_capture_cell(cell, _terrain_id_for_cell_type(grid.get_type(cell)))
	var state := get_state(cell)
	if state.base_surface in [
			CellSurfaceState.BaseSurface.VOID,
			CellSurfaceState.BaseSurface.WALL,
			CellSurfaceState.BaseSurface.OBSTACLE,
		]:
		return {"eligible": false, "reason": "structural_cell", "cell": cell}
	return {"eligible": true, "reason": "", "cell": cell}


func can_receive_surface(cell: Vector2i, effect: TerrainEffectData = null) -> bool:
	return bool(eligibility_report(cell, effect).eligible)


func get_effect_data(cell: Vector2i) -> TerrainEffectData:
	var state := get_state(cell)
	if state == null:
		return null
	return state.active_effect if state.is_dynamic() else state.base_effect


func get_state(cell: Vector2i) -> CellSurfaceState:
	return _states.get(cell) as CellSurfaceState


func has_state(cell: Vector2i) -> bool:
	return _states.has(cell)


func state_count() -> int:
	return _states.size()


func state_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell in _states:
		cells.append(cell)
	cells.sort_custom(_cell_less)
	return cells


func active_surface_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell in _states:
		if (_states[cell] as CellSurfaceState).is_dynamic():
			cells.append(cell)
	cells.sort_custom(_cell_less)
	return cells


func get_surface(cell: Vector2i) -> int:
	var state := get_state(cell)
	return state.dynamic_surface \
		if state != null else CellSurfaceState.DynamicSurface.NONE


func get_surface_id(cell: Vector2i) -> StringName:
	var state := get_state(cell)
	return state.surface_id if state != null else &"none"


func get_visual_terrain_id(cell: Vector2i) -> StringName:
	var state := get_state(cell)
	return state.visual_terrain_id if state != null else &""


func get_remaining_duration(cell: Vector2i) -> int:
	var state := get_state(cell)
	return state.remaining_duration if state != null and state.is_dynamic() else 0


func get_base_state(cell: Vector2i) -> Dictionary:
	var state := get_state(cell)
	if state == null:
		return {}
	return {
		"cell_type": state.base_cell_type,
		"terrain_id": state.base_terrain_id,
		"walkable": state.base_walkable,
		"transparent": state.base_transparent,
		"projectile_passable": state.base_projectile_passable,
		"movement_cost": state.base_movement_cost,
		"effect": state.base_effect,
	}


func get_ai_danger_weight(cell: Vector2i) -> float:
	var effect := get_effect_data(cell)
	var state := get_state(cell)
	if effect != null and effect.dangerous_for_ai:
		return maxf(0.0, effect.ai_danger_weight)
	return state.base_ai_danger_weight if state != null else 0.0


func on_turn_start(unit: Unit) -> void:
	var state := get_state(unit.grid_pos)
	if state == null:
		return
	if state.is_dynamic():
		if state.active_effect != null \
				and state.active_effect.trigger == TerrainEffectData.Trigger.TURN_START:
			_apply_effect_to_unit(unit, state.active_effect, state.visual_terrain_id)
	elif state.base_apply_on_turn_start and state.base_effect != null:
		if state.base_refresh_status_while_standing:
			_apply_status_only_to_unit(unit, state.base_effect, state.base_terrain_id)
		elif state.base_effect.trigger == TerrainEffectData.Trigger.TURN_START:
			_apply_effect_to_unit(unit, state.base_effect, state.base_terrain_id)


func on_enter_cell(unit: Unit, cell: Vector2i) -> Dictionary:
	if unit != null and _last_entry_results.has(unit.get_instance_id()):
		var cached := _last_entry_results[unit.get_instance_id()] as Dictionary
		if cached.get("entry_cell", Vector2i(-1, -1)) == cell:
			return cached.duplicate(true)
	return resolve_unit_entry(unit, cell)


func begin_unit_resolution(unit: Unit, reason: StringName = &"movement") -> StringName:
	if unit == null:
		return &""
	_resolution_serial += 1
	var token := StringName("%s:%d:%d" % [reason, unit.get_instance_id(), _resolution_serial])
	_active_resolution_by_unit[unit.get_instance_id()] = token
	return token


func end_unit_resolution(unit: Unit) -> void:
	if unit == null:
		return
	var token := str(_active_resolution_by_unit.get(unit.get_instance_id(), &""))
	_active_resolution_by_unit.erase(unit.get_instance_id())
	if not token.is_empty():
		for key_value in _applied_resolution_keys.keys():
			if ":%s:" % token in str(key_value):
				_applied_resolution_keys.erase(key_value)


func consume_last_entry_result(unit: Unit) -> Dictionary:
	if unit == null:
		return {}
	var key := unit.get_instance_id()
	var result := (_last_entry_results.get(key, {}) as Dictionary).duplicate(true)
	_last_entry_results.erase(key)
	return result


func resolve_unit_entry(
		unit: Unit,
		cell: Vector2i,
		resolution_token: StringName = &"",
		allow_vortex := true
	) -> Dictionary:
	var result := {
		"applied": false,
		"teleported": false,
		"end_movement": false,
		"entry_cell": cell,
		"destination": cell,
		"reason": &"",
	}
	if unit == null or not unit.is_alive or grid == null or not grid.is_valid(cell):
		result.reason = &"invalid_entry"
		return result
	var token := resolution_token
	if token == &"":
		token = _active_resolution_by_unit.get(unit.get_instance_id(), &"") as StringName
	if token == &"":
		_resolution_serial += 1
		token = StringName("occupancy:%d:%d" % [
			unit.get_instance_id(), _resolution_serial,
		])
	if _applied_resolution_keys.size() > 2048:
		_applied_resolution_keys.clear()
	var dedupe_key := "%d:%s:%d,%d" % [unit.get_instance_id(), token, cell.x, cell.y]
	if _applied_resolution_keys.has(dedupe_key):
		result.reason = &"already_resolved"
		return result
	_applied_resolution_keys[dedupe_key] = true
	var state := get_state(cell)
	var applied_effect: TerrainEffectData = null
	var applied_terrain_id: StringName = &""
	if state != null:
		if state.is_dynamic() and state.active_effect != null \
				and state.active_effect.trigger in [
					TerrainEffectData.Trigger.ON_ENTER,
					TerrainEffectData.Trigger.PASSIVE,
				]:
			applied_effect = state.active_effect
			applied_terrain_id = state.visual_terrain_id
			_apply_effect_to_unit(unit, applied_effect, applied_terrain_id)
			result.applied = true
		elif not state.is_dynamic() and state.base_apply_on_enter \
				and state.base_effect != null:
			applied_effect = state.base_effect
			applied_terrain_id = state.base_terrain_id
			_apply_effect_to_unit(unit, applied_effect, applied_terrain_id)
			result.applied = true
	if applied_effect != null and (
		applied_effect.surface_id == &"electrified_water" \
		or applied_terrain_id == &"electrified_water"
	):
		var shock_result := _resolve_electrified_shock(unit, token, cell)
		for key in shock_result:
			result[key] = shock_result[key]
	if not unit.is_alive:
		result.end_movement = true
		result.reason = &"unit_defeated"
		return result
	if allow_vortex and grid.has_vortex(cell):
		var network := grid.get_vortex_network(cell)
		var network_cells := grid.get_vortex_network_cells(cell)
		if not network.is_empty() and not grid.can_unit_use_vortex_network(cell, unit):
			result.reason = &"vortex_team_not_allowed"
			return result
		if network_cells.size() == 1:
			var impulse_key := unit.get_instance_id()
			if int(_void_impulse_round_by_unit.get(impulse_key, -1)) != round_index:
				_void_impulse_round_by_unit[impulse_key] = round_index
				unit.grant_current_activation_mp_bonus(1)
				result.reason = &"void_impulse"
				result["movement_points_bonus"] = 1
			return result
		var candidates: Array[Vector2i] = []
		if network.is_empty():
			var legacy_destination := grid.get_vortex_destination(cell)
			if legacy_destination != Vector2i(-1, -1) \
					and grid.is_walkable(legacy_destination, unit):
				candidates.append(legacy_destination)
		else:
			candidates = grid.valid_vortex_destinations(cell, unit)
		if candidates.is_empty():
			result.reason = &"vortex_destination_blocked"
			return result
		var destination := candidates[0]
		if candidates.size() > 1:
			var rng := RandomNumberGenerator.new()
			var network_id := StringName(network.get("network_id", ""))
			var unit_id := str(unit.unit_id) if unit.unit_id != &"" \
				else str(unit.get_instance_id())
			var token_parts := str(token).split(":")
			var stable_resolution_id := "%s:%s" % [
				token_parts[0], token_parts[-1],
			]
			rng.seed = absi(("%d|%d|%s|%s|%s|%d,%d" % [
				combat_seed, round_index, stable_resolution_id, unit_id,
				network_id, cell.x, cell.y,
			]).hash())
			destination = candidates[rng.randi_range(0, candidates.size() - 1)]
		_vortex_relocation_guard[unit.get_instance_id()] = true
		var relocated := grid.relocate_unit(unit, destination)
		_vortex_relocation_guard.erase(unit.get_instance_id())
		if relocated:
			result.teleported = true
			result.end_movement = true
			result.destination = destination
			result.reason = &"vortex_traversed"
			var destination_result := resolve_unit_entry(
				unit, destination, token, false
			)
			result["destination_effect_applied"] = bool(
				destination_result.get("applied", false)
			)
	return result


func tick_all_effects() -> void:
	var expired: Array[Vector2i] = []
	var active := 0
	for cell in active_surface_cells():
		var state := get_state(cell)
		if state.remaining_duration == -1:
			active += 1
			continue
		state.set_remaining_duration(state.remaining_duration - 1)
		if state.remaining_duration <= 0:
			expired.append(cell)
			continue
		_write_grid_effect(cell, state)
		duration_changed.emit(_fact(
			cell, state.surface_id, state.surface_id, state.surface_id,
			&"duration_changed", state.remaining_duration,
			state.active_effect, state
		))
		active += 1
	for cell in expired:
		clear_effect(cell, &"expired")
	if not expired.is_empty() or active > 0:
		DebugLogger.debug(CAT, "Vieillissement des effets", {
			"actifs": active,
			"expires": expired.size(),
		})


func _handle_same_surface(
		cell: Vector2i,
		state: CellSurfaceState,
		effect: TerrainEffectData,
		caster,
		source_spell: Spell,
		duration_override: int,
		result: Dictionary
	) -> Dictionary:
	result["same"] = true
	match effect.same_surface_policy:
		TerrainEffectData.SameSurfacePolicy.REFRESH_DURATION:
			var duration := effect.duration \
				if duration_override == DURATION_UNSET else duration_override
			state.set_remaining_duration(duration)
			state.source_unit = caster
			state.source_spell = source_spell
			state.active_effect = effect
			_write_grid_effect(cell, state)
			var fact := _fact(
				cell, state.surface_id, state.surface_id, state.surface_id,
				&"refresh", duration, effect, state
			)
			surface_refreshed.emit(fact)
			duration_changed.emit(fact)
			result["changed"] = true
			result["terrain_event"] = fact
		TerrainEffectData.SameSurfacePolicy.REPLACE:
			var fact := _apply_effect(
				cell, effect, caster, source_spell, duration_override, &"replace"
			)
			result["changed"] = true
			result["terrain_event"] = fact
		_:
			DebugLogger.trace(CAT, "%s deja present en %s : pose ignoree" % [
				effect.effect_name, str(cell)
			])
	return result


func _apply_reaction(
		cell: Vector2i,
		state: CellSurfaceState,
		incoming_effect: TerrainEffectData,
		incoming_id: StringName,
		reaction: StringName,
		caster,
		source_spell: Spell,
		result: Dictionary
	) -> Dictionary:
	var previous_id := state.surface_id
	var event: Dictionary
	if reaction == &"shock":
		_damage_area(cell, REACTION_DAMAGE, caster)
		clear_effect(cell, &"reaction_shock")
		event = _fact(
			cell, previous_id, incoming_id, &"none", reaction, 0,
			incoming_effect, state
		)
	else:
		var resolved := TerrainInteractionResolver.resolve_ids(
			previous_id, incoming_id
		)
		var result_id := StringName(resolved.result_surface_id)
		var result_effect := TerrainSurfaceIdResolver.load_default_effect(result_id)
		if result_effect == null:
			clear_effect(cell, StringName("reaction_%s" % reaction))
			event = _fact(
				cell, previous_id, incoming_id, &"none", reaction, 0,
				incoming_effect, state
			)
		else:
			event = _apply_effect(
				cell, result_effect, caster, source_spell,
				DURATION_UNSET, &"reaction"
			)
			event["previous_surface"] = previous_id
			event["incoming_surface"] = incoming_id
			event["reaction"] = reaction
	if reaction == &"steam":
		steam_requested.emit(cell)
	surface_reaction.emit(event)
	result["changed"] = true
	result["reaction"] = str(reaction)
	result["terrain_event"] = event
	return result


func _apply_effect(
		cell: Vector2i,
		effect: TerrainEffectData,
		caster,
		source_spell: Spell,
		duration_override: int,
		action: StringName
	) -> Dictionary:
	var state := get_state(cell)
	var previous_id := state.surface_id
	var previous_dynamic := state.dynamic_surface
	var ids := TerrainSurfaceIdResolver.resolve(effect)
	var surface_id := StringName(ids.surface_id)
	var visual_id := StringName(ids.visual_terrain_id)
	var duration := effect.duration \
		if duration_override == DURATION_UNSET else duration_override
	state.configure(
		TerrainSurfaceIdResolver.dynamic_surface(surface_id),
		duration,
		caster,
		{
			"dangerous_for_ai": effect.dangerous_for_ai,
			"ai_danger_weight": effect.ai_danger_weight,
			"trigger": effect.trigger,
			"damage": effect.damage,
		},
		effect,
		surface_id,
		visual_id,
		source_spell
	)
	_write_grid_effect(cell, state)
	var surface_properties := {}
	if effect.blocks_movement:
		surface_properties["walkable"] = false
	if effect.blocks_vision:
		surface_properties["transparent"] = false
	grid.set_surface_properties(cell, surface_properties)
	if effect.cell_type >= 0:
		grid.set_type(cell, effect.cell_type)
	else:
		grid.set_type(cell, state.base_cell_type)
	var fact := _fact(
		cell, previous_id, surface_id, surface_id, action,
		duration, effect, state
	)
	if previous_id == &"none":
		surface_applied.emit(fact)
	elif action == &"refresh":
		surface_refreshed.emit(fact)
	else:
		surface_replaced.emit(fact)
	surface_changed.emit(
		cell, previous_dynamic, state.dynamic_surface
	)
	var occupant := grid.get_unit(cell) as Unit
	if occupant != null and occupant.is_alive \
			and effect.trigger in [
				TerrainEffectData.Trigger.ON_ENTER,
				TerrainEffectData.Trigger.PASSIVE,
			]:
		_apply_effect_to_unit(occupant, effect, visual_id)
	return fact


func _write_grid_effect(cell: Vector2i, state: CellSurfaceState) -> void:
	var effect := state.active_effect if state.is_dynamic() else state.base_effect
	if effect == null:
		grid.clear_effect(cell)
		return
	grid.set_effect(cell, effect.effect_name, {
		"data": effect,
		"duration": state.remaining_duration if state.is_dynamic() else -1,
		"surface_id": state.surface_id if state.is_dynamic() else state.base_terrain_id,
		"visual_terrain_id": state.visual_terrain_id if state.is_dynamic() else state.base_terrain_id,
		"layer": &"temporary" if state.is_dynamic() else &"permanent",
		"source_unit": state.source_unit,
		"source_spell": state.source_spell,
	})


func _capture_cell(
		cell: Vector2i,
		terrain_id: StringName,
		has_obstacle := false,
		definition: ArenaTerrainDefinition = null
	) -> void:
	if grid == null or not grid.is_valid(cell):
		return
	var state := CellSurfaceState.new()
	state.configure_base_terrain(
		terrain_id, grid.get_type(cell), has_obstacle
	)
	state.configure_permanent_behavior(definition, grid.get_terrain_properties(cell))
	_states[cell] = state
	_write_grid_effect(cell, state)


func _arena_definition_ineligible_reason(
		arena: ArenaDefinition,
		definition: ArenaCellDefinition
	) -> String:
	if not grid.is_valid(definition.coordinate):
		return "out_of_bounds"
	if not definition.defined or not definition.playable:
		return "removed_or_non_playable"
	if definition.terrain_id in [&"void", &"hole", &"wall"]:
		return "structural_terrain"
	if grid.get_type(definition.coordinate) in [
			GridData.CellType.HOLE, GridData.CellType.WALL
		]:
		return "structural_cell_type"
	if arena.obstacle_at(definition.coordinate) != null:
		return "structural_obstacle"
	return ""


func _terrain_id_for_cell_type(cell_type: int) -> StringName:
	match cell_type:
		GridData.CellType.ICE:
			return &"ice"
		GridData.CellType.LAVA:
			return &"lava"
		GridData.CellType.HOLE:
			return &"hole"
		GridData.CellType.WALL:
			return &"wall"
		GridData.CellType.SHADOW:
			return &"shadow"
		GridData.CellType.RUNE:
			return &"rune"
	return &"normal"


func _apply_effect_to_unit(
		unit: Unit,
		effect: TerrainEffectData,
		terrain_id: StringName = &""
	) -> void:
	if effect.damage > 0:
		unit.take_damage(
			effect.damage, null, effect.damage_type,
			effect.element, {
				"ignore_defense": effect.ignores_defense,
				"cannot_be_dodged": not effect.can_be_dodged,
				"terrain_effect_id": effect.surface_id,
			}
		)
		if not unit.is_alive:
			EventBus.hazard_kill.emit(unit, effect.effect_name)
	if effect.applied_status != null:
		unit.apply_status(effect.applied_status, null, {
			"terrain_id": terrain_id if terrain_id != &"" else effect.visual_terrain_id,
			"terrain_effect_id": effect.surface_id,
		})
		DebugLogger.info(CAT, "[TERRAIN] %s appliqué par %s" % [
			effect.applied_status.status_name,
			terrain_id if terrain_id != &"" else effect.visual_terrain_id,
		])


func _apply_status_only_to_unit(
		unit: Unit,
		effect: TerrainEffectData,
		terrain_id: StringName
	) -> void:
	if effect == null or effect.applied_status == null:
		return
	unit.apply_status(effect.applied_status, null, {
		"terrain_id": terrain_id,
		"terrain_effect_id": effect.surface_id,
		"refresh_while_standing": true,
	})
	DebugLogger.info(CAT, "[TERRAIN] %s rafraîchi par %s" % [
		effect.applied_status.status_name, terrain_id,
	])


func _resolve_electrified_shock(
		unit: Unit,
		token: StringName,
		cell: Vector2i
	) -> Dictionary:
	_electrical_region_resolver.begin_round(round_index)
	var region := _electrical_region_resolver.resolve_region(
		cell, _electrified_cells()
	)
	var region_id := StringName(region.get("region_id", &""))
	var lineage_tokens := region.get(
		"lineage_tokens", PackedStringArray()
	) as PackedStringArray
	var result := {
		"shock_applied": false,
		"shock_region_id": region_id,
		"shock_region_lineage": lineage_tokens,
		"shock_round": round_index,
	}
	if not bool(region.get("ok", false)) or lineage_tokens.is_empty():
		result["reason"] = &"electrical_region_unresolved"
		result["shock_locked"] = true
		return result
	var unit_key := str(unit.unit_id) if unit.unit_id != &"" \
		else "instance:%d" % unit.get_instance_id()
	var previous := _electrified_trigger_by_unit.get(unit_key, {}) as Dictionary
	var consumed := previous.get("regions", {}) as Dictionary
	if int(previous.get("round", -1)) == round_index:
		for lineage_token in lineage_tokens:
			if consumed.has(lineage_token):
				result["shock_locked"] = true
				return result
	else:
		consumed = {}
	for lineage_token in lineage_tokens:
		consumed[lineage_token] = true
	_electrified_trigger_by_unit[unit_key] = {
		"round": round_index,
		"regions": consumed,
	}
	result["shock_applied"] = true
	var voluntary := str(token).begins_with("movement:")
	if voluntary:
		unit.consume_current_activation()
		result["end_movement"] = true
		result["reason"] = &"electrified_shock_current_activation"
		result["current_activation_consumed"] = true
	else:
		var shock := load(SHOCK_STATUS_PATH) as StatusData
		if shock != null:
			unit.apply_status(shock, null, {
				"terrain_id": &"electrified_water",
				"terrain_effect_id": region_id,
				"forced_entry": true,
			})
		result["reason"] = &"electrified_shock_next_activation"
		result["next_activation_skipped"] = true
	DebugLogger.info(CAT, "[TERRAIN] Choc appliqué — round %d, région %s" % [
		round_index, region_id,
	])
	return result


func _electrified_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell in state_cells():
		var state := get_state(cell)
		if state == null:
			continue
		if state.is_dynamic():
			if state.surface_id == &"electrified_water" \
					or state.visual_terrain_id == &"electrified_water":
				cells.append(cell)
		elif state.base_terrain_id == &"electrified_water":
			cells.append(cell)
	return cells


func _on_occupancy_changed(
		reason: StringName,
		unit,
		_from_pos: Vector2i,
		to_pos: Vector2i
	) -> void:
	if not unit is Unit or to_pos == Vector2i(-1, -1) \
			or _vortex_relocation_guard.has(unit.get_instance_id()):
		return
	var token := _active_resolution_by_unit.get(unit.get_instance_id(), &"") as StringName
	var result := resolve_unit_entry(unit, to_pos, token)
	result["occupancy_reason"] = reason
	_last_entry_results[unit.get_instance_id()] = result


func _damage_area(center: Vector2i, amount: int, caster = null) -> void:
	var cells := [center, center + Vector2i.UP, center + Vector2i.DOWN,
		center + Vector2i.LEFT, center + Vector2i.RIGHT]
	for cell in cells:
		if not grid.is_valid(cell):
			continue
		var unit = grid.get_unit(cell)
		if unit != null and unit.is_alive:
			unit.take_damage(
				amount, caster, Spell.DamageType.MAGICAL,
				Spell.Element.LIGHTNING
			)
			if not unit.is_alive:
				EventBus.hazard_kill.emit(unit, "reaction")


func _fact(
		cell: Vector2i,
		previous_surface: StringName,
		incoming_surface: StringName,
		result_surface: StringName,
		reaction: StringName,
		duration: int,
		effect: TerrainEffectData,
		state: CellSurfaceState
	) -> Dictionary:
	return {
		"cell": cell,
		"previous_surface": previous_surface,
		"incoming_surface": incoming_surface,
		"result_surface": result_surface,
		"reaction": reaction,
		"duration": duration,
		"remaining_duration": state.remaining_duration,
		"surface_id": state.surface_id,
		"visual_terrain_id": state.visual_terrain_id,
		"source_spell_id": (
			state.source_spell.get_effective_spell_id()
			if state.source_spell != null else &""
		),
		"source_unit_id": (
			StringName(state.source_unit.unit_id)
			if state.source_unit != null and "unit_id" in state.source_unit else &""
		),
		"effect_name": effect.effect_name if effect != null else "",
		"gameplay_changed": true,
		"visual_changed": state.visual_terrain_id != &"",
	}


func _has_active_surfaces() -> bool:
	return not active_surface_cells().is_empty()


func _cell_less(a: Vector2i, b: Vector2i) -> bool:
	return a.y < b.y or (a.y == b.y and a.x < b.x)
