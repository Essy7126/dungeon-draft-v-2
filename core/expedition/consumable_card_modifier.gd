extends SpellModifier
const Math := preload("res://core/expedition/consumable_card_math.gd")
const Effects := preload("res://core/expedition/consumable_card_effects.gd")
var card: Dictionary = { }


func get_ap_cost(caster, _spell, base_cost: int) -> int:
	var cards = CatabaseCards.for_actor(caster)
	if (
		cards != null and "archive" in cards.active_relics
		and int(card.ap) >= 3 and not cards.trigger_counters.has("archive")
	):
		return maxi(1, base_cost - 1)
	return base_cost


func on_costs_resolved(ctx) -> void:
	var cards = CatabaseCards.for_actor(ctx.caster)
	if "archive" in cards.active_relics and int(card.ap) >= 3:
		cards.take_trigger("archive", true)


func get_range_bonus(caster, _spell) -> int:
	var cards = CatabaseCards.for_actor(caster)
	return (
		int(Math.equipment_mods(cards.equipped).get("range", 0))
		if (cards != null and int(card.get("max", 0)) > 0 and not card.get("fallback", false))
		else 0
	)


func get_preparation_failure_reason(caster, _spell, _grid) -> StringName:
	var cards = CatabaseCards.for_actor(caster)
	if cards == null or cards.ruleset_id != Effects.ID:
		return &"consumable_profile_required"
	if not cards.can_use_family(str(card.id)):
		return &"family_or_choice_unavailable"
	if card.get("chooseSacrifice", false):
		var selected: Variant = cards.action_options.get("sacrifice")
		var cap := floori(minf(caster.current_shield, .8 * caster.attack_power.get_value()))
		if not selected is int or selected < 0 or selected > cap:
			return &"choose_guard_sacrifice"
	if card.get("choosePull", false) and cards.action_options.get("pull") not in [1, 2]:
		return &"choose_pull_distance"
	return &""


func get_target_cell_failure_reason(caster, _spell, cell: Vector2i, grid) -> StringName:
	var target: Unit = grid.get_unit(cell)
	if card.op == "swap" and (target == null or target.get_meta("cc2_boss", false)):
		return &"boss_cannot_swap"
	if (
		card.op == "stasis"
		and (target == null or not Effects.states(target).has("mark") or Effects.states(target).has(
				"stasis_ward"
			))
	):
		return &"requires_mark_without_stasis_immunity"
	return &""


func get_area_override(caster, _spell, cell: Vector2i, grid) -> Variant:
	if card.shape not in ["radius2", "line3_perpendicular"]:
		return null
	var result: Array[Vector2i] = []
	if card.shape == "radius2":
		for x in range(cell.x - 2, cell.x + 3):
			for y in range(cell.y - 2, cell.y + 3):
				if grid.manhattan(cell, Vector2i(x, y)) <= 2:
					result.append(Vector2i(x, y))
	else:
		var axis := Effects.axis(caster.grid_pos, cell)
		var perpendicular := Vector2i(-axis.y, axis.x)
		result.assign([cell - perpendicular, cell, cell + perpendicular])
	var path := Pathfinder.new(grid)
	return result.filter(
		func(pos):
			return (
				grid.is_valid(pos) and grid.is_terrain_interactable(pos)
				and path.has_line_of_sight(caster.grid_pos, pos)
			),
	)


func on_area_resolved(ctx) -> void:
	if card.op != "converge":
		return
	var targets: Array = ctx.grid.get_units().filter(
		func(u):
			return u.team != ctx.caster.team and u.is_alive and ctx.grid.manhattan(
					ctx.cell,
					u.grid_pos,
				) <= 2,
	)
	targets.sort_custom(
		func(a, b):
			var da: int = ctx.grid.manhattan(ctx.cell, a.grid_pos)
			var db: int = ctx.grid.manhattan(ctx.cell, b.grid_pos)
			return str(a.unit_id) < str(b.unit_id) if da == db else da < db,
	)
	for target in targets:
		var moved := Effects.displace(ctx.grid, target, Effects.axis(target.grid_pos, ctx.cell), 1)
		if moved.moved > 0:
			ctx.movement.append(
				{ "unit": target, "from": moved.from, "to": moved.to, "collision": false }
			)


