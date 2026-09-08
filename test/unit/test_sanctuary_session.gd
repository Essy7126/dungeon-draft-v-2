extends GutTest
const Session := preload("res://hub/sanctuary_prototype/sanctuary_session.gd")

class Bridge:
	extends Node
	var mode := "halt"
	var calls: Array[String] = []
	var context := {"mode": "halt", "balance": 180, "currency_label": "oboles", "services": [{"id": "lore", "kind": "lore", "title": "Mémoire", "available": true}, {"id": "buy:real_item", "kind": "merchant", "available": true}], "inventory": []}
	var response := {"success": false, "message": "La sauvegarde n'a pas pu être confirmée."}
	func get_sanctuary_context() -> Dictionary:
		context.mode = mode
		return context
	func use_catabase_hub_service(id: String) -> Dictionary:
		calls.append(id)
		return response
	func continue_from_sanctuary() -> Dictionary:
		calls.append("continue")
		return response
	func return_from_sanctuary() -> Dictionary:
		calls.append("return")
		return response


func test_la_preparation_ne_permet_aucun_achat_ni_conversion_de_monnaie() -> void:
	var bridge := Bridge.new()
	autofree(bridge)
	bridge.mode = "preparation"
	var session := Session.new()
	session.bind_runtime(bridge)
	assert_false(session.use_service("lore").success)
	assert_true(bridge.calls.is_empty(), "Un clic périmé ne doit jamais appeler une transaction avant la run.")
	assert_eq(bridge.context.balance, 180)


func test_les_vues_ne_modifient_pas_la_run_et_conservent_les_identifiants_reels() -> void:
	var bridge := Bridge.new()
	autofree(bridge)
	var session := Session.new()
	session.bind_runtime(bridge)
	var context := session.get_context()
	context.services[0].id = "changed"
	context.balance = 0
	assert_eq(bridge.context.services[0].id, "lore")
	assert_eq(bridge.context.balance, 180)
	assert_eq(session.services_for(&"oracle")[0].id, "lore")
	assert_eq(session.services_for(&"merchant")[0].id, "buy:real_item")


func test_les_echecs_de_persistance_remontent_sans_recompense_locale() -> void:
	var bridge := Bridge.new()
	autofree(bridge)
	var session := Session.new()
	session.bind_runtime(bridge)
	assert_eq(session.use_service("lore"), bridge.response)
	assert_eq(session.continue_journey(), bridge.response)
	assert_eq(session.return_from_visit(), bridge.response)
	assert_eq(bridge.calls, ["lore", "continue", "return"])
	assert_eq(session.get_context().balance, 180)


func test_sans_moteur_le_refuge_ne_promet_pas_un_depart_ou_un_solde_fictif() -> void:
	var session := Session.new()
	var context := session.get_context()
	assert_eq(context.mode, "blocked")
	assert_false(context.departure_enabled)
	assert_true(context.services.is_empty())
	assert_false(session.continue_journey().success)
