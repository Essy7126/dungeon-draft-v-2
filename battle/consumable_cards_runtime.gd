extends Node
## Adapter on the authored Battle: same grid, units, queue, casts and views.
const Integration := preload("res://core/expedition/consumable_cards_integration.gd")
const Turns := preload("res://core/expedition/consumable_card_turns.gd")
const Effects := preload("res://core/expedition/consumable_card_effects.gd")
const Terrain := preload("res://core/expedition/consumable_card_terrain.gd")
const Enemies := preload("res://core/expedition/consumable_enemy_rules.gd")
const Math := preload("res://core/expedition/consumable_card_math.gd")
const NativeStatuses := preload("res://core/expedition/consumable_native_status_checkpoint.gd")
const RoomRules := preload("res://core/expedition/consumable_room_rules.gd")
const Profile := preload("res://core/expedition/consumable_enemy_profile.gd")
const NativeCheckpoint := preload("res://core/expedition/consumable_enemy_checkpoint.gd")
var battle: Node
var session: ExpeditionSession
var restoring := false
var save_failed := false
var room_rules: RefCounted
var room_overlay: Node2D


func setup(value: Node, state: ExpeditionSession) -> void:
	battle = value
	session = state
	Integration.rebuild(session)
	var hero := session.character.unit
	hero.initiative.base_value = 100
	if session.cards.bestiary_revision == 1: hero.combat_order = 0
	var definition := Integration.encounter(session)
	var roster: Array = battle.units.filter(func(unit): return unit.team != hero.team)
	if session.cards.bestiary_revision == 1:
		# The placement planner orders actors by formation. Save identities follow
		# the authored roster, independently of those cell-selection priorities.
		var unassigned := roster.duplicate()
		roster = []
		for data: UnitData in battle.room_data.enemies:
			for candidate: Unit in unassigned:
				if candidate.content_unit_id == data.get_effective_unit_id():
					roster.append(candidate)
					unassigned.erase(candidate)
					break
	definition.roster = []
	for unit in roster:
		var id: String = (str(unit.unit_id) + " " + unit.unit_name).to_lower()
		var kind := "brute"
		if "molosse" in id or "hound" in id: kind = "hound"
		if unit.maximum_range > 1 or unit.preferred_range > 1: kind = "archer"
		if "mage" in id or "lamie" in id or "givre" in id or "braise" in id: kind = "mage"
		if "garde" in id or "guard" in id or "bouclier" in id or "sentinelle" in id or "egide" in id or "égide" in id: kind = "guard"
		if "priest" in id or "prêtre" in id or "collecteur" in id or "officiant" in id: kind = "priest"
		if str(session.route.get_current_node().kind) == "boss" and definition.roster.is_empty(): kind = "boss"
		if not Integration.Catalog.data().enemyTypes.has(kind): kind = str(Integration.Catalog.data().enemyTypes.keys()[0])
		definition.roster.append(kind)
	var models := Enemies.build(definition)
	var eligible: Array[String] = []
	for index in roster.size():
		var unit: Unit = roster[index]
		var model: Unit = models[index]
		if session.cards.bestiary_revision == 1:
			bind_enemy(unit, index)
			eligible.append(str(unit.unit_id))
			continue
		# Stable encounter identity distinguishes two copies of the same monster.
		unit.unit_id = StringName("cc2_enemy_%02d" % index)
		eligible.append(str(unit.unit_id))
		for key in ["max_hp", "attack_power", "max_ap", "max_mp", "armure", "resist_magique", "initiative", "crit_chance", "esquive"]:
			unit.get(key).base_value = model.get(key).base_value
		if session.route.difficulty_id == "easy":
			unit.max_hp.base_value = Math.rounded(unit.max_hp.base_value * .9)
			unit.attack_power.base_value = Math.rounded(unit.attack_power.base_value * .8)
		unit.current_hp = unit.max_hp.get_int()
		for key in ["ai_behavior", "preferred_range", "minimum_range", "maximum_range", "keep_distance"]: unit.set(key, model.get(key))
		unit.ai_profile = null
		unit.combat_form_change = null
		unit.armure.remove_modifiers_from(str(unit.proximity_armor_source))
		unit.proximity_armor_source = &""
		unit.proximity_armor_per_living_neighbor = 0
		unit.proximity_armor_max_neighbors = 0
		unit.first_forced_movement_reduction_per_activation = 0
		unit.spells = model.spells.duplicate()
		unit.basic_attack_enabled = false
		for key in model.get_meta_list(): unit.set_meta(key, model.get_meta(key))
		unit.reset_combat_resources()
	Enemies.bind_encounter_variant(definition, roster)
	Integration.Economy.commit_loot(session.cards, definition, eligible)
	room_rules = RoomRules.new()
	room_rules.configure(definition, battle.grid, battle.terrain_effects, hero, roster, session.cards)
	if not room_rules.room_id.is_empty():
		room_overlay = preload("res://battle/consumable_room_overlay.gd").new()
		room_overlay.runtime = self
		battle.grid_view.add_child(room_overlay)
	if not EventBus.action_resolved.is_connected(_on_action): EventBus.action_resolved.connect(_on_action)
	if not EventBus.hp_damage_taken.is_connected(_on_health_loss): EventBus.hp_damage_taken.connect(_on_health_loss)
	# Runtime IDs are now final; update commander links and formation sources.
	if session.cards.bestiary_revision == 1: battle.grid._next_combat_order = roster.size() + 1
	battle.grid._refresh_tactical_links()


