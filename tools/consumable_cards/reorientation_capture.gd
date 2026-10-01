extends "res://tools/consumable_cards/integrated_capture.gd"
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
	manager.expedition_save_path = "user://audit_setup.json"
	manager.select_run_variant("cards")
	check(manager.start_expedition(33, { }, false, true, "normal", true), "start")
	check(manager.expedition.combat_won(), "victory fixture")
	check(GameManager.restore_expedition_snapshot(manager.get_expedition_snapshot()), "restore")
	manager.cleanup_run_state()
	manager.free()
	GameManager.expedition_save_path = "user://audit_active.json"
	var session = GameManager.expedition
	var cards = session.cards
	cards.level = 8
	cards.masteries.earth = 3
	cards.aptitudes.vitality = 1
	cards.specialization = str(Catalog.class_row(cards.primary_class).specs[0])
	for node in session.route.nodes:
		if int(node.depth) == 11:
			session.route.current_node_id = str(node.id)
			break
	session.route.phase = "reward"
	cards.combat_started = false
	Integration.rebuild(session, true)
	check(
		Integration.full_reorientation_available(session),
		"reset available in real refuge conditions",
	)
	scene = load(GameManager.EXPEDITION_SCREEN_PATH).instantiate()
	scene.inspection_only = true
	scene.allow_attribute_edits = true
	scene.initial_page = "attributes"
	add_child(scene)
	scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scene.find_child("OpenStatAllocation", true, false).pressed.emit()
	await get_tree().process_frame
	var editor = scene.find_child("PrototypeV1Progression", true, false)
	var before: String = editor._preview.text
	editor.find_child("Allocation_contact", true, false).value = 3
	check(
		editor.find_child("ApplyPrototypeAllocation", true, false).disabled,
		"overspending cannot be confirmed",
	)
	check("Points insuffisants" in editor._budget.text, "overspending is explained")
	editor.find_child("Allocation_contact", true, false).value = 0
	editor.find_child("Allocation_contact", true, false).value = 1
	check(before != editor._preview.text, "contact bonus is explained")
	editor.find_child("ProgressionCategories", true, false).current_tab = 1
	await capture("01_contact_preview")
	editor.find_child("Allocation_contact", true, false).value = 0
	editor.find_child("Allocation_distance", true, false).value = 1
	check(before != editor._preview.text, "distance bonus is explained even without a ranged deck")
	var snapshot := GameManager.get_expedition_snapshot()
	check(GameManager.save_expedition(), "baseline save")
	editor.find_child("ShowReorientation", true, false).pressed.emit()
	editor.find_child("FullPrototypeReorientation", true, false).pressed.emit()
	await get_tree().process_frame
	var dialog: ConfirmationDialog = editor.find_child("ConfirmFullReorientation", true, false)
	check(dialog != null and dialog.visible, "reset opens a dedicated confirmation")
	check(GameManager.get_expedition_snapshot() == snapshot, "opening confirmation does not mutate")
	check(dialog.gui_get_focus_owner() == dialog.get_cancel_button(), "safe default focus")
	await capture("02_reset_confirmation")
	# Escape is delivered to the focused embedded window, just like the OS.
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	dialog.push_input(escape)
	await get_tree().process_frame
	check(not dialog.visible, "Escape dismisses confirmation")
	check(scene._page == "allocation", "Escape preserves the allocation page")
	check(GameManager.get_expedition_snapshot() == snapshot, "Escape preserves state")
	check(editor.aptitudes.distance == 1, "cancel preserves the draft")
	var canceled_save := ExpeditionSaveService.read_snapshot(GameManager.expedition_save_path)
	check(
		not canceled_save.get("session", { }).get("cards_run", { }).get(
			"full_reorientation_used",
			true,
		),
		"cancel leaves saved reset unused",
	)
	editor.find_child("FullPrototypeReorientation", true, false).pressed.emit()
	dialog.get_cancel_button().pressed.emit()
	await get_tree().process_frame
	check(not dialog.visible, "cancel button closes confirmation")
	check(GameManager.get_expedition_snapshot() == snapshot, "cancel preserves state")
	editor.find_child("FullPrototypeReorientation", true, false).pressed.emit()
	dialog.get_ok_button().pressed.emit()
	await get_tree().process_frame
	check(cards.full_reorientation_used, "confirmation consumes the single reset")
	check(cards.specialization.is_empty(), "announced specialization reset applies")
	check(cards.masteries.earth == 0 and cards.aptitudes.vitality == 0, "points refunded")
	check(not Integration.full_reorientation_available(session), "reset cannot be reused")
	var saved := ExpeditionSaveService.read_snapshot(GameManager.expedition_save_path)
	check(saved.get("session", { }).get("cards_run", { }).get("full_reorientation_used", false), "reset saved")
	check(saved.get("session", { }).get("cards_run", { }).get("specialization", "missing") == "", "specialization reset saved")
	await capture("03_reset_applied")
	clear_scene()
	GameManager.cleanup_run_state()
	print(
		"REORIENTATION_CAPTURE "
		+ JSON.stringify(
			{ "passed": failures.is_empty(), "captures": captures, "failures": failures }
		)
	)
	get_tree().quit(0 if failures.is_empty() else 1)
