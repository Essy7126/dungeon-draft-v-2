extends RefCounted
## Read-only projection of the same stats used by combat. No copied unit or modifiers.
const STATS := [
	["max_hp", "Vitalité maximale", "Ressources", "number"],
	["max_ap", "PA par tour", "Ressources", "number"],
	["max_mp", "PM par tour", "Ressources", "number"],
	["initiative", "Initiative", "Ressources", "number"],
	["attack_power", "Prouesse", "Attaque et placement", "number"],
	["force", "Force de déplacement", "Attaque et placement", "number"],
	["crit_chance", "Chance de critique", "Attaque et placement", "percent"],
	["crit_multi", "Multiplicateur critique", "Attaque et placement", "multiplier"],
	["armure", "Armure physique", "Défenses", "number"],
	["resist_magique", "Défense magique", "Défenses", "number"],
	["esquive", "Esquive", "Défenses", "percent"],
]
const ELEMENTS := {Spell.Element.FIRE: "Feu", Spell.Element.ICE: "Glace", Spell.Element.LIGHTNING: "Foudre", Spell.Element.SHADOW: "Ombre", Spell.Element.HOLY: "Sacré", Spell.Element.EARTH: "Terre"}


static func rows(unit: Unit) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for spec in STATS:
		result.append(_row(spec[0], spec[1], spec[2], spec[3], unit.get(spec[0]) as Stat))
	for element in ELEMENTS:
		result.append(_row("resistance_%d" % element, ELEMENTS[element], "Résistances élémentaires", "percent", unit.resistances.get(element) as Stat))
	return result


static func _row(id: String, title: String, group: String, mode: String, stat: Stat) -> Dictionary:
	var flat := 0.0
	var percent := 0.0
	var sources := PackedStringArray()
	if stat != null:
		for modifier in stat.get_modifiers():
			if modifier.type == Stat.ModType.FLAT: flat += float(modifier.value)
			else: percent += float(modifier.value)
			var origin := "Effet temporaire" if int(modifier.duration) >= 0 else "Bonus permanent"
			if str(modifier.source).contains("equipment"): origin = "Équipement"
			elif str(modifier.source).contains("champion"): origin = "Caractéristiques"
			elif str(modifier.source).contains("expedition"): origin = "Construction"
			var value := "%+.1f %%" % (float(modifier.value) * 100.0) if modifier.type == Stat.ModType.PERCENT else _signed(float(modifier.value), mode)
			sources.append(origin + " : " + value + (" · %d tour(s)" % int(modifier.duration) if int(modifier.duration) >= 0 else ""))
	var bonus := _signed(flat, mode)
	if not is_zero_approx(percent): bonus += " / %+.1f %%" % (percent * 100.0)
	var detail := "\n".join(sources) if not sources.is_empty() else "Aucun modificateur."
	if stat != null and (not is_nan(stat.min_value) or not is_nan(stat.max_value)):
		detail += "\nLe total respecte les limites de cette statistique."
	return {"id": id, "title": title, "group": group, "base": _format(stat.base_value if stat != null else 0.0, mode), "bonus": bonus, "total": _format(stat.get_value() if stat != null else 0.0, mode), "detail": detail}


static func _signed(value: float, mode: String) -> String:
	return ("+" if value >= 0 else "") + _format(value, mode)


static func _format(value: float, mode: String) -> String:
	if mode == "percent": return "%.1f %%" % (value * 100.0)
	if mode == "multiplier": return "%.2f ×" % value
	return str(roundi(value))
