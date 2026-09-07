extends "res://tools/philosopher_sprite_validation/combat_probe.gd"

var _terrain_bound := false
var _occupancy: Array[Dictionary] = []
var _tile_visuals: Array[Dictionary] = []
var _turn_endings: Array[Dictionary] = []
var _terrain_initial: Dictionary = {}


func _process(delta: float) -> void:
	if _running and not _terrain_bound:
		_terrain_bound = true
		_battle.grid.occupancy_changed.connect(_on_terrain_occupancy)
		EventBus.turn_ended.connect(_on_terrain_turn_ended)
		_terrain_initial = {"hero": _snapshot(_hero), "mage": _snapshot(_mage), "mage_presentation_scale": _observed_unit_view.get_painted_visual_scale(), "mage_visual_scale": _observed_visual.scale}
		_capture_tile_contracts()
	super._process(delta)


func _capture_tile_contracts() -> void:
	var renderer := (_battle.get("arena_assembly") as Dictionary).get("renderer") as ArenaTerrainVisualRenderer
	for tile: Dictionary in placement.get("permanent_tiles", []):
		var cell := Vector2i(tile.cell)
		var floor_root := renderer.node_for_cell(cell)
		var visual := floor_root.get_node_or_null("Visual") as Sprite2D if floor_root != null else null
		var texture_path := visual.texture.resource_path if visual != null and visual.texture != null else ""
		var shader_path := ""
		if visual != null and visual.material is ShaderMaterial:
			var shader := (visual.material as ShaderMaterial).shader
			shader_path = shader.resource_path if shader != null else ""
		var terrain := _battle.get("terrain_effects") as TerrainEffects
		var state: CellSurfaceState = terrain.get_surface_state(cell)
		var effective_id: String = str(state.visual_terrain_id if state != null and state.is_dynamic() else state.base_terrain_id if state != null else &"")
		_tile_visuals.append({"cell": cell, "expected_id": tile.terrain_id,
			"actual_visual_id": effective_id, "active_surface_id": str(terrain.get_visual_terrain_id(cell)), "base_state": terrain.get_base_state(cell), "expected_texture": tile.texture_path,
			"actual_texture": texture_path, "visible": visual != null and visual.is_visible_in_tree(),
			"shader_path": shader_path})
	for cell: Vector2i in placement.get("portal_cells", []):
		_tile_visuals.append({"cell": cell, "kind": "vortex_network", "has_real_grid_portal": _battle.grid.has_vortex(cell),
			"network": _battle.grid.get_vortex_network(cell), "network_cells": _battle.grid.get_vortex_network_cells(cell)})


func _on_terrain_occupancy(reason: StringName, unit, from_cell: Vector2i, to_cell: Vector2i) -> void:
	if unit != _mage and unit != _hero:
		return
	# Nested portal relocation may notify exit before the outer entry event.
	# Preserve both events and their actual state instead of consuming runtime results.
	_occupancy.append({"time_usec": Time.get_ticks_usec(), "unit_id": str(unit.unit_id),
		"reason": str(reason), "from": from_cell, "to": to_cell, "actual_cell": unit.grid_pos,
		"hp": unit.current_hp, "mp": unit.current_mp, "ap": unit.current_ap})


func _on_terrain_turn_ended(unit: Unit, reason: StringName) -> void:
	if unit == _hero or unit == _mage:
		_turn_endings.append({"time_usec": Time.get_ticks_usec(), "unit_id": str(unit.unit_id),
			"reason": str(reason), "cell": unit.grid_pos, "hp": unit.current_hp, "mp": unit.current_mp, "ap": unit.current_ap})


func _on_damage(target: Unit, attacker: Unit, amount: int, category: int, element: int, critical: bool) -> void:
	if target == _hero or target == _mage:
		_fact("hp_damage", attacker, target, amount, {"environmental_source": attacker == null,
			"damage_category": category, "damage_element": element, "critical": critical})


func _on_status(target: Unit, status: StatusData) -> void:
	if target != _hero and target != _mage:
		return
	var environmental := status.status_id in [&"burn", &"wet", &"frozen", &"shock"]
	_fact("status", null if environmental else _mage, target, 0,
		{"status_id": str(status.status_id), "environmental_source": environmental})