func on_targets_resolved(ctx) -> void:
	var cards = CatabaseCards.for_actor(ctx.caster)
	var captured := { }
	var triggers := Effects.trigger_map(cards)
	var mods := Math.equipment_mods(cards.equipped)
	var targets: Array = []
	for cell in ctx.affected_cells:
		var target: Unit = ctx.grid.get_unit(cell)
		if target != null and target.team != ctx.caster.team and target not in targets:
			targets.append(target)
	targets.sort_custom(
		func(a, b):
			return str(a.unit_id) < str(b.unit_id),
	)
	for target in targets:
		var facts := Effects.mark_facts(ctx.caster, target, cards, cards.action_options)
		captured[target] = facts
		if not ctx.spell.deals_damage():
			continue
		var evaluated := Math.impact(
			card,
			ctx.caster.attack_power.get_value(),
			facts,
			mods,
			cards.primary_class,
			cards.specialization,
			triggers,
			cards,
		)
		for key in evaluated.triggers:
			triggers[key] = true
			cards.take_trigger(key)
		var parry := 0.0
		if card.type == "physical" and Effects.states(target).has("parry"):
			parry = float(Effects.states(target).parry.amount)
			Effects.states(target).erase("parry")
		ctx.impact_options_by_unit[target] = {
			"damage_ruleset": Effects.ID,
			"raw_payload": evaluated.raw,
			"ignore_defense": bool(card.get("pierce", false)),
			"parry_payload": parry,
			"attack_classification": &"cc2_fallback" if card.get("fallback", false) else &"cc2_card",
		}
		if not card.get("fallback", false):
			Effects.states(target).erase("mark")
	ctx.set_meta("cc2_captured", captured)
	ctx.set_meta("cc2_moved_before", cards.moved_cells)
	if card.op == "guardburst":
		ctx.caster.consume_shield_source(&"cc2_guard", int(cards.action_options.sacrifice))


func on_targets_finalized(ctx) -> void:
	if card.id in ["l01", "r08", "t02"]:
		# Presentation snapshot before deaths or a swap; no gameplay changes.
		preload("res://core/expedition/class_card_vfx_facts.gd").new().on_targets_finalized(ctx)


