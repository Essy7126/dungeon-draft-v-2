extends RefCounted
## Pure projections: inspecting gear must never equip it or rebuild the hero.
const Math := preload("res://core/expedition/consumable_card_math.gd")
const Presenter := preload("res://ui/expedition/consumable_cards_presenter.gd")
const METRICS := {
	"hp": "PV maximum",
	"power": "Puissance",
	"ap": "PA",
	"mp": "PM",
	"hand": "Taille de main",
	"physical": "Résistance physique",
	"magic": "Résistance magique",
	"guard": "Bonus de garde",
}
const STAT_MODS := ["hp", "mp", "hand", "armor", "magicResist", "guard"]


static func value(key: String, amount: float) -> String:
	if key in ["physical", "magic", "guard"]:
		return ("%.0f %%" % (amount * 100))
	if key == "power":
		return ("%.1f" % amount).replace(".", ",")
	return str(int(amount))


static func sources(cards) -> Array[Dictionary]:
	var base := Math.stats(cards.level, { }, { })
	var attributed := Math.stats(cards.level, cards.attributes, { })
	var final := Math.stats(cards.level, cards.attributes, Math.equipment_mods(cards.equipped))
	var result: Array[Dictionary] = []
	for key in METRICS:
		result.append(
			{
				"key": key,
				"title": METRICS[key],
				"base": base[key],
				"attributes": float(attributed[key]) - float(base[key]),
				"equipment": float(final[key]) - float(attributed[key]),
				"total": final[key],
			}
		)
	return result


static func compare(cards, id: String) -> Dictionary:
	var item := Presenter.item(id)
	if not item.has("slot"):
		return { }
	var next: Dictionary = cards.equipped.duplicate()
	var removing := str(next.get(item.slot, "")) == id
	if removing:
		next.erase(item.slot)
	else:
		next[item.slot] = id
	var before_mods := Math.equipment_mods(cards.equipped)
	var after_mods := Math.equipment_mods(next)
	var before := Math.stats(cards.level, cards.attributes, before_mods)
	var after := Math.stats(cards.level, cards.attributes, after_mods)
	var rows: Array[Dictionary] = []
	for key in METRICS:
		if not is_equal_approx(float(before[key]), float(after[key])):
			rows.append(
				{ "key": key, "title": METRICS[key], "before": before[key], "after": after[key] }
			)
	var effects: Array[Dictionary] = []
	var keys := before_mods.keys()
	for key in after_mods:
		if key not in keys:
			keys.append(key)
	for key in keys:
		if key in STAT_MODS:
			continue
		var old := float(before_mods.get(key, 0))
		var current := float(after_mods.get(key, 0))
		if not is_equal_approx(old, current):
			effects.append({ "key": key, "before": old, "after": current })
	var caps: PackedStringArray = []
	for spec in [
		["physical", "armor", .4],
		["magic", "magicResist", .4],
		["mp", "mp", 5.0],
		["hand", "hand", 7.0],
	]:
		var key: String = spec[0]
		var raw := float(after_mods.get(spec[1], 0))
		if key == "physical":
			raw += .02 * int(cards.attributes.get("resolve", 0))
		elif key == "mp":
			raw += 3
		elif key == "hand":
			raw += 5
		if raw >= float(spec[2]):
			caps.append(
				"%s : plafond %s%s"
				% [
					METRICS[key],
					value(key, spec[2]),
					(
						" · excédent sans effet " + value(key, raw - float(spec[2]))
						if raw > float(spec[2]) + .00001
						else " atteint"
					),
				]
			)
	return { "removing": removing, "rows": rows, "effects": effects, "caps": caps }
