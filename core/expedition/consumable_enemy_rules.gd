extends RefCounted
## Encounter policy around the shared EnemyAI, Pathfinder, Unit and damage service.
const Catalog := preload("res://core/expedition/consumable_card_catalog.gd")
const Effects := preload("res://core/expedition/consumable_card_effects.gd")
const Turns := preload("res://core/expedition/consumable_card_turns.gd")
const Terrain := preload("res://core/expedition/consumable_card_terrain.gd")
const Math := preload("res://core/expedition/consumable_card_math.gd")


static func build(encounter: Dictionary) -> Array[Unit]:
	var data := Catalog.data()
	var total_weight := 0.0
	for kind in encounter.roster: total_weight += float(data.enemyTypes[kind].weight)
	var result: Array[Unit] = []
	for index in encounter.roster.size():
		var kind: String = encounter.roster[index]
		var row: Dictionary = data.enemyTypes[kind]
		var hp := Math.rounded(float(data.rules.prowess[int(encounter.level) - 1]) * float(encounter.hpBudget) * float(row.weight) / total_weight)
		var attack := Math.rounded(float(data.rules.hp[int(encounter.level) - 1]) * float(row.attack))
		var unit := Unit.new(str(row.name), 1, hp, 1, 1, int(row.mp), attack)
		unit.unit_id = StringName("cc2_enemy_%02d" % index)
		unit.armure.base_value = float(row.armor) * 100.0
		unit.preferred_range = int(row.range)
		unit.minimum_range = 1
		unit.maximum_range = int(row.range)
		unit.ai_behavior = 1 if int(row.range) > 1 else 0
		unit.keep_distance = int(row.range) > 1
		unit.set_meta("cc2_ruleset", Effects.ID)
		unit.set_meta("cc2_kind", kind)
		unit.set_meta("cc2_spawn", index)
		unit.set_meta("cc2_boss", kind == "boss")
		unit.set_meta("cc2_phase", 1)
		unit.set_meta("cc2_sacrificed", false)
		unit.set_meta("cc2_intent", {})
		unit.set_meta("cc2_variant", "")
		var spell := Spell.new()
		spell.spell_id = &"cc2_enemy_attack"
		spell.spell_name = "Attaque"
		spell.damage = attack
		spell.damage_type = Spell.DamageType.MAGICAL if row.type == "magic" else Spell.DamageType.PHYSICAL
		spell.spell_range = int(row.range)
		spell.minimum_range = 1
		spell.once_per_activation = true
		unit.add_spell(spell)
		if encounter.encounterVariant == "telegraphed_execution" and index == encounter.roster.size() - 1:
			unit.set_meta("cc2_variant", "execution")
			unit.unit_name = "Exécuteur du seuil"
		if encounter.encounterVariant == "support_line_of_sight" and kind == "mage": unit.set_meta("cc2_variant", "support")
		if encounter.encounterVariant == "break_guard_formation" and kind == "guard": unit.set_meta("cc2_variant", "formation")
		if encounter.encounterVariant == "finite_parry" and kind == "guard": unit.set_meta("cc2_variant", "parry")
		result.append(unit)
	return result


