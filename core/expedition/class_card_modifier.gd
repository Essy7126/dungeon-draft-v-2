extends SpellModifier
## Uses the shared cast context. No mutation of catalogue resources.
var effect := ""
var value := 0.0
var class_id := ""


func on_targets_resolved(ctx) -> void:
	var session = CatabaseCombatModifier.session_for(ctx.caster)
	var cards = session.cards if session != null else null
	var passive := ""
	if cards != null and cards.rules_revision == 3:
		passive = cards.specialization if not cards.specialization.is_empty() else cards.primary_class
	var available: bool = int(ctx.caster.get_meta("ct_class_passive_turn", -1)) != ctx \
			.caster \
			.activation_index
	var count := 0
	for cell in ctx.affected_cells:
		var target = ctx.grid.get_unit(cell)
		if target != null and target.team != ctx.caster.team:
			count += 1
	for cell in ctx.affected_cells:
		var target = ctx.grid.get_unit(cell)
		if target == null:
			continue
		if (
			target == ctx.caster and effect == "guard"
			and available and passive in ["gardien", "bastion"]
		):
			ctx.additional_shield_by_unit[target] = roundi(
				ctx.spell.get_scaled_shield(ctx.caster) * (.4 if passive == "bastion" else .2)
			)
			ctx.report["class_passive"] = true
		if target.team == ctx.caster.team:
			continue
		var facts: Dictionary = ctx.caster.get_equipment_condition_facts(target)
		var marked: bool = target.has_status(&"class_marked")
		var slowed: bool = target.has_status(&"class_slow")
		var moved: bool = int(facts.get("prior_moved_cells", 0)) >= 2
		var wounded: bool = bool(facts.get("hp_lost_since_previous_activation", false))
		var displaced: bool = bool(facts.get("target_moved_or_collided", false))
		var execute: bool = target.get_hp_ratio() <= .35
		var distance: int = ctx.grid.manhattan(ctx.caster.grid_pos, target.grid_pos)
		var condition: bool = (
			(effect == "marked" and marked) or (effect == "moved" and moved)
			or (effect == "execute" and execute)
			or (effect == "guarded" and ctx.caster.current_shield > 0)
			or (effect == "wounded" and wounded) or (effect == "displaced" and displaced)
		)
		var bonus := roundi(ctx.caster.attack_power.get_value() * value) if condition else 0
		if effect in ["bleed", "burn", "weaken"]:
			var status := StatusData.new()
			status.status_id = StringName("class_" + effect)
			status.status_name = { "bleed": "Saignement", "burn": "Brûlure", "weaken": "Affaibli" }[
				effect
			]
			status.duration = 1 if effect == "weaken" else 2
			status.unique_per_source = true
			if effect == "weaken":
				status.stat_modifiers = {
					&"attack_power": -roundi(target.attack_power.get_value() * value)
				}
			else:
				status.damage_per_turn = roundi(ctx.caster.attack_power.get_value() * value)
				status.damage_type = ctx.spell.damage_type
				status.element = ctx.spell.element
			ctx.additional_statuses_by_unit[target] = [status]
			ctx.additional_status_sources_by_unit[target] = ctx.caster
		var ratio := 0.0
		if available and ctx.spell.deals_damage():
			match passive:
				"assassin":
					var isolated := true
					for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
						var neighbor = ctx.grid.get_unit(target.grid_pos + offset)
						if neighbor != null and neighbor.team == target.team:
							isolated = false
					if isolated and distance == 1:
						ratio = .2
				"arpenteur":
					if distance >= 3:
						ratio = .2
				"thaumaturge":
					if (marked or slowed) and ctx.spell.damage_type == Spell.DamageType.MAGICAL:
						ratio = .2
				"execution":
					if execute:
						ratio = .35
				"ambush":
					if moved and distance == 1:
						ratio = .3
				"stalker":
					if marked:
						ratio = .3
				"retaliation":
					if wounded:
						ratio = .3
				"breaker":
					if displaced:
						ratio = .35
				"sniper":
					if distance >= 4:
						ratio = .35
				"skirmish":
					if moved:
						ratio = .3
				"hunter":
					if slowed:
						ratio = .3
				"fire":
					if ctx.spell.element == Spell.Element.FIRE:
						ratio = .25
				"ice":
					if slowed and ctx.spell.damage_type == Spell.DamageType.MAGICAL:
						ratio = .35
				"area":
					if count >= 2:
						ratio = .25
		if ratio > 0:
			bonus += roundi(ctx.spell.get_scaled_damage(ctx.caster) * ratio)
			ctx.report["class_passive"] = true
		ctx.damage_bonus_by_cell[cell] = int(ctx.damage_bonus_by_cell.get(cell, 0)) + bonus


func on_cast_complete(ctx) -> void:
	if ctx.report.get("class_passive", false):
		ctx.caster.set_meta("ct_class_passive_turn", ctx.caster.activation_index)
