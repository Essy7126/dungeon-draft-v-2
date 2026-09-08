extends Node
## Production scenes and button signals; isolated save, no simulated victory.
const OUTPUT := "res://artifacts/project_audit/2026-09-08/menu_navigation"
const TITLE := "res://ui/TitreEcran.tscn"
const SELECTION := "res://ui/selection/CharacterSelectionScreen.tscn"
const INTRO := "res://cinematics/intro/intro_cinematic.tscn"
const SANCTUARY := "res://hub/sanctuary_prototype/SanctuaryPrototype.tscn"
var observer := false
var _checks := 0
var _failures: Array[String] = []
var _captures: Array[String] = []
var _user_save := ""
var _user_inventory := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if observer:
		_run.call_deferred()
	else:
		var persistent := Node.new()
		persistent.set_script(get_script())
		persistent.set("observer", true)
		get_tree().root.add_child.call_deferred(persistent)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	_user_save = _hash(ExpeditionSaveService.SAVE_PATH)
	_user_inventory = _hash("user://inventory_equipment_v1.json")
	GameManager.expedition_save_path = OUTPUT.path_join("checkpoint_%d.json" % Time.get_ticks_usec())
	_check(GameManager.start_expedition(81723), "Fresh expedition starts")
	if not await _wait_combat():
		await _finish(); return
	await _pause_action(&"return_to_title")
	if not await _wait_scene(TITLE):
		await _finish(); return
	var checkpoint := _hash(GameManager.expedition_save_path)
	_check(checkpoint != "absent", "Return to title preserves the checkpoint")
	for resolution in [Vector2i(1200, 896), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		get_window().size = resolution
		await _settle()
		var title := get_tree().current_scene
		title.call("_finish_intro")
		await _settle()
		var actions: Array[Control] = []
		for child in title.get_node("UI/Boutons").get_children():
			if child is Button and child.visible:
				actions.append(child)
		_check(actions.size() == 4, "Title exposes resume, new game, Sanctuary and exit")
		_check_bounds(actions, "Title " + str(resolution))
		var resume := title.find_child("BoutonReprendreCatabase", true, false) as Button
		_check(resume != null and resume.has_focus(), "Saved game receives initial focus")
		await _capture("title_%dx%d" % [resolution.x, resolution.y])
		(title.get_node("UI/Boutons/BoutonNouvellePartie") as Button).pressed.emit()
		if not await _wait_scene(SELECTION):
			await _finish(); return
		var selection := get_tree().current_scene as CharacterSelectionScreen
		await _settle()
		_check(_hash(GameManager.expedition_save_path) == checkpoint, "Browsing heroes preserves the checkpoint")
		_check_bounds(_selection_actions(selection), "Selection " + str(resolution))
		await _capture("selection_%dx%d" % [resolution.x, resolution.y])
		selection.start_button.pressed.emit()
		await _settle()
		var dialog := selection.get_node_or_null("ReplaceExpeditionConfirmation") as ConfirmationDialog
		if not _check(dialog != null and dialog.visible, "Starting Catabase asks before replacing"):
			await _finish(); return
		_check(dialog.get_cancel_button().has_focus(), "Keeping the save receives initial confirmation focus")
		_check(_hash(GameManager.expedition_save_path) == checkpoint, "Confirmation does not write or delete")
		await _capture("confirmation_%dx%d" % [resolution.x, resolution.y])
		dialog.get_cancel_button().pressed.emit()
		await _settle()
		_check(not dialog.visible and selection.start_button.has_focus(), "Cancel closes confirmation and restores focus")
		_check(_hash(GameManager.expedition_save_path) == checkpoint, "Cancel preserves the checkpoint")
		selection.request_back()
		if not await _wait_scene(TITLE):
			await _finish(); return
	# The painted Achilles variant uses the same protected expedition entry.
	var title := get_tree().current_scene
	title.call("_finish_intro")
	(title.get_node("UI/Boutons/BoutonNouvellePartie") as Button).pressed.emit()
	if not await _wait_scene(SELECTION):
		await _finish(); return
	var selection := get_tree().current_scene as CharacterSelectionScreen
	selection.select_character(1)
	selection.start_button.pressed.emit()
	await _settle()
	var dialog := selection.get_node_or_null("ReplaceExpeditionConfirmation") as ConfirmationDialog
	if not _check(dialog != null and dialog.visible, "Painted Achilles is also protected"):
		await _finish(); return
	dialog.get_ok_button().pressed.emit()
	if not await _wait_scene(INTRO):
		await _finish(); return
	_check(_hash(GameManager.expedition_save_path) == checkpoint, "Old checkpoint survives through the cinematic")
	var skip := get_tree().current_scene.get("skip_button") as Button
	_check(skip != null and not skip.disabled, "Cinematic skip is available")
	if skip != null:
		skip.pressed.emit()
	if not await _wait_combat():
		await _finish(); return
	_check(_hash(GameManager.expedition_save_path) != checkpoint, "Confirmed replacement writes its valid entry")
	_check(ExpeditionSaveService.read_snapshot(GameManager.expedition_save_path).get("hero_visual_variants", {}) == {"achilles": "painted_g"}, "Confirmed painted appearance persists")
	await _pause_action(&"abandon")
	if not await _wait_scene(TITLE):
		await _finish(); return
	_check(not FileAccess.file_exists(GameManager.expedition_save_path), "Confirmed abandon removes this expedition checkpoint")
	_check(get_tree().current_scene.find_child("BoutonReprendreCatabase", true, false) == null, "Abandoned expedition has no resume button")
	# An unavailable save destination must keep the cinematic under a retry dialog.
	(get_tree().current_scene.get_node("UI/Boutons/BoutonNouvellePartie") as Button).pressed.emit()
	if not await _wait_scene(SELECTION):
		await _finish(); return
	(get_tree().current_scene as CharacterSelectionScreen).start_button.pressed.emit()
	if not await _wait_scene(INTRO):
		await _finish(); return
	var blocked_temp := GameManager.expedition_save_path + ".tmp"
	_check(DirAccess.make_dir_absolute(blocked_temp) == OK, "Create isolated write-failure fixture")
	(get_tree().current_scene.get("skip_button") as Button).pressed.emit()
	await get_tree().create_timer(2.0).timeout
	_check(get_tree().current_scene.scene_file_path == INTRO, "Save failure does not leave the pending cinematic")
	_check(GameManager.get_expedition_save_status().get("pending", false), "First entry reports pending save")
	_check(GameManager.run_active and GameManager.expedition != null, "Prepared expedition remains in memory")
	var retry := get_tree().root.find_child("ExpeditionSaveFailure", true, false) as ConfirmationDialog
	if not _check(retry != null and retry.visible, "Real save retry dialog is visible over the cinematic"):
		DirAccess.remove_absolute(blocked_temp)
		await _finish(); return
	await _capture("cinematic_save_retry")
	_check(DirAccess.remove_absolute(blocked_temp) == OK, "Remove isolated write-failure fixture")
	retry.get_ok_button().pressed.emit()
	if not await _wait_combat():
		await _finish(); return
	_check(not bool(GameManager.get_expedition_save_status().get("pending", false)), "Retry commits entry and starts combat")
	await _pause_action(&"abandon")
	if not await _wait_scene(TITLE):
		await _finish(); return
	GameManager.set_reduced_motion_enabled(true)
	get_tree().reload_current_scene()
	if not await _wait_scene(TITLE):
		await _finish(); return
	_check(not bool(get_tree().current_scene.get("_intro_en_cours")), "Reduced motion opens the title without waiting")
	(get_tree().current_scene.find_child("BoutonSanctuaire", true, false) as Button).pressed.emit()
	_check(await _wait_scene(SANCTUARY), "Title Sanctuary button opens the real hub")
	await _finish()


func _pause_action(action: StringName) -> void:
	var persistent := GameManager.get_persistent_run_ui()
	if not _check(persistent != null and persistent.open_pause_menu(), "Production pause opens"):
		return
	await _settle()
	var menu := persistent.get_pause_menu()
	menu.get_action_button(action).pressed.emit()
	await _settle()
	_check(menu.has_open_confirmation(), "Pause action asks for confirmation")
	menu.get_confirmation_dialog().get_ok_button().pressed.emit()


func _wait_scene(path: String) -> bool:
	var deadline := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.05).timeout
		var scene := get_tree().current_scene
		if scene != null and scene.scene_file_path == path:
			await _settle()
			return true
	return _check(false, "Timed out waiting for " + path)


