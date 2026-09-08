extends SceneTree
## Component checks use a bridge fixture; real Catabase transactions are covered by the runtime probe.
const SESSION := preload("res://hub/sanctuary_prototype/sanctuary_session.gd")
const PANELS := preload("res://hub/sanctuary_prototype/sanctuary_panels.gd")
var failures: Array[String] = []

class BridgeFixture:
	extends Node
	var service_calls: Array[String] = []
	var fail_save := true
	var applied_without_save := false
	var context := {
		"mode": "halt", "balance": 160, "currency_label": "oboles",
		"services": [
			{"id": "buy:equipment_fixture", "kind": "merchant", "title": "Équipement de la halte", "description": "Une description assez longue pour vérifier la lecture dans les panneaux étroits.", "cost": 82, "used": false, "available": true},
			{"id": "lore", "kind": "lore", "title": "Écouter les noms oubliés", "description": "Découvrir un passage secret et recevoir 20 oboles.", "cost": 0, "used": false, "available": true},
		], "inventory": [], "departure_enabled": true, "departure_label": "Reprendre le chemin",
		"departure_description": "Vos achats et vos découvertes suivent votre aventure.",
	}
	func get_sanctuary_context() -> Dictionary:
		return context
	func use_catabase_hub_service(id: String) -> Dictionary:
		service_calls.append(id)
		if fail_save:
			return {"success": false, "message": "Sauvegarde impossible : vos choix restent inchangés."}
		for entry in context.services:
			if entry.id == id:
				entry.used = true
				entry.available = false
		return {"success": true, "saved": not applied_without_save, "message": "Choix appliqué. Enregistrement impossible : réessayez la sauvegarde." if applied_without_save else "Choix enregistré."}
	func continue_from_sanctuary() -> Dictionary:
		return {"success": false, "message": "Impossible d'enregistrer le départ."}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var bridge := BridgeFixture.new()
	root.add_child(bridge)
	var session := SESSION.new()
	session.bind_runtime(bridge)
	var panels := PANELS.new()
	panels.setup(session)
	root.add_child(panels)
	await process_frame
	panels.open_shop()
	await process_frame
	var buy := panels.find_child("Buy_buy_equipment_fixture", true, false) as Button
	check(buy != null and not buy.disabled, "Offre réelle du contexte affichée.")
	buy.pressed.emit()
	check(bridge.service_calls == ["buy:equipment_fixture"], "Le bouton transmet l'identifiant complet.")
	check("Sauvegarde impossible" in (panels.find_child("ActionFeedback", true, false) as Label).text, "L'erreur de sauvegarde reste visible.")
	check((panels.find_child("SanctuaryBalance", true, false) as Label).text == "160 oboles", "Pas de débit visuel optimiste.")
	bridge.fail_save = false
	panels.open_oracle()
	var choose := panels.find_child("Select_lore", true, false) as Button
	choose.pressed.emit()
	check(bridge.service_calls.size() == 1, "La sélection seule ne consomme pas le service.")
	(panels.find_child("ConfirmService", true, false) as Button).pressed.emit()
	check(bridge.service_calls == ["buy:equipment_fixture", "lore"], "Confirmation explicite du vrai service.")
	check((panels.find_child("Select_lore", true, false) as Button).disabled, "Une transaction accomplie n'est plus proposée.")
	bridge.applied_without_save = true
	panels.open_shop()
	(panels.find_child("Buy_buy_equipment_fixture", true, false) as Button).pressed.emit()
	var feedback := panels.find_child("ActionFeedback", true, false) as Label
	check("Enregistrement impossible" in feedback.text and feedback.get_theme_color("font_color").is_equal_approx(Color("e4ac91")), "Une transaction appliquée mais non enregistrée garde son alerte.")
	check((panels.find_child("Buy_buy_equipment_fixture", true, false) as Button).disabled, "Une sauvegarde refusée ne permet pas de rejouer l'achat appliqué.")
	for resolution: Vector2i in [Vector2i(1200, 896), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = resolution
		for method in ["open_shop", "open_oracle", "open_inventory", "open_departure"]:
			panels.call(method)
			for frame in 4: await process_frame
			var panel := panels.find_child("SanctuaryPanel", true, false) as Control
			var rect := panel.get_global_rect()
			check(rect.position.x >= 0 and rect.position.y >= 0 and rect.end.x <= resolution.x + 1 and rect.end.y <= resolution.y + 1, "Panneau borné %s %s" % [resolution, method])
			var actions := panels.find_child("FixedActions", true, false) as Control
			check(actions.get_global_rect().end.y <= resolution.y, "Actions fixes visibles %s %s" % [resolution, method])
			var tab := InputEventKey.new()
			tab.keycode = KEY_TAB
			tab.pressed = true
			for press in 8: panels._input(tab)
			var focus := root.gui_get_focus_owner()
			check(focus != null and panels.is_ancestor_of(focus), "Tab conserve le focus dans le panneau.")
	bridge.context.mode = "preparation"
	bridge.context.services = []
	panels.open_shop()
	check(panels.find_children("Buy_*", "Button", true, false).is_empty(), "Aucun achat fictif avant le départ.")
	panels.open_departure()
	var depart := panels.find_child("ContinueJourney", true, false) as Button
	depart.pressed.emit()
	for frame in 4: await process_frame
	check("Impossible" in (panels.find_child("ActionFeedback", true, false) as Label).text, "Un départ refusé garde le contexte et explique l'erreur.")
	check(not (panels.find_child("ContinueJourney", true, false) as Button).disabled, "Le départ peut être retenté.")
	panels.queue_free()
	bridge.queue_free()
	await process_frame
	for failure in failures: push_error(failure)
	print("SANCTUARY_PANELS_SMOKE_OK" if failures.is_empty() else "SANCTUARY_PANELS_FAILED: " + str(failures))
	quit(0 if failures.is_empty() else 1)

func check(value: bool, message: String) -> void:
	if not value: failures.append(message)