func _on_spell_cast(actor: Unit, spell: Spell, report: Dictionary) -> void:
	super._on_spell_cast(actor, spell, report)
	if actor == _mage and not _active_cast.is_empty():
		_active_cast.actual_caster_cell = actor.grid_pos
		_active_cast.actual_hero_cell = _hero.grid_pos
		_active_cast.actual_distance_to_hero = _battle.grid.manhattan(actor.grid_pos, _hero.grid_pos)
		_active_cast.canonical_minimum_range = spell.minimum_range
		_active_cast.canonical_maximum_range = spell.spell_range
		_active_cast.actual_line_of_sight_to_hero = _battle.pathfinder.has_line_of_sight(actor.grid_pos, _hero.grid_pos)


func _on_move_resolved(unit: Unit, path: Array, cost: int, action_id: StringName) -> void:
	super._on_move_resolved(unit, path, cost, action_id)
	if unit == _mage:
		for move: Dictionary in _moves:
			if str(move.action_id) == str(action_id):
				move.resolved_path = path.duplicate()
				move.actual_destination = unit.grid_pos


func _scenario_observed() -> bool:
	var scenario := str(configuration.scenario)
	if scenario.begins_with("push_"):
		if not _has_spell("philosopher_refutation") or not _pushed_onto_fixture():
			return false
		match scenario:
			"push_lava":
				return _has_environment_status("burn", _hero) and _environment_damage(_hero) > 0
			"push_water":
				return _has_environment_status("wet", _hero) and _hero_mp_reduced_by_one()
			"push_ice":
				return _has_environment_status("frozen", _hero) and _hero_mp_reduced_by_one()
			"push_electric":
				return _has_environment_status("wet", _hero) and _has_environment_status("shock", _hero) and _environment_damage(_hero) > 0 and _hero_stunned_activation()
	elif scenario in ["portal_pair", "portal_network"]:
		return not _real_portal_jump().is_empty() and _cast_from_real_exit()
	elif scenario in ["avoid_fire", "escape_fire"]:
		return not _moves.is_empty() and not _casts.is_empty() and _mage.grid_pos != Vector2i(placement.hazard_cell)
	return false


func _has_spell(spell_id: String) -> bool:
	for cast: Dictionary in _casts:
		if str(cast.get("spell_id", "")) == spell_id:
			return true
	return false


func _pushed_onto_fixture() -> bool:
	for fact: Dictionary in _facts:
		if str(fact.kind) == "push" and Vector2i(fact.to) == Vector2i(placement.hazard_cell):
			return true
	return false


func _has_environment_status(status_id: String, unit: Unit) -> bool:
	for fact: Dictionary in _facts:
		if str(fact.kind) == "status" and str(fact.get("status_id", "")) == status_id and int(fact.target_instance) == unit.get_instance_id() and bool(fact.get("environmental_source", false)):
			return true
	return false


func _environment_damage(unit: Unit) -> int:
	var total := 0
	for fact: Dictionary in _facts:
		if str(fact.kind) == "hp_damage" and int(fact.target_instance) == unit.get_instance_id() and bool(fact.get("environmental_source", false)):
			total += int(fact.amount)
	return total


func _hero_mp_reduced_by_one() -> bool:
	for fact: Dictionary in _facts:
		if str(fact.kind) == "hero_activation" and int(fact.mp) == int(fact.mp_before_statuses) - 1 and int(fact.player_actions_since_start) == 0:
			return true
	return false


func _hero_stunned_activation() -> bool:
	for turn: Dictionary in _turn_endings:
		if str(turn.unit_id) == str(_hero.unit_id) and str(turn.reason) == "stunned":
			return true
	return false


func _real_portal_jump() -> Dictionary:
	for event: Dictionary in _occupancy:
		if str(event.unit_id) == str(_mage.unit_id) and Vector2i(event.from) == Vector2i(placement.portal_entry) and (placement.portal_exits as Array).has(Vector2i(event.to)) and Vector2i(event.actual_cell) == Vector2i(event.to):
			return event
	return {}