static func prepare_activation(enemy: Unit, hero: Unit, all_units: Array, grid: GridData, terrain: TerrainEffects, reference_power: float, reset_resources := true, resolve_statuses := true) -> Dictionary:
	var report := {"unit": str(enemy.unit_id), "kind": "idle", "from": [enemy.grid_pos.x, enemy.grid_pos.y]}
	if not enemy.is_alive or not hero.is_alive: return report
	var shield_source := StringName("cc2_support_" + str(enemy.unit_id))
	for unit in all_units: unit.clear_shield_source(shield_source)
	if reset_resources: enemy.start_turn()
	var skipped := false
	if resolve_statuses:
		var ice := Terrain.begin_activation(terrain, enemy)
		skipped = Turns.apply_activation_statuses(enemy, grid, ice)
	if skipped:
		enemy.set_meta("cc2_intent", {})
		report.kind = "skipped"
		return report
	update_boss_phase(all_units)
	var variant := str(enemy.get_meta("cc2_variant", ""))
	var boss: bool = enemy.get_meta("cc2_boss", false)
	var intent: Dictionary = enemy.get_meta("cc2_intent", {})
	if enemy.get_meta("cc2_kind", "") == "priest" and enemy.activation_index % 2 == 0:
		var allies: Array = all_units.filter(func(u): return u.is_alive and u.team == enemy.team)
		allies.sort_custom(func(a, b): return str(a.unit_id) < str(b.unit_id) if a.get_hp_ratio() == b.get_hp_ratio() else a.get_hp_ratio() < b.get_hp_ratio())
		if not allies.is_empty(): allies[0].add_sourced_shield(shield_source, Math.rounded(.25 * reference_power), enemy)
	if not intent.is_empty():
		enemy.set_meta("cc2_intent", {})
		var cells: Array = intent.get("cells", [])
		for value in cells:
			var cell := Vector2i(value[0], value[1])
			if hero.grid_pos == cell and (boss or grid.manhattan(enemy.grid_pos, cell) == 1):
				attack(enemy, hero, float(intent.multiplier))
		report.kind = "resolve_intent"
		return report
	if variant == "support" and enemy.activation_index % 2 == 1:
		var path := Pathfinder.new(grid)
		var eligible: Array = all_units.filter(func(u): return u != enemy and u.is_alive and u.team == enemy.team and grid.manhattan(u.grid_pos, enemy.grid_pos) <= 3 and path.has_line_of_sight(enemy.grid_pos, u.grid_pos))
		eligible.sort_custom(func(a, b): return str(a.unit_id) < str(b.unit_id) if a.get_hp_ratio() == b.get_hp_ratio() else a.get_hp_ratio() < b.get_hp_ratio())
		if not eligible.is_empty():
			eligible[0].add_sourced_shield(shield_source, Math.rounded(.4 * reference_power), enemy)
			report.kind = "protect_ally"
			report.target = str(eligible[0].unit_id)
			return report
	if variant == "formation" and grid.manhattan(enemy.grid_pos, hero.grid_pos) != 1:
		for unit in all_units:
			if unit != enemy and unit.is_alive and unit.team == enemy.team and grid.manhattan(enemy.grid_pos, unit.grid_pos) == 1:
				unit.add_sourced_shield(shield_source, Math.rounded(.25 * reference_power), enemy)
	if variant == "parry": Effects.apply_state(enemy, "parry", .4 * reference_power, 1, enemy)
	if boss and int(enemy.get_meta("cc2_phase", 1)) == 1 and enemy.activation_index % 3 == 1:
		var direction := Effects.axis(enemy.grid_pos, hero.grid_pos)
		var cells: Array = []
		for index in range(1, 4):
			var cell := enemy.grid_pos + direction * index
			if grid.is_valid(cell): cells.append([cell.x, cell.y])
		enemy.set_meta("cc2_intent", {"cells": cells, "multiplier": 1.4})
		report.kind = "prepare_line"
		return report
	report["ready"] = true
	return report


