extends SpellModifier
## Native targeting, animations, status and support; shared Cartes damage policy.
const Effects := preload("res://core/expedition/consumable_card_effects.gd")
const Math := preload("res://core/expedition/consumable_card_math.gd")


func get_delayed_damage_options(caster, spell, target) -> Dictionary:
	return impact_options(caster, target, spell, spell.get_scaled_damage(caster))


func on_targets_resolved(ctx) -> void:
	if not ctx.spell.deals_damage():
		return
	for cell in ctx.affected_cells:
		var target: Unit = ctx.grid.get_unit(cell)
		if target == null or target.team == ctx.caster.team:
			continue
		var raw: float = ctx.spell.get_scaled_damage(ctx.caster)
		var linked: bool = ctx.caster.target_has_linked_source_status(
			target,
			ctx.spell.bonus_damage_status_id,
		)
		if ctx.spell.bonus_requires_linked_status_source and linked:
			raw += ctx.spell.bonus_damage_if_marked
		ctx.impact_options_by_unit[target] = impact_options(ctx.caster, target, ctx.spell, raw)


static func impact_options(caster: Unit, target: Unit, spell: Spell, raw: float) -> Dictionary:
	var states := Effects.states(caster)
	if states.has("weak"):
		raw *= 1.0 - float(states.weak.amount)
		states.erase("weak")
	var result := {
		"damage_ruleset": Effects.ID,
		"raw_payload": raw,
		"attack_classification": &"cc2_attack",
		"ability_id": spell.get_effective_spell_id(),
	}
	var cards = CatabaseCards.for_actor(target)
	if cards != null and cards.take_trigger("first_received", true):
		var resistance := target.resist_magique.get_value()
		if spell.damage_type == Spell.DamageType.PHYSICAL:
			resistance = target.armure.get_value()
		var fraction := float(Math.equipment_mods(cards.equipped).get("firstHitReduction", 0))
		var reduction := fraction * target.attack_power.get_value()
		result.raw_payload = maxf(0, raw * (1.0 - clampf(resistance / 100.0, 0, 0.4)) - reduction)
		result.ignore_defense = true
	return result
