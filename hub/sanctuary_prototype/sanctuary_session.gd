class_name SanctuarySession
extends RefCounted

## Etat temporaire du prototype : aucune sauvegarde ni dependance au combat.
const INITIAL_DRACHMES := 120
const SHOP_ITEMS := [
	{
		"id": &"nectar_des_sources", "name": "Nectar des sources",
		"description": "Une fiole de nectar préparée par le marchand du sanctuaire.",
		"price": 25, "initial_stock": 2,
	},
	{
		"id": &"fil_d_ariane", "name": "Fil d'Ariane",
		"description": "Un fil doré pour garder la mémoire du chemin parcouru.",
		"price": 60, "initial_stock": 2,
	},
	{
		"id": &"sceau_de_bronze", "name": "Sceau de bronze",
		"description": "Un sceau gravé à l'effigie des gardiens du sanctuaire.",
		"price": 90, "initial_stock": 1,
	},
]
const BLESSINGS := [
	{
		"id": &"athena", "name": "Clairvoyance d'Athéna",
		"description": "Athéna éclaire les décisions d'Achille.",
		"effect": "Intention pour l'expédition : révéler un indice avant un choix.",
	},
	{
		"id": &"hermes", "name": "Faveur d'Hermès",
		"description": "Hermès veille sur les rencontres et les échanges.",
		"effect": "Intention pour l'expédition : découvrir une occasion de commerce.",
	},
	{
		"id": &"hestia", "name": "Chaleur d'Hestia",
		"description": "Hestia offre à Achille la promesse d'un refuge.",
		"effect": "Intention pour l'expédition : trouver un lieu de repos.",
	},
]

var _drachmes := INITIAL_DRACHMES
var _inventory: Dictionary = {}
var _stocks: Dictionary = {}
var _selected_blessing: StringName = &""


func _init() -> void:
	reset()


func reset() -> void:
	_drachmes = INITIAL_DRACHMES
	_inventory.clear()
	_stocks.clear()
	_selected_blessing = &""
	for item: Dictionary in SHOP_ITEMS:
		_stocks[item.id] = item.initial_stock


func get_drachmes() -> int:
	return _drachmes


func get_inventory() -> Dictionary:
	return _inventory.duplicate(true)


func get_shop_items() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for source: Dictionary in SHOP_ITEMS:
		var item := source.duplicate(true)
		item["stock"] = int(_stocks[item.id])
		result.append(item)
	return result


func get_blessings() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for source: Dictionary in BLESSINGS:
		result.append(source.duplicate(true))
	return result


func get_selected_blessing() -> Dictionary:
	return _find_entry(BLESSINGS, _selected_blessing).duplicate(true)


func get_snapshot() -> Dictionary:
	return {
		"drachmes": _drachmes,
		"inventory": _inventory.duplicate(true),
		"stocks": _stocks.duplicate(true),
		"selected_blessing": _selected_blessing,
	}


func buy_item(item_id: StringName, quantity: int = 1) -> Dictionary:
	var item := _find_entry(SHOP_ITEMS, item_id)
	if item.is_empty():
		return _failure(&"unknown_item", "Cet article n'existe pas.")
	if quantity <= 0:
		return _failure(&"invalid_quantity", "La quantité doit être positive.")
	var stock := int(_stocks[item_id])
	# Check bounded stock before multiplication, including very large requests.
	if quantity > stock:
		return _failure(&"insufficient_stock", "Le marchand n'a plus assez de stock.")
	var total_price := int(item.price) * quantity
	if total_price > _drachmes:
		return _failure(&"insufficient_funds", "Achille n'a pas assez de drachmes.")

	# Commit only after every validation has passed; failures leave state intact.
	_drachmes -= total_price
	_stocks[item_id] = stock - quantity
	_inventory[item_id] = int(_inventory.get(item_id, 0)) + quantity
	return {
		"ok": true, "error": &"", "item_id": item_id,
		"quantity": quantity, "total_price": total_price,
		"message": "%s rejoint l'inventaire." % String(item.name),
	}


func choose_blessing(blessing_id: StringName) -> Dictionary:
	var blessing := _find_entry(BLESSINGS, blessing_id)
	if blessing.is_empty():
		return _failure(&"unknown_blessing", "Cette bénédiction n'existe pas.")
	if _selected_blessing != &"":
		return _failure(&"blessing_already_chosen", "Achille a déjà choisi sa bénédiction.")
	_selected_blessing = blessing_id
	return {
		"ok": true, "error": &"", "blessing_id": blessing_id,
		"message": "%s accompagne désormais Achille." % String(blessing.name),
	}


func _find_entry(entries: Array, entry_id: StringName) -> Dictionary:
	for entry: Dictionary in entries:
		if entry.id == entry_id:
			return entry
	return {}


func _failure(error: StringName, message: String) -> Dictionary:
	return {"ok": false, "error": error, "message": message}