func on_damage_resolved(ctx) -> void:
	var hero: Unit = ctx.caster
	var cards = CatabaseCards.for_actor(hero)
	var power := hero.attack_power.get_value()
	var captured: Dictionary = ctx.get_meta("cc2_captured", { })
	var candidates: Array = []
	var hp_damage := 0
	for target in captured:
		var facts: Dictionary = captured[target]
		var result = ctx.damage_result_by_unit.get(target)
		if result != null:
			hp_damage += maxi(0, result.hp_damage_applied)
			if (
				not card.get("fallback", false)
				and cards.primary_class == "arpenteur" and int(facts.distance) >= 3
			):
				cards.anchor_available = true
		if not target.is_alive:
			if result != null and not card.get("fallback", false):
				if (
					cards.specialization == "relay" and float(facts.mark) > 0
					and facts.mark_origin != "relay"
				):
					candidates.append(target)
				if "obole" in cards.active_relics:
					var earned := int(cards.trigger_counters.get("obole_gold", 0))
					var gain := mini(4, 20 - earned)
					cards.gold += gain
					cards.trigger_counters["obole_gold"] = earned + gain
				if "cup" in cards.active_relics and int(cards.trigger_counters.get("cup_kills", 0)) < 2:
					cards.trigger_counters["cup_kills"] = int(cards.trigger_counters.get(
							"cup_kills",
							0,
						)) + 1
					_heal(ctx, .35 * power, cards)
			continue
		var applied := false
		match str(card.op):
			"mark":
				applied = Effects.apply_state(
					target,
					"mark",
					Math.component(card, "amount", power, cards, "mark", .2 if "seal" in cards.active_relics else 0.0),
					int(card.get("duration", 2)),
					hero,
					{ "origin": "direct" },
				)
			"slow":
				applied = Effects.apply_state(target, "slow", float(card.amount), 1, hero)
			"burn", "bleed":
				var tick := float(card.amount)
				if card.op == "burn":
					if "embers" in cards.active_relics:
						tick += .1
					if cards.specialization == "pyre" and cards.take_trigger("spec"):
						tick += .1
				applied = Effects.apply_state(
					target,
					str(card.op),
					Math.component(card, "amount", power, cards, "periodic", tick - float(card.amount)),
					int(card.get("duration", 2)),
					hero,
				)
			"disrupt":
				Effects.apply_state(
					target,
					"weak",
					.25 if target.get_meta("cc2_boss", false) else float(card.amount),
					1,
					hero,
				)
			"stasis":
				Effects.states(target).erase("mark")
				Effects.apply_state(
					target,
					"weak" if target.get_meta("cc2_boss", false) else "stasis",
					.25 if target.get_meta("cc2_boss", false) else 1.0,
					1,
					hero,
				)
				Effects.apply_state(target, "stasis_ward", 1.0, 3, hero)
		if applied and card.op in ["mark", "slow", "burn"]:
			if cards.primary_class == "thaumaturge" and cards.take_trigger("class"):
				Effects.guard(hero, .2, cards)
			if card.op == "slow" and cards.specialization == "frost" and cards.take_trigger("spec"):
				Effects.guard(hero, .3, cards)
	if not candidates.is_empty() and cards.take_trigger("spec"):
		candidates.sort_custom(
			func(a, b):
				return str(a.unit_id) < str(b.unit_id),
		)
		var facts: Dictionary = captured[candidates[0]]
		var eligible: Array = ctx.grid.get_units().filter(
			func(u):
				return u.is_alive and u.team != hero.team and ctx.grid.manhattan(
						u.grid_pos,
						facts.cell,
					) <= 2,
		)
		if not eligible.is_empty():
			cards.pending_choice = {
				"kind": "relay",
				"cell": [facts.cell.x, facts.cell.y],
				"amount": minf(float(facts.mark), .2 * power),
			}
	if card.op in ["guard", "counter"]:
		var multiplier := 1.0
		if (
			not card.get("fallback", false) and cards.specialization == "bastion"
			and cards.take_trigger("spec")
		):
			multiplier = 1.25
		ctx.report.shield_increase_total += Effects.guard(
			hero,
			float(card.amount),
			cards,
			multiplier,
			&"cc2_g05" if card.op == "counter" else &"",
			card,
		)
		if card.op == "counter":
			Effects.apply_state(hero, "counter", Math.component(card, "counter", power, cards, "indirect"), 1, hero)
	if card.op in ["heal", "renew", "drain"]:
		var amount := power * float(card.amount)
		if card.op == "renew":
			amount = hero.max_hp.get_value() * float(card.amount)
		if card.op == "drain":
			amount = hp_damage * float(card.amount)
		elif cards.prototype_revision == 1:
			amount = Math.component(card, "amount", hero.max_hp.get_value() if card.op == "renew" else power, cards, "heal")
		_heal(ctx, amount, cards, card.op != "drain" and cards.prototype_revision == 1)
	if card.has("shield"):
		ctx.report.shield_increase_total += Effects.guard(hero, float(card.shield), cards, 1.0, &"", card, "shield")
	if card.op == "edict":
		Effects.apply_state(hero, "edict", 1, 1, hero)
	if hp_damage > 0 and not card.get("fallback", false):
		var leech := float(Math.equipment_mods(cards.equipped).get("lifesteal", 0))
		var budget := maxi(
			0,
			Math.rounded(hero.max_hp.get_value() * .1) - int(cards.trigger_counters.get(
					"lifesteal_healed",
					0,
				)),
		)
		if leech > 0 and budget > 0:
			var before := hero.current_hp
			var multiplier := 1.0 + float(Math.equipment_mods(cards.equipped).get("healing", 0))
			_heal(ctx, minf(hp_damage * leech, float(budget) / multiplier), cards)
			cards.trigger_counters["lifesteal_healed"] = int(cards.trigger_counters.get(
					"lifesteal_healed",
					0,
				)) + hero.current_hp - before