func _cast_from_real_exit() -> bool:
	var jump := _real_portal_jump()
	if jump.is_empty():
		return false
	for cast: Dictionary in _casts:
		if str(cast.get("spell_id", "")) not in ["philosopher_axiom", "philosopher_aporia"] or not cast.has("actual_caster_cell"):
			continue
		var distance := int(cast.actual_distance_to_hero)
		if Vector2i(cast.actual_caster_cell) == Vector2i(jump.to) and int(cast.started_usec) > int(jump.time_usec) and distance >= int(cast.canonical_minimum_range) and distance <= int(cast.canonical_maximum_range) and bool(cast.actual_line_of_sight_to_hero) and int(cast.get("spell_count", 0)) == 1:
			return true
	return false


func _validate() -> void:
	super._validate()
	if not _terrain_bound:
		_errors.append("terrain_observer_was_not_connected")
	for tile: Dictionary in _tile_visuals:
		if tile.get("kind", "") == "vortex_network":
			if not bool(tile.has_real_grid_portal) or (tile.network_cells as Array).size() < 2:
				_errors.append("real_portal_network_missing")
		elif not bool(tile.visible) or str(tile.actual_texture) != str(tile.expected_texture) or str(tile.actual_visual_id) != str(tile.expected_id):
			_errors.append("canonical_special_floor_texture_or_state_missing")
	if float(_terrain_initial.get("mage_presentation_scale", 0.0)) < 1.4:
		_errors.append("mage_multimap_readability_profile_missing")
	for tile: Dictionary in _tile_visuals:
		if str(tile.get("shader_path", "")) == "res://battle/painted/registered_terrain/shaders/stone_palette.gdshader":
			_errors.append("special_terrain_was_recolored_as_stone")
	var scenario := str(configuration.scenario)
	if scenario in ["avoid_fire", "escape_fire"]:
		var entered_fire := false
		for event: Dictionary in _occupancy:
			entered_fire = entered_fire or (str(event.unit_id) == str(_mage.unit_id) and Vector2i(event.to) == Vector2i(placement.hazard_cell))
		if entered_fire:
			_errors.append("mage_entered_known_fire_instead_of_safe_route")
		if not _has_action("walk"):
			_errors.append("terrain_route_missing_real_walk_animation")
		if scenario == "avoid_fire" and _environment_damage(_mage) != 0:
			_errors.append("safe_route_still_hurt_mage")
		if scenario == "escape_fire":
			if _environment_damage(_mage) <= 0:
				_errors.append("initial_fire_never_hurt_real_mage")
			if not _moves.is_empty() and not _casts.is_empty() and int(_casts[0].started_usec) < int(_moves[0].get("finished_usec", 0)):
				_errors.append("mage_cast_before_leaving_initial_fire")
	if scenario in ["portal_pair", "portal_network"] and not _has_action("walk"):
		_errors.append("portal_entry_missing_voluntary_walk")
	# Deliberately do not claim conduction, melting or sliding: the mage's
	# holy kit does not cause those reactions, and ice currently applies Gel.


func _finish(details: Dictionary) -> void:
	details["scope"] = "RegisteredTerrainBattle on the declared canonical map. Initial permanent-tile/portal fixtures only; AI chooses every enemy action. No runtime HP/AP/MP/occupancy/terrain writes."
	details["terrain_validation"] = {"schema_version": 1,
		"scope": "Declared permanent-tile/portal fixtures before combat on unchanged canonical map topology; AI decides all enemy movement and spells. No midcombat stat or terrain writes.",
		"initial_actors": _terrain_initial, "grid_occupancy_events": _occupancy,
		"tile_visual_contracts": _tile_visuals, "turn_endings": _turn_endings,
		"environment_hp_damage_to_hero": _environment_damage(_hero) if _hero != null else 0,
		"environment_hp_damage_to_mage": _environment_damage(_mage) if _mage != null else 0,
		"hero_terrain_mp_penalty_observed": _hero_mp_reduced_by_one(),
		"hero_shock_activation_skipped": _hero_stunned_activation() if _hero != null else false,
		"actual_portal_jump": _real_portal_jump() if _mage != null and placement.has("portal_entry") else {},
		"cast_from_actual_portal_exit": _cast_from_real_exit() if _mage != null and placement.has("portal_entry") else false,
		"ice_contract": "Frozen status: -1 MP at next activation, no automatic physical slide.",
		"spell_elements_scope": "Canonical holy spells unchanged; no lightning conduction, melting or steam claimed."}
	super._finish(details)
