@tool
class_name ConsumableCardItemDefinition
extends ItemDefinition
## A profile-owned item still participates in ItemCatalog, Studio identity,
## duplication and resource transactions. Legacy item effects are never attached.
@export var ruleset_id := "catabase_cards_consumable_v2"
@export var profile_modifiers: Dictionary = { }
@export var profile_relic_rule := ""


func is_valid() -> bool:
	if (
		ruleset_id != "catabase_cards_consumable_v2" or item_id == &""
		or display_name.is_empty() or stack_limit != 1
	):
		return false
	if (
		not stat_modifiers.is_empty() or not spell_modifiers.is_empty()
		or not reactive_effects.is_empty()
	):
		return false
	if category == Category.RELIC:
		return (
			equipment_slot == EquipmentSlot.NONE
			and profile_relic_rule
			in ["thread", "bronze", "seal", "cup", "mirror", "archive", "embers", "obole"]
			and profile_modifiers.is_empty()
		)
	if not profile_relic_rule.is_empty() or profile_modifiers.is_empty() or not super.is_valid():
		return false
	for key in profile_modifiers:
		if key not in [
			"melee",
			"ranged",
			"range",
			"mp",
			"hand",
			"hp",
			"armor",
			"magicResist",
			"guard",
			"damage",
			"magic",
			"healing",
			"openingShield",
			"firstHitReduction",
			"lifesteal",
		]:
			return false
		var value: Variant = profile_modifiers[key]
		if (
			not (value is int or value is float)
			or not is_finite(float(value)) or absf(float(value)) > 5
		):
			return false
	return true
