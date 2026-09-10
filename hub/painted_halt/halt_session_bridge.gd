extends RefCounted
## The editor has an isolated visit. Production delegates to the existing
## SanctuarySession bridge, so prices, receipts and saves stay in GameManager.
const SESSION := preload("res://hub/sanctuary_prototype/sanctuary_session.gd")
var preview := true
var _session := SESSION.new()
var _manager: Node
var _balance := 180
var _used: Array[String] = []
var departed := false


func configure(is_preview: bool, manager: Node = null) -> void:
	preview = is_preview
	_manager = manager
	if not preview:
		_session.bind_runtime(manager)


func context() -> Dictionary:
	if not preview:
		return _session.get_context()
	var services: Array[Dictionary] = [
		{
			"id": "preview:bronze",
			"kind": "merchant",
			"title": "Bracelet de bronze",
			"cost": 60,
			"description": "Une pièce d’atelier pour éprouver l’achat. Cet essai reste dans cette visite.",
		},
		{
			"id": "preview:blessing",
			"kind": "sanctuary",
			"title": "Éveiller les sources",
			"cost": 40,
			"description": "L’autel répond à votre offrande. Une seule offrande pendant cette visite.",
		},
		{
			"id": "preview:rest",
			"kind": "hub",
			"title": "Se recueillir",
			"cost": 25,
			"description": "Prendre un instant près des pierres anciennes.",
		},
		{
			"id": "preview:lore",
			"kind": "lore",
			"title": "La mémoire des racines",
			"cost": 0,
			"description": "Sous la pierre, les racines gardent la mémoire des noms confiés au feu.",
		},
	]
	for service: Dictionary in services:
		service["used"] = str(service.id) in _used
		service["available"] = not service.used and _balance >= int(service.cost) and not departed
	return {
		"mode": "halt",
		"balance": _balance,
		"services": services,
		"preview": true,
		"departure_enabled": not departed,
	}


func blocked() -> bool:
	if preview:
		return departed
	if not is_instance_valid(_manager) or context().get("mode", "") != "halt":
		return true
	return bool(_manager.call("get_expedition_save_status").get("pending", false))


func use_service(id: String) -> Dictionary:
	if blocked():
		return {
			"success": false,
			"message": "Cette action attend la reprise de la halte ou de son enregistrement.",
		}
	if not preview:
		return _session.use_service(id)
	for service: Dictionary in context().services:
		if str(service.id) == id:
			if not bool(service.available):
				return { "success": false, "message": "Déjà accompli ou oboles insuffisantes." }
			_balance -= int(service.cost)
			_used.append(id)
			return {
				"success": true,
				"saved": true,
				"message": str(service.title) + " · essai accompli.",
			}
	return { "success": false, "message": "Ce service n’existe plus." }


func leave() -> Dictionary:
	if blocked():
		return { "success": false, "message": "La halte attend un enregistrement avant le départ." }
	if not preview:
		return _session.continue_journey()
	departed = true
	return {
		"success": true,
		"saved": true,
		"message": "Visite terminée. Fermez cet essai pour revenir à l’atelier.",
	}


func retry_save() -> Dictionary:
	if preview or not is_instance_valid(_manager):
		return { "success": false }
	var success: bool = _manager.call("retry_expedition_save")
	return { "success": success, "message": str(_manager.call("get_expedition_save_status").get(
				"message",
				"",
			)) }