func bind_enemy(unit: Unit, index: int, summoned := false) -> void:
	unit.unit_id = StringName("cc2_enemy_%02d" % index)
	unit.combat_order = index + 1
	var data := UnitData.new()
	data.unit_id = unit.content_unit_id
	data.unit_name = unit.unit_name
	data.maximum_range = unit.maximum_range
	data.preferred_range = unit.preferred_range
	var archetype := Profile.kind(data, session.route.get_current_node().kind == "boss" and index == 0)
	for pair in [["cc2_ruleset", Effects.ID], ["cc2_kind", archetype], ["cc2_spawn", index], ["cc2_boss", archetype == "boss"], ["cc2_phase", 1], ["cc2_sacrificed", false], ["cc2_intent", {}], ["cc2_variant", ""], ["cc2_summoned", summoned]]:
		unit.set_meta(pair[0], pair[1])
	unit.set_meta("cc2_native_type", str(unit.content_unit_id) if Profile.NATIVE.has(str(unit.content_unit_id)) else "")
	if not summoned: unit.reset_combat_resources()


func on_spawn(unit: Unit) -> void:
	if session.cards.bestiary_revision != 1 or restoring: return
	bind_enemy(unit, battle.units.find(unit) - 1, true)


func begin_activation(unit: Unit) -> bool:
	if unit == session.character.unit:
		Turns.begin_hero(unit, session.cards, battle.terrain_effects, false)
		return not unit.is_alive
	var ice := Terrain.begin_activation(battle.terrain_effects, unit)
	var skipped := Turns.apply_activation_statuses(unit, battle.grid, ice)
	Enemies.update_boss_phase(battle.units)
	for other in battle.units: other.clear_shield_source(StringName("cc2_support_" + str(unit.unit_id)))
	if skipped:
		if unit.has_meta("cc2_native_type") and not str(unit.get_meta("cc2_native_type")).is_empty():
			battle.spell_caster.cancel_pending_for_unit(unit, &"stasis")
		unit.set_meta("cc2_intent", {})
		_publish_intent(unit)
	elif room_rules != null:
		room_rules.begin_enemy(unit)
	return skipped


func end_activation(unit: Unit) -> void:
	if unit == session.character.unit:
		if room_rules != null: room_rules.end_hero()
		Turns.end_hero(session.cards, battle.grid)
	for other in battle.units: other.stats_changed.emit(other)


func round_started(number: int) -> void:
	if number <= 1 or battle._battle_over: return
	battle._begin_outcome_deferral()
	if room_rules != null: room_rules.finish_round(number)
	# Battle owns terrain duration ticking; only expire profile marks here.
	for unit in battle.units:
		var effects := Effects.states(unit)
		if effects.has("mark") and not effects.mark.has("expires_hero_end"):
			effects.mark.duration -= 1
			if effects.mark.duration <= 0: effects.erase("mark")
	Terrain.prune(battle.terrain_effects, session.cards)
	var hero := session.character.unit
	if hero.is_alive and battle.units.any(func(u): return u.team != hero.team and u.is_alive):
		if number > 24:
			Effects.hit(hero, null, hero.current_hp, false, "pressure", true)
		else:
			Effects.hit(hero, null, Math.pressure(hero.max_hp.get_int(), number - 1), false, "pressure", true)
	Enemies.update_boss_phase(battle.units)
	battle._finish_outcome_deferral()