static func activate(enemy: Unit, hero: Unit, all_units: Array, grid: GridData, terrain: TerrainEffects, caster: SpellCaster, reference_power: float) -> Dictionary:
	var report := prepare_activation(enemy, hero, all_units, grid, terrain, reference_power)
	if not report.get("ready", false): return report
	var variant := str(enemy.get_meta("cc2_variant", ""))
	var boss: bool = enemy.get_meta("cc2_boss", false)
	var ai := EnemyAI.new(grid, Pathfinder.new(grid), caster)
	var plan := ai.decide(enemy, all_units)
	var attacked := false
	for action in plan:
		if not enemy.is_alive or not hero.is_alive: break
		if action.type == "move":
			for cell in action.path:
				if cell == enemy.grid_pos: continue
				if enemy.current_mp < 1 or grid.manhattan(enemy.grid_pos, cell) != 1 or not grid.is_walkable(cell): break
				if grid.relocate_unit(enemy, cell): enemy.spend_mp(1)
		elif variant != "execution" and not attacked and action.type in ["attack", "cast"]:
			if grid.manhattan(enemy.grid_pos, hero.grid_pos) <= enemy.maximum_range and Pathfinder.new(grid).has_line_of_sight(enemy.grid_pos, hero.grid_pos):
				attack(enemy, hero)
				attacked = true
	if variant == "execution" and grid.manhattan(enemy.grid_pos, hero.grid_pos) == 1:
		enemy.set_meta("cc2_intent", {"cells": [[hero.grid_pos.x, hero.grid_pos.y]], "multiplier": 1.5})
		report.kind = "prepare_execution"
	elif attacked:
		report.kind = "attack"
		if boss and int(enemy.get_meta("cc2_phase", 1)) == 2 and hero.is_alive:
			Effects.displace(grid, hero, Effects.axis(enemy.grid_pos, hero.grid_pos), 1)
	else: report.kind = "move"
	return report


static func attack(enemy: Unit, hero: Unit, multiplier := 1.0) -> void:
	var effects := Effects.states(enemy)
	var raw := enemy.attack_power.get_value() * multiplier
	if effects.has("weak"):
		raw *= 1.0 - float(effects.weak.amount)
		effects.erase("weak")
	var magic: bool = Catalog.data().enemyTypes[str(enemy.get_meta("cc2_kind"))].type == "magic"
	var cards = CatabaseCards.for_actor(hero)
	var resistance := hero.resist_magique.get_value() / 100.0 if magic else hero.armure.get_value() / 100.0
	# First-hit flat reduction happens after defense, before the single rounding.
	if cards != null and cards.take_trigger("first_received", true):
		var reduction := float(Math.equipment_mods(cards.equipped).get("firstHitReduction", 0)) * hero.attack_power.get_value()
		raw = maxf(0, raw * (1.0 - clampf(resistance, 0, .4)) - reduction)
		Effects.hit(hero, enemy, raw, magic, "attack", true)
	else:
		Effects.hit(hero, enemy, raw, magic, "attack")


static func update_boss_phase(units: Array) -> void:
	for unit in units:
		if unit.is_alive and unit.current_hp > 0 and unit.get_meta("cc2_boss", false) and unit.current_hp * 2 <= unit.max_hp.get_int():
			unit.set_meta("cc2_phase", 2)


static func bind_encounter_variant(encounter: Dictionary, actors: Array) -> void:
	# The authored roster keeps its appearance and numeric archetypes. A mandatory
	# encounter role must nevertheless exist, even when none is named "guard".
	var spec: Array = {
		"telegraphed_execution": ["execution", "brute", "catabase_evolution_executeur"],
		"support_line_of_sight": ["support", "mage", "catabase_evolution_lamie"],
		"break_guard_formation": ["formation", "guard", "catabase_evolution_porte_egide"],
		"finite_parry": ["parry", "guard", "catabase_evolution_porte_egide"],
	}.get(str(encounter.encounterVariant), [])
	if spec.is_empty() or actors.is_empty(): return
	var chosen: Unit = null
	for actor in actors:
		if str(actor.tactical_role_id) == spec[2]:
			chosen = actor
			break
	if chosen == null:
		for actor in actors:
			if str(actor.get_meta("cc2_kind", "")) == spec[1]:
				chosen = actor
				if spec[0] != "execution": break
	if chosen == null:
		# Stable spawn order, not translated names; use the designated contract slot.
		var slot: int = encounter.roster.find(spec[1])
		chosen = actors[clampi(slot, 0, actors.size() - 1)]
	for actor in actors:
		actor.set_meta("cc2_variant", spec[0] if actor == chosen else "")
