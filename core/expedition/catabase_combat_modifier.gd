class_name CatabaseCombatModifier
extends SpellModifier
## Per-combat mutable state lives on the actor, never on shared resources.
@export var mode := "passives"
@export var weapon_id := ""
@export var amount := 0.5
@export var price := 12
@export var charges := 3

static func reset_actor(hero: Unit) -> void:
	for key in hero.get_meta_list():
		if String(key).begins_with("ct_") and key != &"ct_session": hero.remove_meta(key)
	hero.set_meta("ct_healing", 30)
	hero.set_meta("ct_gold_earned", 0)
	hero.set_meta("ct_bronze", 0)

static func session_for(hero: Unit):
	if not hero.has_meta("ct_session"): return null
	var reference: Variant = hero.get_meta("ct_session")
	return reference.get_ref() if reference is WeakRef else null

static func cleanse(hero: Unit) -> bool:
	var changed := false
	for entry in hero.active_statuses.duplicate():
		var status: StatusData = entry.get("data")
		if status == null: continue
		var negative := status.ap_reduction > 0 or status.mp_reduction > 0
		for value in status.stat_modifiers.values(): negative = negative or float(value) < 0
		if negative:
			hero.remove_status(status.get_effective_status_id(), entry.get("source"), true)
			changed = true
	return changed

func get_target_cell_failure_reason(caster, spell, cell: Vector2i, grid) -> StringName:
	if caster == null: return &"caster"
	if mode == "passives":
		var session = session_for(caster)
		if session != null and not session.build.starting_selection.is_empty():
			var id := String(spell.spell_id)
			for weapon in CatabasePreparationCatalog.WEAPONS:
				for index in [2, 3]:
					var root: String = CatabasePreparationCatalog.WEAPONS[weapon][index]
					if id != root and not id.begins_with(root + "_"): continue
					var equipped := false
					for modifier in caster.get_equipment_spell_modifiers():
						if modifier is CatabaseCombatModifier and modifier.mode == "weapon" and modifier.weapon_id == weapon: equipped = true
					if not equipped: return &"Équipez l'arme correspondante à cette technique."
	match mode:
		"throw":
			if caster.has_meta("ct_disc"): return &"Récupérez le disque avant de relancer."
		"return":
			if not caster.has_meta("ct_disc"): return &"Lancez d'abord le disque."
			if not Pathfinder.new(grid).has_line_of_sight(caster.get_meta("ct_disc"), caster.grid_pos): return &"Le trajet du retour est bloqué."
		"toll":
			var session = session_for(caster)
			if session == null or session.gold < price: return &"Oboles insuffisantes pour ce péage."
			if int(caster.get_meta("ct_toll_turn", -1)) == caster.activation_index: return &"Un péage attend déjà votre prochain impact."
		"bronze":
			if int(caster.get_meta("ct_bronze", 0)) <= 0: return &"L'urne ne contient pas de bronze."
		"flux":
			var effect: Variant = grid.get_effect(cell)
			if not effect is Dictionary or String(effect.get("name", "")) != "Braise": return &"Ciblez une braise encore active."
			var payload: Dictionary = effect.get("data", {})
			if payload.get("source_unit") != caster or payload.get("surface_id") != &"ct_braise": return &"Cette braise ne vous appartient pas."
			var destination := flux_destination(caster, cell)
			if destination == cell or not grid.is_valid(destination) or not grid.is_walkable(destination, grid.get_unit(destination)) or grid.get_effect(destination) != null: return &"La case d'arrivée doit être libre de surface et praticable."
			if not Pathfinder.new(grid).has_line_of_sight(cell, destination): return &"Un obstacle bloque le trajet de la braise."
	return &""

static func flux_destination(caster: Unit, cell: Vector2i) -> Vector2i:
	var delta := cell - caster.grid_pos
	var step := Vector2i(signi(delta.x), 0) if absi(delta.x) >= absi(delta.y) else Vector2i(0, signi(delta.y))
	return cell + step * (2 if caster.get_meta("ct_relic_5", false) else 1)

func get_area_override(caster, _spell, _cell: Vector2i, grid) -> Variant:
	if mode != "return": return null
	if caster == null or not caster.has_meta("ct_disc"): return []
	var cells: Array = Pathfinder.new(grid)._bresenham(caster.get_meta("ct_disc"), caster.grid_pos)
	return cells.filter(func(cell): return cell != caster.grid_pos)

func on_costs_resolved(ctx) -> void:
	if bool(ctx.get_meta("automatic_cast", false)): return
	if mode == "toll":
		var session = session_for(ctx.caster)
		if session != null:
			session.gold -= price
			ctx.caster.set_meta("ct_toll_turn", ctx.caster.activation_index)
			ctx.caster.set_meta("ct_toll", amount)
	if mode == "bronze":
		var spent := mini(30, int(ctx.caster.get_meta("ct_bronze", 0)))
		ctx.caster.set_meta("ct_bronze", int(ctx.caster.get_meta("ct_bronze", 0)) - spent)
		ctx.set_meta("ct_bronze_spent", spent)

