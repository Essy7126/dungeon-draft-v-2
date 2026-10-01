extends RefCounted
## Base effects from the prepared deck only; explicit distance, no target conditions.
const Catalog := preload("res://core/expedition/consumable_card_catalog.gd")
const Math := preload("res://core/expedition/consumable_card_math.gd")


static func rows(cards, candidate) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen := { }
	for uid in cards.active:
		var family: String = str(cards.copy_for(uid).get("family", ""))
		if family.is_empty() or seen.has(family):
			continue
		seen[family] = true
		var card := Catalog.card(family, family in cards.upgraded_ids)
		for component in ["damage", "amount"]:
			if not card.get("elements", { }).has(component):
				continue
			var kind := "direct" if component == "damage" else "periodic"
			var caption := "Dégâts" if component == "damage" else "Dégâts par déclenchement"
			if component == "amount":
				if card.op in ["guard", "counter"]:
					kind = "guard"
					caption = "Garde"
				elif card.op in ["heal", "renew"]:
					kind = "heal"
					caption = "Soin"
				elif card.op == "mark":
					kind = "mark"
					caption = "Marque"
			var distances: Array[int] = [0]
			if kind == "direct":
				distances.clear()
				for distance in [1, 2, maxi(3, int(card.min))]:
					if distance >= int(card.min) and distance <= int(card.max):
						distances.append(distance)
			for distance in distances:
				var values: Array[int] = []
				for state in [cards, candidate]:
					var stats := Math.stats(
						state.level,
						state.attributes,
						Math.equipment_mods(state.equipped),
						state,
					)
					var basis: float = stats.hp if component == "amount" and card.op == "renew" else stats.power
					values.append(
						Math.rounded(
							Math.component(
								card,
								component,
								basis,
								state,
								kind,
								0.0,
								{ "distance": distance },
							)
						)
					)
				result.append(
					{
						"family": family,
						"name": card.name,
						"caption": caption,
						"distance": distance,
						"before": values[0],
						"after": values[1],
						"changed": values[0] != values[1],
					}
				)
	# Stable partition: changed effects first, retaining deck order within each group.
	var changed: Array[Dictionary] = []
	var unchanged: Array[Dictionary] = []
	for row in result:
		if row.changed:
			changed.append(row)
		else:
			unchanged.append(row)
	changed.append_array(unchanged)
	return changed
