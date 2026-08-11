class_name RunStartingItemData
extends Resource

@export var item_id: StringName = &""
@export_range(1, 99, 1) var quantity := 1


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if item_id == &"":
		errors.append("Un objet initial doit posseder un item_id.")
	if quantity <= 0:
		errors.append("La quantite d'un objet initial doit etre positive.")
	return errors
