extends RefCounted
## Read-only presentation of one persisted level-up, including grouped levels.
const Rules := preload("res://core/expedition/consumable_progression_v1.gd")


static func read(cards, from_level: int) -> Dictionary:
	var level: int = cards.level
	var previous := clampi(from_level, 1, level)
	var before: Dictionary = Rules.profile().level_row(previous)
	var after: Dictionary = Rules.profile().level_row(level)
	return {
		"before": previous,
		"level": level,
		"gained": level - previous,
		"hp": int(after.hp) - int(before.hp),
		"power": int(after.power) - int(before.power),
		"elements_gained": Rules.element_budget(level) - Rules.element_budget(previous),
		"aptitudes_gained": Rules.aptitude_budget(level) - Rules.aptitude_budget(previous),
		"training_gained": Rules.training_slots(level) - Rules.training_slots(previous),
		"elements_left": maxi(0, Rules.element_budget(level) - Rules.spent(cards.masteries)),
		"aptitudes_left": maxi(0, Rules.aptitude_budget(level) - Rules.spent(cards.aptitudes)),
		"training_left": maxi(0, cards.points()),
		"specialization_required": level >= Rules.specialization_level()
		and cards.specialization.is_empty(),
	}
