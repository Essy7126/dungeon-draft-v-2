class_name SanctuarySession
extends RefCounted
## Presentation bridge. GameManager owns every transaction and its persistence.
var _manager: Node


func bind_runtime(manager: Node) -> void:
	_manager = manager


func get_context() -> Dictionary:
	if is_instance_valid(_manager) and _manager.has_method("get_sanctuary_context"):
		var context: Variant = _manager.call("get_sanctuary_context")
		if context is Dictionary:
			return context.duplicate(true)
	return {
		"mode": "blocked", "balance": 0, "currency_label": "oboles",
		"services": [], "inventory": [], "departure_enabled": false,
		"departure_label": "Passage indisponible",
		"departure_description": "Le refuge ne peut pas encore rejoindre votre aventure.",
		"return_label": "Menu principal",
	}


func services_for(kind: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for service: Dictionary in get_context().get("services", []):
		var is_merchant := str(service.get("kind", "")) == "merchant"
		if (kind == &"merchant" and is_merchant) or (kind == &"oracle" and not is_merchant):
			result.append(service)
	return result


func use_service(service_id: String) -> Dictionary:
	if str(get_context().get("mode", "")) != "halt":
		return {"success": false, "message": "Les préparatifs seront disponibles lors d'une halte de Catabase."}
	return _action("use_catabase_hub_service", service_id)


func continue_journey() -> Dictionary:
	return _action("continue_from_sanctuary")


func return_from_visit() -> Dictionary:
	return _action("return_from_sanctuary")


func _action(method: String, argument: Variant = null) -> Dictionary:
	if not is_instance_valid(_manager) or not _manager.has_method(method):
		return {"success": false, "message": "Cette action est momentanément indisponible."}
	var result: Variant = _manager.call(method) if argument == null else _manager.call(method, argument)
	return result if result is Dictionary else {"success": false, "message": "Le refuge n'a pas pu confirmer cette action."}
