extends RefCounted
## Validated numerical contract. Route rewards and act transitions are separate.
## Construct through from_rules(); inputs and returned rows are detached.
const APTITUDES := ["vitality", "protection", "contact", "distance"]
const MAX_INTEGER := 2147483647
var _rules: Dictionary = { }
var _progression: Dictionary = { }


static func from_rules(source: Dictionary):
	if not validation_errors(source).is_empty():
		return null
	var instance = new()
	instance._rules = source.duplicate(true)
	instance._progression = instance._rules.prototypeProgression
	return instance


static func validation_errors(source: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var definition: Variant = source.get("prototypeProgression")
	if not definition is Dictionary:
		return ["Profil de progression absent."]
	if not _integer(definition.get("schemaVersion"), 1, 1):
		errors.append("Version du contrat de progression inconnue.")
	if not definition.get("id") is String or str(definition.id).strip_edges().is_empty():
		errors.append("Identité du profil de progression absente.")
	var cap: Variant = definition.get("levelCap")
	if not _integer(cap, 1, 99):
		return errors + ["Plafond de niveau invalide (1 à 99)."]
	for key in ["hp", "prowess", "xpThresholds"]:
		_check_curve(source.get(key), int(cap), key, key == "xpThresholds", errors)
	_check_curve(definition.get("power"), int(cap), "power", false, errors)
	for key in ["initialElementPoints", "elementPointsPerLevel"]:
		if not _integer(definition.get(key), 0, MAX_INTEGER / int(cap)):
			errors.append("Budget entier invalide : " + key)
	if not _integer(definition.get("aptitudeRankCap"), 1, MAX_INTEGER):
		errors.append("Plafond de rang d'aptitude invalide.")
	if not _integer(definition.get("specializationLevel"), 1, int(cap)):
		errors.append("Niveau de spécialisation hors profil.")
	_check_milestones(definition.get("aptitudeLevels"), int(cap), "aptitudeLevels", errors)
	_check_milestones(source.get("trainingLevels"), int(cap), "trainingLevels", errors)
	var gains: Variant = definition.get("aptitudeGains")
	if not gains is Dictionary or gains.size() != APTITUDES.size():
		errors.append("Gains d'aptitude incomplets.")
	else:
		for key in APTITUDES:
			if not _gain(gains.get(key)):
				errors.append("Gain d'aptitude invalide : " + key)
	var bands: Variant = definition.get("masteryBands")
	if not bands is Array or bands.is_empty():
		errors.append("Paliers de maîtrise absents.")
	else:
		var previous := 0
		for index in bands.size():
			var band: Variant = bands[index]
			if (
				not band is Dictionary or not _integer(band.get("upTo"), 0, MAX_INTEGER)
				or not _gain(band.get("gain"))
			):
				errors.append("Palier de maîtrise invalide.")
				continue
			var end := int(band.upTo)
			if (
				(index == bands.size() - 1 and end != 0)
				or (index < bands.size() - 1 and end <= previous)
			):
				errors.append("Paliers ordonnés, puis un dernier palier ouvert, requis.")
			previous = end
	return errors


static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (
		(value is int or value is float) and is_finite(float(value))
		and value == floorf(value) and value >= minimum and value <= maximum
	)


static func _gain(value: Variant) -> bool:
	return (
		(value is int or value is float) and is_finite(float(value)) and value >= 0 and value <= 1
	)


static func _check_curve(
	value: Variant,
	cap: int,
	label: String,
	xp: bool,
	errors: Array[String],
) -> void:
	if not value is Array or value.size() != cap:
		errors.append("Courbe complète requise : " + label)
		return
	var previous := -1
	for index in value.size():
		if not _integer(value[index], 0 if xp else 1, MAX_INTEGER):
			errors.append("Valeur entière invalide : " + label)
			continue
		var current := int(value[index])
		if xp and ((index == 0 and current != 0) or current <= previous):
			errors.append("Seuils XP strictement croissants à partir de zéro requis.")
		previous = current


static func _check_milestones(
	value: Variant,
	cap: int,
	label: String,
	errors: Array[String],
) -> void:
	if not value is Array:
		errors.append("Paliers absents : " + label)
		return
	var previous := 1
	for level in value:
		if not _integer(level, 2, cap) or int(level) <= previous:
			errors.append("Paliers uniques, ordonnés et dans le profil requis : " + label)
		else:
			previous = int(level)


func id() -> String:
	return str(_progression.id)


func level_cap() -> int:
	return int(_progression.levelCap)


func contains_level(level: int) -> bool:
	return level >= 1 and level <= level_cap()


## An absent level is rejected, never replaced with the last published row.
func level_row(level: int) -> Dictionary:
	if not contains_level(level):
		return { }
	return {
		"level": level,
		"hp": int(_rules.hp[level - 1]),
		"power": int(_progression.power[level - 1]),
		"legacy_power": int(_rules.prowess[level - 1]),
		"xp_threshold": int(_rules.xpThresholds[level - 1]),
		"element_points": element_budget(level),
		"aptitude_points": aptitude_budget(level),
		"training_slots": training_slots(level),
	}


func curve(key: String) -> Array:
	if key == "power":
		return _progression.power.duplicate()
	if key in ["hp", "prowess", "xpThresholds"]:
		return _rules[key].duplicate()
	return []


## -1 distinguishes an invalid level from a valid level with no rewards.
func element_budget(level: int) -> int:
	return (
		int(_progression.initialElementPoints) + int(_progression.elementPointsPerLevel) * (
			level - 1
		)
		if contains_level(level)
		else -1
	)


func aptitude_budget(level: int) -> int:
	return _milestones(_progression.aptitudeLevels, level)


func training_slots(level: int) -> int:
	return _milestones(_rules.trainingLevels, level)


func _milestones(levels: Array, level: int) -> int:
	if not contains_level(level):
		return -1
	var count := 0
	for milestone in levels:
		if level >= milestone:
			count += 1
	return count


func aptitude_rank_cap() -> int:
	return int(_progression.aptitudeRankCap)


func specialization_level() -> int:
	return int(_progression.specializationLevel)


func aptitude_gains() -> Dictionary:
	return _progression.aptitudeGains.duplicate()


func mastery(points: int) -> float:
	var result := 0.0
	var previous := 0
	for band in _progression.masteryBands:
		var end := points if int(band.upTo) == 0 else mini(points, int(band.upTo))
		result += maxi(0, end - previous) * float(band.gain)
		previous = end
		if end >= points:
			break
	return result