func _heal(ctx, raw: float, cards, already_scaled := false) -> void:
	var before: int = ctx.caster.current_hp
	var bonus := 0.0 if already_scaled else float(Math.equipment_mods(cards.equipped).get("healing", 0))
	ctx.caster.heal(Math.rounded(raw * (1.0 + bonus)), ctx.caster)
	ctx.report.healing_total += ctx.caster.current_hp - before


func on_movement_resolved(ctx) -> void:
	var cards = CatabaseCards.for_actor(ctx.caster)
	var target: Unit = ctx.primary_target
	if card.op in ["move", "blink"]:
		var distance := 0
		for move in ctx.movement:
			if move.unit == ctx.caster and move.get("voluntary", false):
				distance += ctx.grid.manhattan(move.from, move.to)
		cards.moved_cells += distance
		if distance > 0 and "thread" in cards.active_relics and cards.take_trigger("thread"):
			ctx.caster.grant_current_activation_mp_bonus(1)
	elif target != null and target.is_alive and card.op in ["push", "pull"]:
		var direction := Effects.axis(ctx.caster.grid_pos, target.grid_pos)
		if card.op == "pull":
			direction = -direction
		var count := (
			int(cards.action_options.get("pull", card.amount))
			if card.get("choosePull", false)
			else int(card.amount)
		)
		var move := Effects.displace(ctx.grid, target, direction, count)
		ctx.report.pushed = move.moved > 0
		if move.moved > 0:
			ctx.movement.append(
				{ "unit": target, "from": move.from, "to": move.to, "collision": move.wall }
			)
			if (
				card.op == "push" and cards.specialization == "crusher"
				and cards.take_trigger("spec")
			):
				Effects.hit(target, ctx.caster, .25 * ctx.caster.attack_power.get_value())
		if move.wall and card.has("collisionGuard"):
			ctx.report.shield_increase_total += Effects.guard(
				ctx.caster,
				float(card.collisionGuard),
				cards,
				1.0, &"", card, "collisionGuard",
			)
	elif target != null and target.is_alive and card.op == "swap":
		var from: Vector2i = ctx.caster.grid_pos
		var to := target.grid_pos
		ctx.grid.remove_unit(target)
		ctx.grid.relocate_unit(ctx.caster, to)
		ctx.grid.place_unit(target, from)
		EventBus.unit_pushed.emit(ctx.caster, from, to, false)
		EventBus.unit_pushed.emit(target, to, from, false)
	preload("res://core/expedition/consumable_card_terrain.gd").resolve_cast(ctx, cards, card)


func on_cast_complete(ctx) -> void:
	var cards = CatabaseCards.for_actor(ctx.caster)
	if card.op == "draw":
		cards.draw_cards(int(card.amount))
	var moved := int(ctx.get_meta("cc2_moved_before", 0))
	if card.get("drawOnMoved", 0) > 0 and moved >= int(card.get("movementThreshold", 2)):
		cards.draw_cards(int(card.drawOnMoved))
	if (
		ctx.spell.deals_damage() and not card.get("fallback", false) and moved >= 2
		and cards.specialization == "skirmish" and cards.take_trigger("spec")
	):
		cards.draw_cards(1)
	if card.get("retain", 0) > 0 and not cards.hand.is_empty():
		cards.pending_choice = { "kind": "retain" }
	if card.get("endTurn", false):
		ctx.caster.consume_current_activation()
	cards.action_options.clear()
	cards.changed.emit()
