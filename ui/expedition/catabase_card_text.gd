extends RefCounted
## Read-only presentation. No prediction claims after target mitigation.

static func reason_text(reason: StringName, actor: Unit, spell: Spell) -> String:
	match reason:
		&"": return ""
		&"pa": return "PA insuffisants : %d / %d." % [actor.current_ap, actor.get_spell_ap_cost(spell)]
		&"cooldown": return "Recharge : %d activation(s)." % actor.get_spell_cooldown_remaining(spell)
		&"max_uses": return "Usages de cette famille épuisés pour ce combat."
		&"once_per_activation": return "Famille déjà jouée ce tour."
		&"card_not_in_hand": return "Aucune copie en main."
		&"caster_dead": return "Personnage hors combat."
		&"combat_form": return "Forme de combat requise."
	return str(reason)


static func effect(spell: Spell, actor: Unit) -> String:
	var parts: Array[String] = ["%d PA" % actor.get_spell_ap_cost(spell)]
	var damage := spell.get_scaled_damage(actor)
	if str(spell.spell_id).begins_with("exp_ct_repercussion"):
		damage = roundi(1.5 * mini(int(actor.get_meta("ct_bronze", 0)), CatabaseCombatModifier.bronze_spend_cap(actor)))
	if damage > 0: parts.append("%d dégâts bruts" % damage)
	var shield := spell.get_scaled_shield(actor)
	if shield > 0: parts.append("%d garde" % shield)
	var heal := spell.get_scaled_heal(actor)
	if heal > 0: parts.append("%d soin de base" % heal)
	parts.append("sur soi" if spell.spell_range == 0 else "portée de base %d" % spell.spell_range)
	return " · ".join(parts)


static func details(spell: Spell, actor: Unit) -> String:
	return "%s\n%s\n%s\nLes dégâts affichés sont avant défenses et effets conditionnels. Une carte = une action ; usages partagés entre copies." % [spell.spell_name, effect(spell, actor), spell.description]
