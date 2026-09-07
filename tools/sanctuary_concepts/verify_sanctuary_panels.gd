extends SceneTree

const SESSION := preload("res://hub/sanctuary_prototype/sanctuary_session.gd")
const PANELS := preload("res://hub/sanctuary_prototype/sanctuary_panels.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := SESSION.new()
	var panels := PANELS.new()
	var events := {"changed": 0, "closed": 0}
	panels.session_changed.connect(func() -> void: events.changed += 1)
	panels.closed.connect(func() -> void: events.closed += 1)
	panels.setup(session)
	root.add_child(panels)
	await process_frame
	_check(not panels.is_open() and not panels.visible, "Les panneaux démarrent fermés.")

	panels.open_shop()
	_check(panels.is_open() and panels.visible, "Le marchand ouvre un panneau visible.")
	var buy := panels.find_child("Buy_nectar_des_sources", true, false) as Button
	_check(buy != null and not buy.disabled, "Le nectar peut être acheté.")
	buy.pressed.emit()
	_check(session.get_drachmes() == 95, "Le bouton débite le prix réel du nectar.")
	_check(int(session.get_inventory().get(&"nectar_des_sources", 0)) == 1, "L'achat ajoute le nectar à la besace.")
	buy = panels.find_child("Buy_nectar_des_sources", true, false) as Button
	buy.pressed.emit()
	_check(session.get_drachmes() == 70, "Le second achat actualise le solde.")
	buy = panels.find_child("Buy_nectar_des_sources", true, false) as Button
	_check(buy.disabled, "Un article épuisé ne peut plus être acheté.")
	var costly := panels.find_child("Buy_sceau_de_bronze", true, false) as Button
	_check(costly.disabled and "20" in costly.tooltip_text, "Un article trop cher indique les drachmes manquantes.")
	_check((panels.find_child("DrachmesBalance", true, false) as Label).text == "70 drachmes", "Le solde affiché suit les achats.")
	_check(not (panels.find_child("ActionFeedback", true, false) as Label).text.is_empty(), "L'achat affiche un retour lisible.")
	_check(events.changed == 2, "Chaque achat réussi émet session_changed.")

	panels.open_oracle()
	var confirm := panels.find_child("ConfirmBlessing", true, false) as Button
	_check(confirm != null and confirm.disabled, "La confirmation exige une première sélection.")
	(panels.find_child("Select_athena", true, false) as Button).pressed.emit()
	_check(session.get_selected_blessing().is_empty(), "Une sélection seule ne scelle pas le choix.")
	confirm = panels.find_child("ConfirmBlessing", true, false) as Button
	_check(not confirm.disabled, "La sélection active une confirmation explicite.")
	(panels.find_child("Select_hermes", true, false) as Button).pressed.emit()
	confirm = panels.find_child("ConfirmBlessing", true, false) as Button
	confirm.pressed.emit()
	_check(session.get_selected_blessing().get("id") == &"hermes", "La confirmation retient la dernière sélection.")
	for id: String in ["athena", "hermes", "hestia"]:
		_check((panels.find_child("Select_" + id, true, false) as Button).disabled, "Le choix final bloque " + id + ".")
	_check(events.changed == 3, "La bénédiction émet un seul changement de session.")
	panels.close_panel()
	panels.open_oracle()
	_check(panels.find_child("ConfirmBlessing", true, false) == null, "La réouverture conserve la bénédiction exclusive.")
	(panels.find_child("Select_athena", true, false) as Button).pressed.emit()
	_check(session.get_selected_blessing().get("id") == &"hermes", "Même un signal manuel ne remplace pas une bénédiction.")

	panels.open_inventory()
	_check(_contains_text(panels, "Nectar des sources  × 2"), "La besace présente la quantité achetée.")
	_check(_contains_text(panels, "Faveur d'Hermès"), "La besace présente la faveur reçue.")
	(panels.find_child("ClosePanel", true, false) as Button).pressed.emit()
	_check(not panels.is_open() and not panels.visible and events.closed == 2, "Le bouton de fermeture masque le panneau et émet closed.")
	panels.open_shop()
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	panels._input(escape)
	_check(not panels.is_open() and events.closed == 3, "Échap ferme le panneau.")
	panels.close_panel()
	_check(events.closed == 3, "La fermeture répétée n'émet pas de signal supplémentaire.")

	var before_departure: Dictionary = session.get_snapshot()
	panels.open_departure()
	_check(_contains_text(panels, "Derniers préparatifs"), "Le départ présente un récapitulatif lisible.")
	_check(_contains_text(panels, "Nectar des sources  × 2"), "Le départ conserve le récapitulatif des provisions.")
	(panels.find_child("ReturnToSanctuary", true, false) as Button).pressed.emit()
	_check(not panels.is_open() and session.get_snapshot() == before_departure, "Le départ permet de revenir sans modifier la session.")

	for viewport_size: Vector2i in [Vector2i(1200, 896), Vector2i(1600, 900)]:
		root.size = viewport_size
		for panel_method: String in ["open_shop", "open_oracle", "open_inventory", "open_departure"]:
			panels.call(panel_method)
			await process_frame
			await process_frame
			var panel := panels.find_child("SanctuaryPanel", true, false) as PanelContainer
			_check(panel.position.x >= 0 and panel.position.y >= 0, panel_method + " tient dans " + str(viewport_size) + ".")
			_check(panel.position.x + panel.size.x <= float(viewport_size.x) + 1.0, "Le bord droit reste visible à " + str(viewport_size) + " / " + panel_method + ".")
			_check(panel.position.y + panel.size.y <= float(viewport_size.y) + 1.0, "Le bord inférieur reste visible à " + str(viewport_size) + " / " + panel_method + ".")
			_check((panels.find_child("ModalBackdrop", true, false) as Control).mouse_filter == Control.MOUSE_FILTER_STOP, "Le fond intercepte les clics monde.")
	panels.queue_free()
	await process_frame
	if _failures.is_empty():
		print("SANCTUARY_PANELS_SMOKE_OK")
		quit(0)
	else:
		for failure: String in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _contains_text(node: Node, expected: String) -> bool:
	if node is Label and node.text == expected:
		return true
	for child: Node in node.get_children():
		if _contains_text(child, expected):
			return true
	return false