func run_enemy(unit: Unit) -> void:
	if not str(unit.get_meta("cc2_native_type", "")).is_empty():
		await battle._enemy_turn.run(unit)
		return
	if unit.activation_consumed: return
	var generation: int = battle._lifecycle_generation
	var hero := session.character.unit
	if not await battle._wait_battle_seconds_safe(.3, generation): return
	if room_rules != null and room_rules.is_courier(unit):
		if not room_rules.deliver(unit):
			var path: Array = room_rules.courier_path(unit)
			if not path.is_empty(): await battle._enemy_turn._execute_move(unit, path)
		return
	var prepared := Enemies.prepare_activation(unit, hero, battle.units, battle.grid, battle.terrain_effects, float(Integration.Catalog.data().rules.prowess[session.cards.level - 1]), false, false)
	_publish_intent(unit)
	if not prepared.get("ready", false): return
	var attacked := false
	var plan: Array = battle.enemy_ai.decide(unit, battle.units)
	for action in plan:
		if not battle._is_operation_current(generation) or battle._battle_over or not unit.is_alive or not hero.is_alive or unit.activation_consumed: return
		if action.type == "move":
			await battle._enemy_turn._execute_move(unit, action.path)
		elif action.type in ["attack", "cast"] and not attacked and unit.get_meta("cc2_variant", "") != "execution":
			if unit.current_ap < unit.get_spell_ap_cost(unit.spells[0]): continue
			if battle.grid.manhattan(unit.grid_pos, hero.grid_pos) < unit.minimum_range or battle.grid.manhattan(unit.grid_pos, hero.grid_pos) > unit.maximum_range or not battle.pathfinder.has_line_of_sight(unit.grid_pos, hero.grid_pos): continue
			var view: Variant = battle._unit_views.get(unit)
			if is_instance_valid(view) and view.has_method("prepare_spell_visual"):
				if not await view.prepare_spell_visual(hero.grid_pos, unit.spells[0]): return
			if not battle._is_operation_current(generation) or battle._battle_over or not unit.is_alive or not hero.is_alive: return
			unit.spend_ap(unit.get_spell_ap_cost(unit.spells[0]))
			Enemies.attack(unit, hero)
			attacked = true
			if unit.get_meta("cc2_boss", false) and int(unit.get_meta("cc2_phase", 1)) == 2 and hero.is_alive:
				Effects.displace(battle.grid, hero, Effects.axis(unit.grid_pos, hero.grid_pos), 1)
			if is_instance_valid(view) and view.has_method("wait_for_action_visual_finished"): await view.wait_for_action_visual_finished()
	if unit.get_meta("cc2_variant", "") == "execution" and battle.grid.manhattan(unit.grid_pos, hero.grid_pos) == 1:
		unit.set_meta("cc2_intent", {"cells": [[hero.grid_pos.x, hero.grid_pos.y]], "multiplier": 1.5})
		_publish_intent(unit)


func _publish_intent(unit: Unit) -> void:
	var intent: Dictionary = unit.get_meta("cc2_intent", {})
	EventBus.telegraph_cleared.emit(unit)
	if not unit.is_alive or intent.is_empty() or intent.get("cells", []).is_empty(): return
	var cells: Array[Vector2i] = []
	for position in intent.cells: cells.append(Vector2i(position[0], position[1]))
	EventBus.ability_telegraphed.emit(unit, unit.spells[0], {"cell": cells[0], "cells": cells, "label": "Prochaine activation · impact ×%.1f" % float(intent.multiplier), "color": Color("f58b66")})


func _on_action(actor, _id, kind, report: Dictionary) -> void:
	if restoring or session == null or actor != session.character.unit: return
	if kind == &"voluntary_movement": session.cards.moved_cells += int(report.get("distance", 0))
	Enemies.update_boss_phase(battle.units)
	for unit in battle.units: unit.stats_changed.emit(unit)


func _on_health_loss(fact: CombatEventFact) -> void:
	if not restoring and fact.target in battle.units:
		Enemies.update_boss_phase([fact.target])


func use_room_command(action: String) -> bool:
	if room_rules == null or not battle._can_accept_player_intent() or battle.turn_queue.get_current_unit() != session.character.unit or not session.cards.pending_choice.is_empty(): return false
	if not room_rules.failure(action).is_empty(): return false
	battle._begin_outcome_deferral()
	var used: bool = room_rules.use_command(action)
	if used:
		battle._cancel_action_selection_for_active_unit()
		battle._hud_port.update_info(session.character.unit)
		battle._hud_port.build_actions(session.character.unit)
	if battle._finish_outcome_deferral(): return used
	if used: checkpoint()
	return used


