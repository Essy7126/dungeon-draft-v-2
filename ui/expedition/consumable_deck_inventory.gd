extends RefCounted
## Read-only partition. A copy belongs to exactly one destination.
const Catalog := preload("res://core/expedition/consumable_card_catalog.gd")


static func partition(copies: Array, active: Array) -> Dictionary:
	var result := { "deck": { }, "reserve": { }, "costs": { }, "deck_count": 0, "reserve_count": 0 }
	for copy in copies:
		var in_deck: bool = copy.id in active
		var lane: String = "deck" if in_deck else "reserve"
		var id := str(copy.family)
		if not result[lane].has(id):
			result[lane][id] = []
		result[lane][id].append(str(copy.id))
		result[lane + "_count"] += 1
		if in_deck:
			var cost := int(Catalog.card(id).ap)
			result.costs[cost] = int(result.costs.get(cost, 0)) + 1
	return result


static func affinity(row: Dictionary) -> String:
	return "Commune" if row.affinity == "shared" else str(Catalog.class_row(row.affinity).name)


static func cost_summary(costs: Dictionary) -> String:
	var keys := costs.keys()
	keys.sort()
	var parts: PackedStringArray = []
	for key in keys:
		parts.append("%d PA × %d" % [key, costs[key]])
	return " · ".join(parts) if not parts.is_empty() else "Ajoutez des cartes depuis la réserve."
