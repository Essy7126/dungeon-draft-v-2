extends RefCounted
## Prototype v1: shared allocation and component contracts, independent of UI.
const NAME := "Prototype v1"
const ELEMENTS := ["earth", "water", "fire", "wind", "night", "sun"]
const ELEMENT_NAMES := {
	"earth": "Terre",
	"water": "Eau",
	"fire": "Feu",
	"wind": "Vent",
	"night": "Nuit",
	"sun": "Soleil",
}
const APTITUDES := ["vitality", "protection", "contact", "distance"]
const APTITUDE_NAMES := {
	"vitality": "Vitalité",
	"protection": "Protection",
	"contact": "Contact",
	"distance": "Distance",
}
const Profile := preload("res://core/expedition/consumable_progression_profile.gd")
const PROFILE_PATH := "res://data/cards/consumable_v2/catalog.json"
const LEGACY_PROFILE_ID := "paris_act_1_v1" # Frozen migration identity, not the current campaign default.
static var _profile
# Compatibility for existing presentation/probes; each access is detached.
static var APTITUDE_GAINS: Dictionary:
	get:
		return profile().aptitude_gains()
static var POWER: Array:
	get:
		return profile().curve("power")
const HALTS := [4, 7, 9, 11, 14, 16, 18, 19]
const FULL_RESET_DEPTHS := [11, 16, 19]
const COMPONENTS := ["damage", "bonus", "amount", "counter", "shield", "collisionGuard"]


static func empty_elements() -> Dictionary:
	return { "earth": 0, "water": 0, "fire": 0, "wind": 0, "night": 0, "sun": 0 }


static func empty_aptitudes() -> Dictionary:
	return { "vitality": 0, "protection": 0, "contact": 0, "distance": 0 }


static func profile():
	if _profile == null:
		var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH))
		if not source is Dictionary or not source.get("rules") is Dictionary:
			push_error("Manifeste de progression absent.")
			return null
		_profile = Profile.from_rules(source.rules)
		if _profile == null:
			push_error(
				"Profil de progression invalide : "
				+ "; ".join(Profile.validation_errors(source.rules))
			)
	return _profile


static func level_cap() -> int:
	return profile().level_cap()


static func profile_id() -> String:
	return profile().id()


static func element_budget(level: int) -> int:
	return profile().element_budget(level)


static func aptitude_budget(level: int) -> int:
	return profile().aptitude_budget(level)


static func training_slots(level: int) -> int:
	return profile().training_slots(level)


static func element_point_cap() -> int:
	return element_budget(level_cap())


static func aptitude_rank_cap() -> int:
	return profile().aptitude_rank_cap()


static func specialization_level() -> int:
	return profile().specialization_level()


static func spent(values: Dictionary) -> int:
	var result := 0
	for value in values.values():
		result += int(value)
	return result


static func mastery(points: int) -> float:
	return profile().mastery(points)


static func valid_allocation(values: Variant, keys: Array, budget: int, cap: int) -> bool:
	if budget < 0 or cap < 0 or not values is Dictionary or values.size() != keys.size():
		return false
	var total := 0
	for key in keys:
		var value: Variant = values.get(key)
		if (
			not (value is int or value is float) or not is_finite(float(value))
			or value != floorf(value) or value < 0 or value > cap
		):
			return false
		total += int(value)
	return total <= budget


static func refunded(before: Dictionary, after: Dictionary) -> int:
	var total := 0
	for key in before:
		total += maxi(0, int(before[key]) - int(after.get(key, 0)))
	return total


static func elemental_bonus(
	card: Dictionary,
	component: String,
	cards,
	mods: Dictionary = { },
	selected_profile = null,
) -> float:
	if cards == null or cards.prototype_revision != 1:
		return 0.0
	var result := 0.0
	var numerical = profile() if selected_profile == null else selected_profile
	for element in card.get("elements", { }).get(component, { }):
		var weight := float(card.elements[component][element])
		result += weight * (
			numerical.mastery(int(cards.masteries.get(element, 0))) + float(
				mods.get("mastery_" + element, 0)
			)
		)
	return result


static func aptitude(cards, id: String, selected_profile = null) -> float:
	var numerical = profile() if selected_profile == null else selected_profile
	return (
		float(cards.aptitudes.get(id, 0)) * float(numerical.aptitude_gains().get(id, 0))
		if (cards != null and cards.prototype_revision == 1)
		else 0.0
	)


static func component_errors(card: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not card.get("elements") is Dictionary:
		return ["Composantes élémentaires absentes."]
	var amount_ops := ["guard", "counter", "mark", "burn", "bleed", "firefield", "heal", "renew"]
	for component in COMPONENTS:
		if component == "amount" and card.get("op") not in amount_ops:
			continue
		var forms := [card]
		if card.get("upgrade") is Dictionary:
			forms.append(card.upgrade)
		for form in forms:
			var value: Variant = form.get(component, 0)
			if (value is int or value is float) and value > 0 and not card.elements.has(component):
				errors.append("Composante chiffrée sans éléments : " + str(component))
	for component in card.elements:
		if component not in COMPONENTS or not card.elements[component] is Dictionary:
			errors.append("Composante élémentaire inconnue.")
			continue
		if component == "amount" and card.get("op") not in amount_ops:
			errors.append("Une quantité utilitaire ou dérivée ne peut pas être élémentaire.")
		var total := 0.0
		for element in card.elements[component]:
			var weight: Variant = card.elements[component][element]
			if (
				element not in ELEMENTS or not (weight is float or weight is int)
				or not is_finite(float(weight)) or weight <= 0 or weight > 1
			):
				errors.append("Poids élémentaire invalide.")
			else:
				total += float(weight)
		if not is_equal_approx(total, 1.0):
			errors.append("La somme des poids doit valoir 100 %.")
	return errors
