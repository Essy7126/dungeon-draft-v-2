@tool
class_name MerchantOfferData
extends Resource

enum OfferType {
	EQUIPMENT,
	RELIC,
	HEAL,
	FORGE,
	REROLL,
	REORIENTATION,
	CHIRON_LESSON,
}

@export var offer_id: StringName = &""
@export var display_name := "Offre"
@export_multiline var description := ""
@export var offer_type: OfferType = OfferType.EQUIPMENT
@export_range(0, 9999, 1) var currency_cost := 0
@export var item_id: StringName = &""
@export var catalog_tags: Array[StringName] = []
@export_range(0.0, 1.0, 0.01) var heal_max_hp_ratio := 0.0
@export_range(0, 10, 1) var mastery_amount := 0
@export_range(1, 99, 1) var per_run_limit := 1
@export_range(0, 99, 1) var reroll_offer_count := 0
@export_range(0, 99, 1) var forge_tier_delta := 0
@export_range(0, 99, 1) var reorientation_refund_limit := 0


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if offer_id == &"" or display_name.strip_edges().is_empty():
		errors.append("Une offre marchand doit avoir un identifiant et un nom.")
	if currency_cost < 0 or per_run_limit <= 0:
		errors.append("Coût ou limite invalide pour %s." % offer_id)
	match offer_type:
		OfferType.EQUIPMENT, OfferType.RELIC:
			if item_id == &"" and catalog_tags.is_empty():
				errors.append("L’offre %s doit référencer un objet ou un pool." % offer_id)
		OfferType.HEAL:
			if heal_max_hp_ratio <= 0.0:
				errors.append("L’offre de soin %s est invalide." % offer_id)
		OfferType.FORGE:
			if forge_tier_delta <= 0:
				errors.append("L’offre de forge %s est invalide." % offer_id)
		OfferType.REROLL:
			if reroll_offer_count <= 0:
				errors.append("L’offre de reroll %s est invalide." % offer_id)
		OfferType.REORIENTATION:
			if reorientation_refund_limit <= 0:
				errors.append("L’offre de réorientation %s est invalide." % offer_id)
		OfferType.CHIRON_LESSON:
			if mastery_amount != 1:
				errors.append("La Leçon de Chiron doit accorder exactement +1 maîtrise.")
	return errors


func is_valid() -> bool:
	return validation_errors().is_empty()
