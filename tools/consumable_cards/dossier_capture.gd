extends "res://tools/consumable_cards/integrated_capture.gd"
## Native public-window fixtures. Isolated user directory; no balance claim.
const Integration := preload("res://core/expedition/consumable_cards_integration.gd")


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	if output.is_empty() or not OS.get_user_data_dir().replace("\\", "/").begins_with(
			ProjectSettings.globalize_path("res://artifacts/dev/").replace("\\", "/")
		):
		get_tree().quit(2)
		return
	GameManager.cleanup_run_state()
	var manager := Manager.new()
	add_child(manager)
	manager.expedition_save_path = "user://dossier_capture.json"
	manager.select_run_variant("cards")
	check(manager.start_expedition(33, { }, false, true, "normal", true), "public start")
	check(manager.expedition.combat_won(), "fixture victory")
	check(GameManager.restore_expedition_snapshot(manager.get_expedition_snapshot()), "restore")
	manager.cleanup_run_state()
	manager.free()
	GameManager.expedition_save_path = "user://dossier_capture_active.json"
	var cards = GameManager.expedition.cards
	cards.equipment_copies.clear()
	cards.owned_relics.clear()
	cards.equipped.clear()
	cards.active_relics.clear()
	_open("gear")
	await capture("01_inventaire_depart")
	_bounds()
	clear_scene()
	for row in Catalog.data().equipment:
		cards.item_serial += 1
		cards.equipment_copies.append(
			{
				"id": "cc2_item_%08d" % cards.item_serial,
				"definition": row.id,
				"origin": "loot",
				"receipt": "fixture",
			}
		)
	for row in Catalog.data().relics:
		cards.owned_relics.append(str(row.id))
	for row in Catalog.data().cards:
		cards.add_copy(row.id)
	_open("gear")
	await capture("02_inventaire_butin")
	_bounds()
	var dossier = scene.find_child("ConsumablePlayerDossier", true, false)
	var equip = _button_containing(dossier, "Équiper cet objet")
	check(equip != null and not equip.disabled, "equipment action available")
	if equip != null:
		equip.pressed.emit()
	await get_tree().process_frame
	check(not cards.equipped.is_empty(), "equipment action applies")
	await capture("03_inventaire_equipe")
	dossier.selected_item = "thread"
	dossier._show_item(cards)
	var activate := _button_containing(dossier, "Activer la relique")
	check(activate != null and not activate.disabled, "relic action available")
	if activate != null:
		activate.pressed.emit()
	await get_tree().process_frame
	check("thread" in cards.active_relics, "relic activates")
	var deactivate := _button_containing(dossier, "Désactiver la relique")
	if deactivate != null:
		deactivate.pressed.emit()
	await get_tree().process_frame
	check("thread" not in cards.active_relics, "relic deactivates")
	clear_scene()
	_open("cards")
	await capture("04_collection")
	_bounds()
	dossier = scene.find_child("ConsumablePlayerDossier", true, false)
	check(dossier.find_child("Family_n02", true, false) != null, "owned family visible")
	var search = dossier.find_child("DossierSearch", true, false)
	search.text = "aucun_resultat_123"
	search.text_changed.emit(search.text)
	await get_tree().process_frame
	check(dossier.find_child("EmptyCollection", true, false).visible, "live search empty state")
	search.text = ""
	search.text_changed.emit(search.text)
	var family := ""
	for row in Catalog.data().cards:
		if dossier._copies(cards, row.id, true).is_empty():
			family = row.id
			break
	dossier.selected_family = family
	dossier._show_family(cards)
	var prepare = _button_containing(dossier, "Préparer (")
	check(prepare != null and not prepare.disabled, "preparation action available")
	if prepare != null and not prepare.disabled:
		var before: int = cards.active.size()
		prepare.pressed.emit()
		await get_tree().process_frame
		check(cards.active.size() == before + 1, "prepare action applies once")
		var reserve := _button_containing(dossier, "Mettre en réserve")
		reserve.pressed.emit()
		await get_tree().process_frame
		check(cards.active.size() == before, "reserve action applies once")
	for row in Catalog.data().cards:
		dossier.selected_family = row.id
		dossier._show_family(cards)
		await get_tree().process_frame
		check(
			get_viewport().get_visible_rect().encloses(dossier._quick_actions.get_global_rect()),
			"actions remain visible for " + str(row.id),
		)
	clear_scene()
	_open("attributes")
	await capture("05_caracteristiques")
	_bounds()
	dossier = scene.find_child("ConsumablePlayerDossier", true, false)
	var attribute = dossier.find_child("Attribute_power", true, false)
	check(attribute != null and not attribute.disabled, "attribute action available")
	if attribute != null:
		attribute.pressed.emit()
	await get_tree().process_frame
	check(int(cards.attributes.power) == 1, "attribute allocation applies")
	var saved := ExpeditionSaveService.read_snapshot(GameManager.expedition_save_path)
	check(
		int(saved.get("session", { }).get("cards_run", { }).get("attributes", { }).get("power", 0)) == 1,
		"attribute persisted",
	)
	clear_scene()
	_open("build")
	await capture("06_progression")
	_bounds()
	clear_scene()
	_open("cards", true)
	await get_tree().process_frame
	dossier = scene.find_child("ConsumablePlayerDossier", true, false)
	check(_button_containing(dossier, "Préparer (").disabled, "read-only preparation disabled")
	check(
		not dossier.find_child("Family_n02", true, false).disabled,
		"read-only card inspection available",
	)
	clear_scene()
	GameManager.cleanup_run_state()
	print(
		"DOSSIER_CAPTURE "
		+ JSON.stringify(
			{ "passed": failures.is_empty(), "captures": captures, "failures": failures }
		)
	)
	get_tree().quit(0 if failures.is_empty() else 1)


func _open(page: String, readonly := false) -> void:
	scene = load(GameManager.EXPEDITION_SCREEN_PATH).instantiate()
	scene.inspection_only = readonly
	scene.initial_page = page
	add_child(scene)
	scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not readonly:
		scene._navigate(page)


func _bounds() -> void:
	var panel = scene.find_child("CatabaseDecisionWindow", true, false)
	check(
		panel != null and get_viewport().get_visible_rect().encloses(panel.get_global_rect()),
		"window within viewport: " + scene._page,
	)
	var close = scene.find_child("CloseDedicatedWindow", true, false)
	check(close != null and get_viewport().get_visible_rect().encloses(close.get_global_rect()), "close within viewport")


func _button_containing(parent: Node, value: String) -> Button:
	for child in parent.get_children():
		if child is Button and value in child.text:
			return child
		var found := _button_containing(child, value)
		if found != null:
			return found
	return null
