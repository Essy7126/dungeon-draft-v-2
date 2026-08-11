class_name TerrainSurfaceRuntimeService
extends RefCounted

const LogDefinitions = preload("res://debug/log_definitions.gd")
const CAT: LogDefinitions.LogCategory = LogDefinitions.LogCategory.TERRAIN
const REACTION_DAMAGE := 20
const DURATION_UNSET := -999999

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


func _init(grid_data: GridData = null) -> void:
	if grid_data != null:
		configure(grid_data)


func configure(grid_data: GridData) -> void:
	assert(grid_data != null, "TerrainSurfaceRuntimeService requiert GridData.")
	grid = grid_data
	_states.clear()
	_base_capture_complete = false


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
				arena.obstacle_at(cell) != null
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
	grid.clear_effect(cell)
	grid.set_type(cell, state.base_cell_type)
	state.clear_dynamic()
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
	return state.active_effect if state != null else null


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
	}


func get_ai_danger_weight(cell: Vector2i) -> float:
	var effect := get_effect_data(cell)
	if effect == null or not effect.dangerous_for_ai:
		return 0.0
	return maxf(0.0, effect.ai_danger_weight)


func on_turn_start(unit: Unit) -> void:
	var effect := get_effect_data(unit.grid_pos)
	if effect != null and effect.trigger == TerrainEffectData.Trigger.TURN_START:
		_apply_effect_to_unit(unit, effect)


func on_enter_cell(unit: Unit, cell: Vector2i) -> void:
	var effect := get_effect_data(cell)
	if effect != null and effect.trigger == TerrainEffectData.Trigger.ON_ENTER:
		_apply_effect_to_unit(unit, effect)


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
	return fact


func _write_grid_effect(cell: Vector2i, state: CellSurfaceState) -> void:
	if state.active_effect == null:
		grid.clear_effect(cell)
		return
	grid.set_effect(cell, state.active_effect.effect_name, {
		"data": state.active_effect,
		"duration": state.remaining_duration,
		"surface_id": state.surface_id,
		"visual_terrain_id": state.visual_terrain_id,
		"source_unit": state.source_unit,
		"source_spell": state.source_spell,
	})


func _capture_cell(
		cell: Vector2i,
		terrain_id: StringName,
		has_obstacle := false
	) -> void:
	if grid == null or not grid.is_valid(cell):
		return
	var state := CellSurfaceState.new()
	state.configure_base_terrain(
		terrain_id, grid.get_type(cell), has_obstacle
	)
	_states[cell] = state


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


func _apply_effect_to_unit(unit: Unit, effect: TerrainEffectData) -> void:
	if effect.damage > 0:
		unit.take_damage(
			effect.damage, null, Spell.DamageType.MAGICAL,
			Spell.Element.FIRE, {"ignore_defense": false}
		)
		if not unit.is_alive:
			EventBus.hazard_kill.emit(unit, effect.effect_name)
	if effect.applied_status != null:
		unit.apply_status(effect.applied_status)


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
