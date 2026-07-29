class_name SpellModCollisionDamage
extends SpellModifier

@export_range(0, 999) var bonus_damage: int = 0
# Valeur negative : additionne bonus_damage. Valeur >= 0 : impose le total.
@export_range(-1, 999) var exact_total_damage: int = -1


func on_targets_resolved(ctx) -> void:
	if exact_total_damage >= 0:
		ctx.collision_damage_override = exact_total_damage
	else:
		ctx.collision_damage_bonus += bonus_damage


func on_movement_resolved(ctx) -> void:
	if ctx == null or ctx.collision_damage_resolved:
		return
	ctx.collision_damage_resolved = true
	var amount: int = (
		ctx.collision_damage_override
		if ctx.collision_damage_override >= 0
		else ctx.collision_damage_bonus
	)
	if amount <= 0 or ctx.caster == null:
		return
	var victims: Array[Unit] = []
	for movement_value in ctx.movement:
		var movement_entry := movement_value as Dictionary
		if not bool(movement_entry.get("collision", false)):
			continue
		var collision_units: Array = movement_entry.get("collision_units", [])
		if collision_units.is_empty():
			collision_units = [movement_entry.get("unit")]
		for victim_value in collision_units:
			var victim := victim_value as Unit
			if victim != null \
					and victim.team != ctx.caster.team \
					and not victims.has(victim):
				victims.append(victim)
	for victim in victims:
		if not victim.is_alive:
			continue
		var result = victim.take_damage(
			amount,
			ctx.caster,
			Spell.DamageType.PHYSICAL,
			Spell.Element.NONE
		)
		if result == null:
			continue
		if not ctx.report["affected_units"].has(victim):
			ctx.report["affected_units"].append(victim)
		if result.amount > 0 and not ctx.report["damaged_enemies"].has(victim):
			ctx.report["damaged_enemies"].append(victim)
