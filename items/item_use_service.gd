class_name ItemUseService
extends RefCounted

var _catalog: ItemCatalog = null


func initialize(catalog: ItemCatalog) -> bool:
	_catalog = catalog
	return _catalog != null and _catalog.rebuild_index()


func use_item(
		inventory: RunInventory,
		state: CharacterRunState,
		instance_id: StringName
	) -> Dictionary:
	if _catalog == null or inventory == null or state == null or state.unit == null:
		return _failure("STATE_INVALID", "État d’utilisation indisponible.")
	var instance := inventory.get_instance(instance_id)
	if instance == null:
		return _failure("ITEM_NOT_FOUND", "Objet absent de l’inventaire.")
	var definition := _catalog.get_definition(instance.definition_id)
	if definition == null or not definition.is_consumable():
		return _failure("ITEM_NOT_USABLE", "Cet objet ne peut pas être utilisé.")
	if not definition.is_compatible_with(state.character_id):
		return _failure("CHARACTER_INCOMPATIBLE", "Ce héros ne peut pas utiliser cet objet.")
	if not state.unit.is_alive:
		return _failure("TARGET_DEAD", "Un héros vaincu ne peut pas utiliser cet objet.")
	var details := {}
	match definition.use_effect:
		ItemDefinition.UseEffect.HEAL_FLAT:
			if state.unit.current_hp >= state.unit.max_hp.get_int():
				return _failure("TARGET_FULL_HP", "Les PV sont déjà au maximum.")
			var before := state.unit.current_hp
			state.unit.heal(maxi(1, int(round(definition.use_value))))
			details["healed"] = state.unit.current_hp - before
		ItemDefinition.UseEffect.RESTORE_AP_FLAT:
			if state.unit.current_ap >= state.unit.max_ap.get_int():
				return _failure("TARGET_FULL_AP", "Les PA sont déjà au maximum.")
			var before := state.unit.current_ap
			state.unit.current_ap = mini(
				state.unit.max_ap.get_int(),
				state.unit.current_ap + maxi(1, int(round(definition.use_value))),
			)
			details["restored_ap"] = state.unit.current_ap - before
			EventBus.ap_changed.emit(
				state.unit,
				state.unit.current_ap,
				state.unit.max_ap.get_int(),
			)
			state.unit.stats_changed.emit()
		_:
			return _failure("EFFECT_UNSUPPORTED", "Effet d’objet non pris en charge.")
	var removed := inventory.remove_quantity(instance_id, 1)
	if not removed.get("success", false):
		return _failure("CONSUMPTION_FAILED", "Consommation de l’objet impossible.")
	return {
		"success": true,
		"character_id": state.character_id,
		"instance_id": instance_id,
		"definition_id": definition.item_id,
		"details": details,
	}


func _failure(code: String, message: String) -> Dictionary:
	return {"success": false, "error_code": code, "error": message}