func _wait_combat() -> bool:
	var deadline := Time.get_ticks_msec() + 35000
	while Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.05).timeout
		var battle := get_tree().current_scene
		if battle == null or battle.get("runtime_ready_state") != true:
			continue
		var deployment = battle.get("_deployment")
		if deployment != null and deployment.is_active():
			deployment.on_cell_clicked(GameManager.get_current_room().hero_spawn_zone[0])
			continue
		var persistent := GameManager.get_persistent_run_ui()
		if persistent != null and bool(persistent.call("_combat_context_allows_run_modal")):
			await _settle()
			return true
	return _check(false, "Combat becomes ready for menus")


func _check_bounds(controls: Array[Control], label: String) -> void:
	var viewport := get_viewport().get_visible_rect()
	for i in controls.size():
		var rect := controls[i].get_global_rect()
		_check(viewport.encloses(rect), label + ": button remains inside viewport")
		_check(rect.size.y >= 40, label + ": button remains easy to target")
		for j in range(i):
			_check(not rect.intersects(controls[j].get_global_rect()), label + ": buttons do not overlap")


func _selection_actions(selection: Control) -> Array[Control]:
	var actions: Array[Control] = []
	for button in selection.find_children("*", "Button", true, false):
		if not button.is_visible_in_tree():
			continue
		var ancestor := button.get_parent()
		var in_roster := false
		while ancestor != selection and ancestor != null:
			in_roster = in_roster or ancestor.name == "HeroRosterScroll"
			ancestor = ancestor.get_parent()
		if not in_roster:
			actions.append(button)
	return actions


func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var path := OUTPUT.path_join(label + ".png")
	_check(get_viewport().get_texture().get_image().save_png(path) == OK, "Capture " + label)
	_captures.append(path)


func _settle() -> void:
	await get_tree().create_timer(0.45).timeout


func _hash(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "absent"


func _check(ok: bool, message: String) -> bool:
	_checks += 1
	if not ok:
		_failures.append(message)
	return ok


func _finish() -> void:
	get_tree().paused = false
	GameManager.cleanup_run_state()
	await _settle()
	_check(_hash(ExpeditionSaveService.SAVE_PATH) == _user_save, "Player expedition save unchanged")
	_check(_hash("user://inventory_equipment_v1.json") == _user_inventory, "Player inventory save unchanged")
	var report := {"checks": _checks, "failures": _failures, "captures": _captures,
		"scope": "Real production scene transitions and button signals; initial seed and deployment are fixtures; no simulated victory."}
	var file := FileAccess.open(OUTPUT.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print("MENU_NAVIGATION ", JSON.stringify(report))
	get_tree().quit(0 if _failures.is_empty() else 1)