func choose(request: Dictionary) -> bool:
	if not battle._can_accept_player_intent() or battle.turn_queue.get_current_unit() != session.character.unit: return false
	var cards = session.cards
	var ok := false
	match str(request.get("kind", "")):
		"retain": ok = cards.retain_copy(str(request.get("uid", "")))
		"relay":
			var target: Unit = null
			for unit in battle.units:
				if str(unit.unit_id) == str(request.get("target", "")): target = unit
			ok = Effects.relay(session.character.unit, cards, target)
		"anchor":
			if cards.pending_choice.is_empty(): ok = Effects.return_to_anchor(session.character.unit, cards, battle.grid)
	if ok:
		cards.changed.emit()
		checkpoint()
	return ok


func checkpoint() -> bool:
	if restoring or battle._closing or battle._battle_over or session.route.phase != "combat": return false
	if battle.turn_queue.get_current_unit() != session.character.unit: return false
	var records := []
	var ordered: Array = [session.character.unit]
	var enemies: Array = battle.units.filter(func(unit): return unit != session.character.unit)
	if session.cards.bestiary_revision == 1:
		enemies.sort_custom(func(a, b): return int(a.get_meta("cc2_spawn")) < int(b.get_meta("cc2_spawn")))
	ordered.append_array(enemies)
	for unit in ordered:
		var metadata := {}
		for key in unit.get_meta_list():
			if str(key).begins_with("cc2_") and key != &"cc2_cards": metadata[str(key)] = unit.get_meta(key)
		var queued := {}
		for key in ["next_turn_ap_modifier", "next_turn_mp_bonus", "next_turn_mp_penalty", "_moved_cells_this_activation", "_mp_spent_this_activation"]: queued[key] = unit.get(key)
		records.append({"id": str(unit.unit_id), "cell": [unit.grid_pos.x, unit.grid_pos.y], "hp": unit.current_hp, "ap": unit.current_ap, "mp": unit.current_mp, "alive": unit.is_alive, "activation": unit.activation_index, "consumed": unit.activation_consumed, "abilities": unit._ability_states.duplicate(true), "shields": unit.get_shield_instances_snapshot(), "statuses": NativeStatuses.snapshot(unit), "queued": queued, "metadata": metadata})
		if session.cards.bestiary_revision == 1: records[-1]["native"] = NativeCheckpoint.snapshot(unit)
	var native_terrain := {"serial": battle.terrain_effects.runtime_service._resolution_serial, "void": {}, "electric": battle.terrain_effects.runtime_service._electrified_trigger_by_unit.duplicate(true)}
	for unit in ordered:
		var used: int = battle.terrain_effects.runtime_service._void_impulse_round_by_unit.get(unit.get_instance_id(), -1)
		if used >= 0: native_terrain.void[str(unit.unit_id)] = used
	session.combat_checkpoint = JSON.parse_string(JSON.stringify({"version": 2, "node": session.route.current_node_id, "round": battle.turn_queue.round_number, "units": records, "surfaces": Terrain.snapshot(battle.terrain_effects), "native_terrain": native_terrain, "cast_sequence": battle.spell_caster._cast_sequence, "room": room_rules.state if room_rules != null else {}}))
	if session.cards.bestiary_revision == 1:
		session.combat_checkpoint.version = 3
		session.combat_checkpoint["summon_budgets"] = NativeCheckpoint.budgets(battle.encounter_runtime_state)
		session.combat_checkpoint["turn_order"] = battle.turn_queue.get_full_order().map(func(actor): return str(actor.unit_id))
		session.combat_checkpoint = JSON.parse_string(JSON.stringify(session.combat_checkpoint))
	session.gold = session.cards.gold
	save_failed = not GameManager.commit_consumable_combat_checkpoint()
	return not save_failed