func on_targets_resolved(ctx) -> void:
	if mode == "harvest":
		for cell in ctx.affected_cells:
			var target = ctx.grid.get_unit(cell)
			if target != null and target.has_status(&"exp_ct_plaie"):
				ctx.damage_bonus_by_cell[cell] = int(ctx.damage_bonus_by_cell.get(cell, 0)) + roundi(ctx.spell.get_scaled_damage(ctx.caster) * 0.5)
	if mode == "bronze":
		for cell in ctx.affected_cells:
			ctx.damage_bonus_by_cell[cell] = roundi(int(ctx.get_meta("ct_bronze_spent", 0)) * 1.5) - ctx.spell.get_scaled_damage(ctx.caster)
	if mode != "passives" or bool(ctx.get_meta("automatic_cast", false)): return
	var hero: Unit = ctx.caster
	var toll := float(hero.get_meta("ct_toll", 0.0)) if int(hero.get_meta("ct_toll_turn", -1)) == hero.activation_index else 0.0
	var toll_used := false
	for cell in ctx.affected_cells:
		var target = ctx.grid.get_unit(cell)
		if target == null or target.team == hero.team or not ctx.spell.deals_damage(): continue
		var percent := 0.0
		if hero.get_meta("ct_relic_1", false) and ctx.spell.damage_type == Spell.DamageType.PHYSICAL and bool(hero.get_equipment_condition_facts(target).get("target_moved_or_collided", false)): percent += 0.2
		if toll > 0 and not toll_used:
			percent += toll
			toll_used = true
		ctx.damage_bonus_by_cell[cell] = int(ctx.damage_bonus_by_cell.get(cell, 0)) + roundi(ctx.spell.get_scaled_damage(hero) * percent)
	if toll_used:
		hero.remove_meta("ct_toll")
		hero.remove_meta("ct_toll_turn")

func on_damage_resolved(ctx) -> void:
	var hero: Unit = ctx.caster
	match mode:
		"salve":
			var reduction := int(amount) if amount > 1 else 6
			hero.add_sourced_shield(&"ct_salve", reduction * charges, hero, {"tags": [&"guard", &"salve"], "expires_after_activations": 1, "max_absorption_per_hit": reduction, "remaining_impacts": charges})
		"cleanse":
			cleanse(hero)
			hero.resist_magique.remove_modifiers_from("ct_sceau")
			hero.resist_magique.add_modifier(10, Stat.ModType.FLAT, "ct_sceau", 1)
		"passives":
			if bool(ctx.get_meta("automatic_cast", false)): return
			var damage := 0
			var kills := 0
			for target in ctx.damage_result_by_unit:
				if target.team == hero.team: continue
				var fact: DamageResolver.DamageResult = ctx.damage_result_by_unit[target]
				damage += maxi(0, fact.hp_damage_applied)
				if not target.is_alive and fact.hp_damage_applied > 0: kills += 1
			if hero.get_meta("ct_relic_4", false) and ctx.spell.damage_type == Spell.DamageType.PHYSICAL:
				var remaining := int(hero.get_meta("ct_healing", 0))
				var before := hero.current_hp
				hero.heal(mini(remaining, floori(damage * 0.15)), hero, {"action_id": StringName("relic:ct_coupe:" + String(ctx.action_id))})
				hero.set_meta("ct_healing", remaining - maxi(0, hero.current_hp - before))
			if kills > 0 and hero.get_meta("ct_relic_6", false):
				var gained := mini(kills * 4, 20 - int(hero.get_meta("ct_gold_earned", 0)))
				var session = session_for(hero)
				if session != null:
					session.gold += gained
					hero.set_meta("ct_gold_earned", int(hero.get_meta("ct_gold_earned", 0)) + gained)

func on_terrain_resolved(ctx) -> void:
	if bool(ctx.get_meta("automatic_cast", false)): return
	if mode == "flux":
		var effect: TerrainEffectData = ctx.terrain.get_effect_data(ctx.cell)
		var duration: int = ctx.terrain.get_remaining_duration(ctx.cell)
		if effect == null or effect.surface_id != &"ct_braise": return
		var destination := flux_destination(ctx.caster, ctx.cell)
		var result: Dictionary = ctx.terrain.place_effect(destination, effect, ctx.caster, ctx.spell, duration)
		if not bool(result.get("changed", false)): return
		ctx.terrain.clear_effect(ctx.cell)
		var owned: Array = ctx.caster.get_meta("ct_braises", [])
		owned.erase(ctx.cell)
		owned.append(destination)
		ctx.caster.set_meta("ct_braises", owned)
		ctx.report["terrain_changed"].append_array([ctx.cell, destination])
	if mode == "passives" and ctx.spell.terrain_effect != null and ctx.spell.terrain_effect.surface_id == &"ct_braise":
		var owned: Array = ctx.caster.get_meta("ct_braises", [])
		for cell in ctx.affected_cells:
			if ctx.terrain.get_surface_id(cell) == &"ct_braise" and cell not in owned: owned.append(cell)
		ctx.caster.set_meta("ct_braises", owned)

func on_cast_complete(ctx) -> void:
	if bool(ctx.get_meta("automatic_cast", false)): return
	if mode == "throw": ctx.caster.set_meta("ct_disc", ctx.cell)
	if mode == "return":
		ctx.caster.remove_meta("ct_disc")
		if ctx.caster.get_meta("ct_relic_3", false) and int(ctx.caster.get_meta("ct_return_turn", -1)) != ctx.caster.activation_index:
			ctx.caster.grant_current_activation_mp_bonus(1)
			ctx.caster.set_meta("ct_return_turn", ctx.caster.activation_index)
