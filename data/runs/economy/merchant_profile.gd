@tool
class_name MerchantProfile
extends Resource

@export var schema_version := 1
@export var merchant_id: StringName = &""
@export var display_name := "Marchand"
@export_range(0, 99, 1) var maximum_mastery_purchases_per_run := 3
@export var offers: Array[MerchantOfferData] = []


func get_offer(offer_id: StringName) -> MerchantOfferData:
	for offer in offers:
		if offer != null and offer.offer_id == offer_id:
			return offer
	return null


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if schema_version <= 0 or merchant_id == &"":
		errors.append("Le profil marchand doit avoir un schéma et un identifiant.")
	if display_name.strip_edges().is_empty():
		errors.append("Le profil marchand doit avoir un nom.")
	if maximum_mastery_purchases_per_run > 3:
		errors.append("La Leçon de Chiron est limitée à trois achats par run.")
	var ids := {}
	for offer in offers:
		if offer == null:
			errors.append("Une offre marchand est absente.")
			continue
		errors.append_array(offer.validation_errors())
		if ids.has(offer.offer_id):
			errors.append("Offre dupliquée : %s." % offer.offer_id)
		ids[offer.offer_id] = true
	return errors


func is_valid() -> bool:
	return validation_errors().is_empty()
