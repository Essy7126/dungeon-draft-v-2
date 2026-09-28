extends RefCounted
## Read-only summaries from the same definitions as the run.
const Catalog := preload("res://core/expedition/consumable_card_catalog.gd")
const Math := preload("res://core/expedition/consumable_card_math.gd")


static func stats_text() -> String:
	var stats := Math.stats(1, { }, { })
	return "%d PV · %d PA · %d PM · Puissance %s" % [
		stats.hp,
		stats.ap,
		stats.mp,
		String.num(stats.power).replace(".", ","),
	]


static func power_help() -> String:
	var stats := Math.stats(1, { }, { })
	var power_text := String.num(stats.power).replace(".", ",")
	return "P = votre puissance (%s au départ). 0,5 P représente %d avant résistances et bonus conditionnels." % [
		power_text,
		Math.rounded(.5 * stats.power),
	]


static func category(id: String) -> String:
	var row := Catalog.card(id)
	if row.affinity == "shared":
		return "Commune · toutes classes"
	var class_row := Catalog.class_row(row.affinity)
	return str(class_row.name) + " · carte de classe"


static func counts(families: Array) -> Dictionary:
	var result := { }
	for id in families:
		result[id] = int(result.get(id, 0)) + 1
	return result


static func deck_text(families: Array) -> String:
	var costs := { }
	for id in families:
		var ap := int(Catalog.card(id).ap)
		costs[ap] = int(costs.get(ap, 0)) + 1
	var keys := costs.keys()
	keys.sort()
	var parts: PackedStringArray = []
	for ap in keys:
		parts.append("%d à %d PA" % [costs[ap], ap])
	var family_counts := counts(families)
	var cost_text := " · ".join(parts) if not parts.is_empty() else "deck vide"
	return "%d copies · %d familles\nCoûts : %s" % [
		families.size(),
		family_counts.size(),
		cost_text,
	]
