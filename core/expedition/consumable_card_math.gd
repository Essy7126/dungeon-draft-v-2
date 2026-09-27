extends RefCounted


## All factors stay real until the final payload. Preview and execution share this.
static func rounded(value: float) -> int:
	return maxi(0, floori(value + 0.5))


static func damage(raw: float, resistance: float, pierce := false, parry := 0.0) -> int:
	return rounded(maxf(0.0, raw - parry) * (1.0 if pierce else 1.0 - clampf(resistance, 0.0, 0.4)))


static func guard(power: float, coefficient: float, bonus: float, current: int) -> int:
	return mini(
		maxi(0, rounded(2.5 * power) - current),
		rounded(power * coefficient * (1.0 + bonus)),
	)


static func stats(level: int, attributes: Dictionary, equipment: Dictionary) -> Dictionary:
	var rules: Dictionary = preload("res://core/expedition/consumable_card_catalog.gd").data().rules
	var index := clampi(level - 1, 0, 11)
	return {
		"hp": rounded(
			float(rules.hp[index])
			* (1.0 + .06 * int(attributes.get("vitality", 0)) + float(equipment.get("hp", 0)))
		),
		"power": float(rules.prowess[index]) * (1.0 + .05 * int(attributes.get("power", 0))),
		"ap": 4,
		"mp": clampi(3 + int(equipment.get("mp", 0)), 1, 5),
		"hand": clampi(5 + int(equipment.get("hand", 0)), 1, 7),
		"physical": clampf(
			.02 * int(attributes.get("resolve", 0)) + float(equipment.get("armor", 0)),
			0.0,
			.4,
		),
		"magic": clampf(float(equipment.get("magicResist", 0)), 0.0, .4),
		"guard": .05 * int(attributes.get("resolve", 0)) + float(equipment.get("guard", 0)),
	}


static func equipment_mods(equipped: Dictionary) -> Dictionary:
	var result := { }
	var catalog := preload("res://core/expedition/consumable_cards_content.gd").items()
	if catalog == null:
		return result
	for id in equipped.values():
		var item := catalog.get_definition(StringName("cc2_" + str(id))) as ConsumableCardItemDefinition
		if item == null:
			continue
		for key in item.profile_modifiers:
			result[key] = float(result.get(key, 0.0)) + float(item.profile_modifiers[key])
	return result


static func pressure(max_hp: int, round_index: int) -> int:
	return rounded(max_hp * .025 * maxi(0, round_index - 8))


static func impact(
	card: Dictionary,
	power: float,
	facts: Dictionary,
	equipment: Dictionary,
	class_id: String,
	spec: String,
	triggers: Dictionary,
) -> Dictionary:
	var raw := power * float(card.get("damage", 0))
	var consumed_triggers: Array[String] = []
	var condition: String = card.get("condition", "")
	var applies := false
	match condition:
		"marked":
			applies = float(facts.get("mark", 0)) > 0
		"moved":
			applies = int(facts.get("moved", 0)) >= int(card.get("movementThreshold", 2))
		"execute":
			applies = bool(facts.get("execute", false))
		"guarded":
			applies = int(facts.get("guard", 0)) > 0
		"absorbed":
			applies = int(facts.get("absorbed", 0)) > 0
	if applies:
		raw += power * float(card.get("bonus", 0))
	if card.op == "guardburst":
		raw += 1.5 * int(facts.get("sacrifice", 0))
	var bonus := float(equipment.get("damage", 0))
	var distance := int(facts.get("distance", 0))
	if distance == 1:
		bonus += float(equipment.get("melee", 0))
	if distance >= 3:
		bonus += float(equipment.get("ranged", 0))
	if card.type == "magic":
		bonus += float(equipment.get("magic", 0))
	if not bool(card.get("fallback", false)):
		raw *= 1.0 + bonus
	if not bool(card.get("fallback", false)):
		if (
			class_id == "assassin" and not triggers.get("class", false)
			and facts.get("isolated", false)
		):
			raw += .25 * power
			consumed_triggers.append("class")
		if (
			not triggers.get("spec", false)
			and (
				(spec == "execution" and facts.get("execute", false))
				or (spec == "sniper" and distance >= 4)
			)
		):
			raw += (.30 if spec == "execution" else .25) * power
			consumed_triggers.append("spec")
		raw += float(facts.get("mark", 0))
	return { "raw": raw, "triggers": consumed_triggers }
