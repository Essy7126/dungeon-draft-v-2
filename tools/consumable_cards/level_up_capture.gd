extends "res://tools/consumable_cards/integrated_capture.gd"
const Flow := preload("res://core/expedition/expedition_flow.gd")


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
	manager.expedition_save_path = "user://level_capture.json"
	manager.select_run_variant("cards")
	check(manager.start_expedition(33, { }, false, true, "normal", true), "start")
	check(manager.expedition.combat_won(), "victory")
	check(
		Flow.required_step(manager.expedition) == "rewards",
		"loot comes before level announcement",
	)
	check(
		GameManager.restore_expedition_snapshot(manager.get_expedition_snapshot()),
		"restore pending announcement",
	)
	manager.cleanup_run_state()
	manager.free()
	GameManager.expedition_save_path = "user://level_capture_active.json"
	scene = load(GameManager.EXPEDITION_SCREEN_PATH).instantiate()
	scene.initial_page = "rewards"
	add_child(scene)
	scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await get_tree().process_frame
	scene.find_child("ClassLootContinue", true, false).pressed.emit()
	await capture("01_niveau_apres_butin")
	check(scene._page == "advancement", "closing receipt opens level hub")
	check(scene.find_child("LevelAnnouncement", true, false) != null, "explicit level announcement")
	_bounds()
	scene.find_child("OpenStatAllocation", true, false).pressed.emit()
	check(scene._page == "allocation", "allocation has its own window")
	scene._close_current_view()
	check(scene._page == "advancement", "allocation returns to announcement")
	scene.find_child("OpenLevelDeck", true, false).pressed.emit()
	check(scene._page == "cards", "card choice opens deck, not class")
	scene._close_current_view()
	check(scene._page == "advancement", "deck returns to announcement")
	var snapshot: Dictionary = GameManager.get_expedition_snapshot()
	clear_scene()
	check(
		GameManager.restore_expedition_snapshot(snapshot),
		"reopen pending level without losing it",
	)
	_open()
	await capture("02_annonce_reprise")
	_bounds()
	clear_scene()
	GameManager.expedition.cards.level = 4
	GameManager.expedition.advancement_from_level = 3
	GameManager.expedition.cards.specialization = ""
	_open()
	await capture("03_specialisation")
	_bounds()
	check(
		scene.find_child("ConsumableProgressionContinue", true, false).disabled,
		"required specialization cannot be skipped",
	)
	scene.find_child("OpenRequiredSpecialization", true, false).pressed.emit()
	check(scene._page == "build", "specialization opens separate class window")
	scene._close_current_view()
	check(scene._page == "advancement", "class returns to announcement")
	clear_scene()
	GameManager.expedition.cards.level = 8
	GameManager.expedition.advancement_from_level = 1
	_open()
	await capture("04_niveaux_groupes")
	_bounds()
	check(
		scene.find_child("LevelAnnouncement", true, false).text == "NIVEAU 8",
		"multiple levels share one announcement",
	)
	clear_scene()
	GameManager.cleanup_run_state()
	print(
		"LEVEL_UP_CAPTURE "
		+ JSON.stringify(
			{ "passed": failures.is_empty(), "captures": captures, "failures": failures }
		)
	)
	get_tree().quit(0 if failures.is_empty() else 1)


func _open() -> void:
	scene = load(GameManager.EXPEDITION_SCREEN_PATH).instantiate()
	scene.initial_page = "advancement"
	add_child(scene)
	scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _bounds() -> void:
	var viewport := get_viewport().get_visible_rect()
	for control in scene.find_children("*", "Button", true, false):
		if control.is_visible_in_tree():
			check(
				viewport.encloses(control.get_global_rect()),
				"visible button fits: " + control.name,
			)
	check(viewport.encloses(scene._decision_panel.get_global_rect()), "whole level window fits")