func restore_checkpoint() -> bool:
	var checkpoint: Dictionary = session.combat_checkpoint
	if checkpoint.is_empty(): return false
	restoring = true
	if int(checkpoint.version) == 3:
		for index in range(battle.units.size(), checkpoint.units.size()):
			var saved: Dictionary = checkpoint.units[index]
			var summoned := Unit.from_data(Profile.summon_data(saved.native.type, session.route.get_current_node()))
			bind_enemy(summoned, index - 1, true)
			battle.units.append(summoned)
			battle.turn_queue.add_unit(summoned)
			battle._on_pending_unit_spawned(summoned)
	var units := {}
	for unit in battle.units: units[str(unit.unit_id)] = unit
	if int(checkpoint.version) == 3:
		for saved in checkpoint.units: units[saved.id].combat_order = int(saved.native.order)
	if int(checkpoint.version) >= 2 and room_rules != null and not checkpoint.room.is_empty():
		room_rules.restore(checkpoint.room)
	# Restoring occupancy must not fire entry hazards, teleports or reactions.
	battle.grid.set_block_signals(true)
	for unit in battle.units: battle.grid.remove_unit(unit)
	for saved in checkpoint.units:
		var unit: Unit = null
		for candidate in battle.units:
			if str(candidate.unit_id) == saved.id: unit = candidate
		if unit == null:
			save_failed = true
			battle.grid.set_block_signals(false)
			restoring = false
			return true # Fail closed: never draw a new hand over a continuation.
		NativeStatuses.restore(unit, saved.statuses, units)
		unit.current_hp = int(saved.hp)
		unit.current_ap = int(saved.ap)
		unit.current_mp = int(saved.mp)
		unit.is_alive = saved.alive
		unit.activation_index = int(saved.activation)
		unit.activation_consumed = saved.consumed
		for key in saved.queued: unit.set(key, int(saved.queued[key]))
		unit._ability_states = saved.abilities.duplicate(true)
		unit.restore_shield_instances_snapshot(saved.shields)
		for key in saved.metadata: unit.set_meta(key, saved.metadata[key])
		var cell := Vector2i(saved.cell[0], saved.cell[1])
		if unit.is_alive: battle.grid.place_unit(unit, cell)
		else: unit.grid_pos = cell
		var view: Variant = battle._unit_views.get(unit)
		if is_instance_valid(view):
			view.position = battle.grid_cell_to_parent_local(cell, view.get_parent())
			view.visible = unit.is_alive
		if int(checkpoint.version) == 3: NativeCheckpoint.restore_pending(unit, saved.native, units, battle.encounter_runtime_state)
	battle.grid.set_block_signals(false)
	if int(checkpoint.version) == 3:
		battle.encounter_runtime_state.normal_summons_committed = int(checkpoint.summon_budgets.normal)
		battle.encounter_runtime_state.chief_summons_committed = int(checkpoint.summon_budgets.chief)
		battle.grid._next_combat_order = 1 + checkpoint.units.map(func(entry): return int(entry.native.order)).max()
		battle.grid._refresh_tactical_links()
		battle.turn_queue._order.assign(checkpoint.turn_order.map(func(id): return units[id]))
	if int(checkpoint.version) == 1 and room_rules != null and not room_rules.state.is_empty():
		# Older integrated fights had no mechanisms to replay. Start their room state
		# at the restored decision, with the current hand, resources and consumed UIDs.
		var hero := session.character.unit
		room_rules.state.clock = [hero.grid_pos.x, hero.grid_pos.y]
	Enemies.bind_encounter_variant(Integration.encounter(session), battle.units.filter(func(unit): return unit != session.character.unit))
	# Repair older continuations saved below the threshold before this transition fix.
	Enemies.update_boss_phase(battle.units)
	for entry in checkpoint.surfaces:
		var cell := Vector2i(entry.cell[0], entry.cell[1])
		var source: Unit = null
		for unit in battle.units:
			if str(unit.unit_id) == entry.source: source = unit
		battle.terrain_effects.place_effect(cell, Terrain.effect(entry.surface, int(entry.duration)), source)
		battle.terrain_effects.runtime_service.get_state(cell).gameplay_flags = entry.flags.duplicate(true)
	var service = battle.terrain_effects.runtime_service
	service.configure_resolution_context(0, int(checkpoint.round))
	service._resolution_serial = int(checkpoint.native_terrain.serial)
	service._electrified_trigger_by_unit = checkpoint.native_terrain.electric.duplicate(true)
	service._void_impulse_round_by_unit.clear()
	for id in checkpoint.native_terrain.void: service._void_impulse_round_by_unit[units[id].get_instance_id()] = int(checkpoint.native_terrain.void[id])
	battle.turn_queue.round_number = int(checkpoint.round)
	battle.turn_queue._current_index = battle.turn_queue._order.find(session.character.unit)
	battle.spell_caster._cast_sequence = int(checkpoint.cast_sequence)
	battle._turn_end_committed = false
	battle.turn_state.begin_player_turn()
	battle.presentation_state.set_lock(&"battle_not_started", false)
	battle._update_active_highlight(session.character.unit)
	battle._hud_port.update_info(session.character.unit)
	battle._hud_port.build_actions(session.character.unit)
	battle.turn_queue.queue_changed.emit()
	for unit in battle.units:
		if unit.team != session.character.unit.team:
			_publish_intent(unit)
			if int(checkpoint.version) == 3: NativeCheckpoint.publish(unit)
	restoring = false
	return true
