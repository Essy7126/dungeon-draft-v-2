extends "res://tools/consumable_cards/integrated_capture.gd"
## Deterministic victory UI fixtures. No claim about combat difficulty.
const Receipt := preload("res://ui/expedition/consumable_loot_receipt.gd")


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
	manager.expedition_save_path = "user://loot_capture.json"
	manager.select_run_variant("cards")
	check(manager.start_expedition(33, { }, false, true, "normal", true), "start")
	var families: Array = ["n01", "n01", "n02", "a01"]
	for rarity in ["elite", "rare", "legendary", "god", "immortal"]:
		for row in Catalog.data().cards:
			if row.rarity == rarity:
				families.append(row.id)
				break
	var encounter := preload("res://core/expedition/consumable_cards_integration.gd").encounter(
		manager.expedition
	)
	manager.expedition.cards.loot_commitments[str(encounter.index)] = {
		"enemy": {
			"cards": families,
			"equipment": ["w_blade", "f_quick"],
			"relics": ["thread"],
			"bags": [],
		}
	}
	check(manager.expedition.combat_won(), "fixture victory")
	check(GameManager.restore_expedition_snapshot(manager.get_expedition_snapshot()), "restore")
	manager.cleanup_run_state()
	manager.free()
	_open_receipt()
	await capture("01_butin")
	var view = scene.find_child("ConsumableCombatResults", true, false)
	check(view != null, "dedicated receipt replaces workshop")
	check(scene.find_child("Family_n01", true, false) == null, "no deck workshop")
	var tile = view.find_child("LootReceipt_n01", true, false)
	_hover(tile)
	await capture("02_carte_survolee")
	check(
		is_instance_valid(view._preview) and view._preview.visible,
		"real mouse hover expands card",
	)
	check(get_viewport().get_visible_rect().encloses(view._preview.get_global_rect()), "hover fits viewport")
	var gear = view.find_child("LootReceipt_w_blade", true, false)
	_scroll_to(gear)
	await get_tree().process_frame
	_hover(gear)
	await capture("03_equipement_survole")
	check(view._source == gear, "passive hover allows another drop")
	# Every authored effect must fit, including the longest rule and all rarities.
	for row in Catalog.data().cards:
		for upgraded in [false, true]:
			var probe = preload("res://ui/expedition/consumable_loot_tile.gd").new()
			var record := Receipt.card_record(row.id, upgraded)
			record.count = 1
			probe.configure(record)
			view.add_child(probe)
			view._show_preview(probe)
			await get_tree().process_frame
			await get_tree().process_frame
			check(
				get_viewport().get_visible_rect().encloses(view._preview.get_global_rect()),
				"fits %s upgraded=%s" % [row.id, upgraded],
			)
			check(
				view._preview.mouse_filter == Control.MOUSE_FILTER_IGNORE,
				"passive " + str(row.id),
			)
			view._hide_preview(probe)
			probe.free()
	clear_scene()
	var before_sale: Dictionary = GameManager.get_expedition_snapshot()
	var expected := Receipt.records_for(GameManager.expedition).map(
		func(row):
			return [row.id, row.count],
	)
	var economy = preload("res://core/expedition/consumable_card_economy.gd")
	var cards = GameManager.expedition.cards
	economy.market(cards, "loot_capture", 1)
	check(economy.transact(cards, "loot_capture", {
			"id": "sale",
			"kind": "sell",
			"copies": [cards.last_drops[0]],
		}).success, "sell a received copy")
	GameManager.expedition.gold = cards.gold
	check(
		GameManager.restore_expedition_snapshot(GameManager.get_expedition_snapshot()),
		"restore after sale",
	)
	check(
		Receipt.records_for(GameManager.expedition).map(
			func(row):
				return [row.id, row.count],
		) == expected,
		"receipt unchanged after sale and restore",
	)
	check(GameManager.restore_expedition_snapshot(before_sale), "restore capture fixture")
	var receipt: Dictionary = GameManager.expedition.cards.battle_results["d01_0"]
	receipt.card_families = Catalog.data().cards.map(
		func(row):
			return row.id,
	)
	_open_receipt()
	await capture("04_butin_abondant")
	var close = scene.find_child("ClassLootContinue", true, false)
	check(get_viewport().get_visible_rect().encloses(close.get_global_rect()), "close stays visible with 48 families")
	clear_scene()
	receipt.card_families = []
	GameManager.expedition.cards.loot_commitments.clear()
	_open_receipt()
	await capture("05_sans_objet")
	var finish = scene.find_child("ClassLootContinue", true, false)
	var mouse := InputEventMouseMotion.new()
	mouse.position = finish.get_global_rect().get_center()
	get_viewport().push_input(mouse)
	var click := InputEventMouseButton.new()
	click.position = mouse.position
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	get_viewport().push_input(click)
	var release := click.duplicate()
	release.pressed = false
	get_viewport().push_input(release)
	await get_tree().process_frame
	await get_tree().process_frame
	check(GameManager.expedition.class_combat_receipt_reviewed(), "real close acknowledges receipt")
	check(scene._page != "rewards", "close continues to progression")
	clear_scene()
	GameManager.cleanup_run_state()
	print(
		"LOOT_CAPTURE "
		+ JSON.stringify(
			{ "passed": failures.is_empty(), "captures": captures, "failures": failures }
		)
	)
	get_tree().quit(0 if failures.is_empty() else 1)


func _open_receipt() -> void:
	scene = load(GameManager.EXPEDITION_SCREEN_PATH).instantiate()
	scene.inspection_only = false
	scene.initial_page = "rewards"
	add_child(scene)
	scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _hover(control: Control) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = control.get_global_rect().get_center()
	get_viewport().push_input(motion)


func _scroll_to(control: Control) -> void:
	var parent := control.get_parent()
	while parent != null:
		if parent is ScrollContainer:
			parent.ensure_control_visible(control)
			return
		parent = parent.get_parent()
