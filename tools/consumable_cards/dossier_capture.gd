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
	var encounter := Integration.encounter(manager.expedition)
	manager.expedition.cards.loot_commitments[str(encounter.index)] = {
		"fixture": {
			"cards": ["n01", "a01"],
			"equipment": ["b_plate", "w_bow"],
			"relics": ["thread"],
			"bags": [],
		}
	}
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
	dossier.selected_item = "w_bow"
	var before_inspection := GameManager.get_expedition_snapshot()
	dossier._show_item(cards)
	check(
		dossier.find_child("EquipmentComparison", true, false) != null,
		"computed comparison visible",
	)
	check(GameManager.get_expedition_snapshot() == before_inspection, "comparing preserves state")
	await capture("03b_comparaison")
	for value in dossier.find_children("ComparisonValue", "Label", true, false):
		check(value.get_line_count() == 1, "comparison values stay on a single line")
	check(get_viewport().get_visible_rect().encloses(dossier._quick_actions.get_global_rect()), "equipment action remains visible")
	var item_filter = dossier.find_child("DossierItemFilter", true, false)
	item_filter.select(3)
	item_filter.item_selected.emit(3)
	check(
		dossier.find_child("Item_w_bow", true, false).visible,
		"last loot filter includes received equipment after restore",
	)
	check(
		not dossier.find_child("Item_s_life", true, false).visible,
		"last loot filter excludes unrelated equipment",
	)
	await capture("03c_dernier_butin")
	var item_search = dossier.find_child("DossierItemSearch", true, false)
	item_search.text = "aucun_resultat_123"
	item_search.text_changed.emit(item_search.text)
	check(dossier.selected_item.is_empty(), "empty search clears stale equipment inspector")
	item_search.text = ""
	item_search.text_changed.emit("")
	var slot_filter = dossier.find_child("DossierSlotFilter", true, false)
	slot_filter.select(2)
	slot_filter.item_selected.emit(2)
	check(dossier.selected_item == "b_plate", "slot filter selects matching received body item")
	slot_filter.select(0)
	slot_filter.item_selected.emit(0)
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
	check(dossier.find_child("DeckFamily_n02", true, false) != null, "owned family visible")
	_check_deck_partition(dossier, cards)
	for tile in dossier._card_tiles:
		for label in tile.find_children("*", "Label", true, false):
			check(tile.get_global_rect().grow(1).encloses(label.get_global_rect()), "card labels fit inside "
				+ tile.name)
	var affinity = dossier.find_child("DossierAffinityFilter", true, false)
	affinity.select(2)
	affinity.item_selected.emit(2)
	for tile in dossier._card_tiles:
		if tile.visible:
			check(
				Catalog.card(str(tile.get_meta("family"))).affinity == "assassin",
				"affinity filter applies to both lanes",
			)
	await capture("04b_affinite")
	affinity.select(0)
	affinity.item_selected.emit(0)
	var rarity = dossier.find_child("DossierRarityFilter", true, false)
	rarity.select(3)
	rarity.item_selected.emit(3)
	for tile in dossier._card_tiles:
		if tile.visible:
			check(Catalog.card(str(tile.get_meta("family"))).rarity == "rare", "rarity filter applies to both lanes")
	rarity.select(0)
	rarity.item_selected.emit(0)
	dossier.find_child("DeckIdentityHelp", true, false).pressed.emit()
	await capture("04c_reperes")
	for child in dossier.get_children():
		if child is AcceptDialog:
			child.get_ok_button().pressed.emit()
	await get_tree().process_frame

	var card_filter = dossier.find_child("DossierCardFilter", true, false)
	card_filter.select(5)
	card_filter.item_selected.emit(5)
	check(
		dossier.find_child("ReserveFamily_n01", true, false).visible,
		"last loot includes received family",
	)
	check(
		not dossier.find_child("ReserveFamily_t01", true, false).visible,
		"last loot excludes unrelated family",
	)
	card_filter.select(0)
	card_filter.item_selected.emit(0)
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
	var prepare = dossier.find_child("PrepareOne_" + family, true, false)
	check(prepare != null and not prepare.disabled, "preparation action available")
	if prepare != null and not prepare.disabled:
		var before: int = cards.active.size()
		prepare.pressed.emit()
		await get_tree().process_frame
		check(cards.active.size() == before + 1, "prepare action applies once")
		_check_deck_partition(dossier, cards)
		await capture("04d_transfert")
		var reserve = dossier.find_child("ReserveOne_" + family, true, false)
		reserve.pressed.emit()
		await get_tree().process_frame
		check(cards.active.size() == before, "reserve action applies once")
		_check_deck_partition(dossier, cards)
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
	var sources = dossier.find_child("ToggleStatSources", true, false)
	sources.pressed.emit()
	await get_tree().process_frame
	check(dossier.find_child("StatSources", true, false).visible, "stat source disclosure opens")
	await capture("05b_origine_statistiques")
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
	check(_button_containing(dossier, "+1 au deck (").disabled, "read-only preparation disabled")
	check(
		not dossier.find_child("DeckFamily_n02", true, false).disabled,
		"read-only card inspection available",
	)
	clear_scene()
	_open("gear", true)
	await get_tree().process_frame
	dossier = scene.find_child("ConsumablePlayerDossier", true, false)
	dossier.selected_item = "b_plate"
	dossier._show_item(cards)
	check(_button_containing(dossier, "Équiper cet objet").disabled, "read-only equipment disabled")
	check(
		dossier.find_child("EquipmentComparison", true, false) != null,
		"comparison available during read-only inspection",
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


func _check_deck_partition(dossier, cards) -> void:
	var totals := { "deck": 0, "reserve": 0 }
	var actual := { "deck": { }, "reserve": { } }
	for tile in dossier._card_tiles:
		var lane := str(tile.get_meta("lane"))
		var id := str(tile.get_meta("family"))
		var count := int(tile.get_meta("count"))
		check(count > 0, "empty stacks are not displayed")
		actual[lane][id] = count
		totals[lane] += count
		var expected: int = cards \
				.copies \
				.filter(
			func(copy):
				return copy.family == id and ((copy.id in cards.active) == (lane == "deck")),
		) \
				.size()
		check(count == expected, "stack belongs only to " + lane + " / " + id)
	check(totals.deck == cards.active.size(), "deck quantities match active cards")
	check(totals.deck + totals.reserve == cards.copies.size(), "no copy lost or counted twice")
	var left: Control = dossier.find_child("PreparedDeckPanel", true, false)
	var right: Control = dossier.find_child("ReservePanel", true, false)
	check(not left.get_global_rect().intersects(right.get_global_rect()), "deck and reserve occupy separate panels")
