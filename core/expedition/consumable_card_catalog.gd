extends RefCounted
## Versioned V2 definitions. Callers receive detached data, never shared mutable rows.
const PATH := "res://data/cards/consumable_v2/catalog.json"
const RULESET := "catabase_cards_consumable_v2"
const RARITIES := ["normal", "elite", "rare", "legendary", "god", "immortal"]
const CLASSES := ["assassin", "gardien", "arpenteur", "thaumaturge"]
const OPS := [
	"hit",
	"guard",
	"move",
	"push",
	"mark",
	"slow",
	"draw",
	"bleed",
	"pull",
	"burn",
	"blink",
	"counter",
	"firefield",
	"icefield",
	"drain",
	"disrupt",
	"stasis",
	"guardburst",
	"swap",
	"converge",
	"storm",
	"heal",
	"edict",
	"renew",
]
static var _data: Dictionary = { }


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		var errors := validation_errors(parsed)
		if not errors.is_empty():
			push_error("Cartes V2 : " + "; ".join(errors))
			return { }
		_data = parsed
	return _data.duplicate(true)


static func validation_errors(value: Variant) -> Array[String]:
	var errors: Array[String] = []
	if not value is Dictionary:
		return ["Catalogue absent ou JSON invalide."]
	for key in ["rules", "specs", "enemyTypes", "maps", "meta"]:
		if not value.get(key) is Dictionary:
			errors.append("Dictionnaire absent : " + key)
	for key in ["classes", "cards", "equipment", "relics", "route"]:
		if not value.get(key) is Array:
			errors.append("Collection absente : " + key)
	if not errors.is_empty():
		return errors
	if value.rules.get("rulesetId") != RULESET or value.meta.get("id") != RULESET:
		errors.append("Profil incompatible.")
	for key in ["hp", "prowess", "xp", "xpThresholds"]:
		var curve: Variant = value.rules.get(key)
		if not curve is Array or curve.size() != 12:
			errors.append("Courbe invalide : " + key)
		elif not curve.all(
			func(n):
				return (n is float or n is int) and is_finite(float(n)) and n >= 0,
		):
			errors.append("Valeur de courbe invalide : " + key)
	var counts := { "classes": 4, "cards": 48, "equipment": 18, "relics": 8, "route": 12 }
	for key in counts:
		if value[key].size() != counts[key]:
			errors.append("Nombre incorrect : " + key)
	var families := { }
	for card in value.cards:
		if not card is Dictionary or not card.get("id") is String:
			errors.append("Définition de carte invalide.")
			continue
		var id: String = card.id
		if families.has(id) or card.get("runtimeId") != "cc2_" + id:
			errors.append("Identifiant de carte invalide : " + id)
		families[id] = card
		if (
			card.get("op") not in OPS or card.get("rarity") not in RARITIES
			or card.get("affinity") not in CLASSES + ["shared"]
		):
			errors.append("Effet, rareté ou affinité inconnue : " + id)
		if (
			card.get("shape") not in ["single", "cross", "radius2", "line3_perpendicular"]
			or card.get("type") not in ["physical", "magic"]
		):
			errors.append("Géométrie ou type inconnu : " + id)
		for key in ["ap", "min", "max", "damage", "amount"]:
			var n: Variant = card.get(key)
			if not (n is float or n is int) or not is_finite(float(n)) or float(n) < 0:
				errors.append("Valeur invalide : " + id + "." + key)
		if not card.get("upgrade") is Dictionary:
			errors.append("Amélioration absente : " + id)
		if (
			float(card.get("min", 0)) > float(card.get("max", 0))
			or int(card.get("ap", 0)) not in [1, 2, 3, 4]
		):
			errors.append("Coût ou portée invalide : " + id)
	var seen_classes := { }
	var seen_specs := { }
	for entry in value.classes:
		if (
			not entry is Dictionary or entry.get("id") not in CLASSES
			or seen_classes.has(entry.get("id"))
		):
			errors.append("Classe invalide ou dupliquée.")
			continue
		seen_classes[entry.id] = true
		if (
			not entry.get("specs") is Array or entry.specs.size() != 2
			or not entry.get("starters") is Array or entry.starters.size() != 5
		):
			errors.append("Spécialisations ou départ invalides : " + str(entry.id))
			continue
		for spec in entry.specs:
			if not value.specs.has(spec) or seen_specs.has(spec):
				errors.append("Spécialisation invalide : " + str(spec))
			seen_specs[spec] = true
		for id in entry.starters:
			if (
				not families.has(id) or families[id].rarity != "normal"
				or families[id].affinity not in [entry.id, "shared"]
			):
				errors.append("Départ invalide : " + str(id))
	for key in ["equipment", "relics"]:
		var seen := { }
		for item in value[key]:
			if (
				not item is Dictionary or not item.get("id") is String
				or seen.has(item.get("id"))
				or not (item.get("price") is float or item.get("price") is int) or float(item.price)
				< 0
			):
				errors.append("Objet invalide : " + key)
				continue
			seen[item.id] = true
			if (
				key == "equipment"
				and (
					item.get("slot") not in ["weapon", "body", "head", "feet", "belt", "amulet"]
					or not item.get("mods") is Dictionary
				)
			):
				errors.append("Emplacement invalide : " + str(item.id))
	var previous_depth := 0
	for index in value.route.size():
		var encounter: Variant = value.route[index]
		if (
			not encounter is Dictionary or int(encounter.get("index", 0)) != index + 1
			or int(encounter.get("level", 0)) != index + 1
			or int(encounter.get("depth", 0)) <= previous_depth
			or not value.maps.has(encounter.get("map")) or not encounter.get("roster") is Array
		):
			errors.append("Rencontre invalide : " + str(index))
			continue
		previous_depth = int(encounter.depth)
		for enemy in encounter.roster:
			if not value.enemyTypes.has(enemy):
				errors.append("Ennemi inconnu : " + str(enemy))
	return errors


static func card(id: String, upgraded := false) -> Dictionary:
	var logical := id.trim_prefix("cc2_")
	for row in data().get("cards", []):
		if row.id == logical:
			var result: Dictionary = row.duplicate(true)
			if upgraded:
				result.merge(row.upgrade, true)
			return result
	return { }


static func class_row(id: String) -> Dictionary:
	for row in data().get("classes", []):
		if row.id == id:
			return row
	return { }


static func pool(class_id := "", rarity_id := "", native_only := false) -> Array[String]:
	var result: Array[String] = []
	for row in data().get("cards", []):
		if not rarity_id.is_empty() and row.rarity != rarity_id:
			continue
		if native_only and row.affinity not in ["shared", class_id]:
			continue
		result.append(str(row.id))
	return result


static func preset(class_id := "assassin") -> Dictionary:
	var row := class_row(class_id)
	if row.is_empty():
		return { }
	var families: Array[String] = []
	for family in row.starters:
		for _copy in 3:
			families.append(str(family))
	return {
		"ruleset_id": RULESET,
		"class_id": class_id,
		"card_families": families,
		"difficulty_id": "normal",
	}


static func valid_departure(selection: Dictionary) -> bool:
	if (
		selection.get("ruleset_id") != RULESET or selection.get("class_id") not in CLASSES
		or selection.get("difficulty_id") not in ["normal", "easy", "standard_v2"]
	):
		return false
	var families: Variant = selection.get("card_families")
	if not families is Array or families.size() != 15:
		return false
	var legal := pool(selection.class_id, "normal", true)
	var counts := { }
	for family in families:
		if not family is String or family not in legal:
			return false
		counts[family] = int(counts.get(family, 0)) + 1
		if counts[family] > 3:
			return false
	return true
