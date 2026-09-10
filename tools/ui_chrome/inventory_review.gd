extends Node
## Prepared Catabase inventory, actual controls/services; no simulated campaign victory.
var _screen: InventoryScreen
var _output := ""
var _review_size := Vector2i.ZERO
var _checks := 0
var _failures: Array[String] = []
var _captures: Array[String] = []


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("review_resolution="):
			var dimensions := argument.trim_prefix("review_resolution=").split("x")
			_review_size = Vector2i(int(dimensions[0]), int(dimensions[1]))
	call_deferred("_run")


func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("output_dir="):
			_output = argument.trim_prefix("output_dir=")
	_check(not _output.is_empty(), "Output directory supplied")
	if _output.is_empty():
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_output)
	var run := ExpeditionRunFactory.create(7642, { "achilles": "painted_g" })
	var resolution := RunHeroResolver.resolve_runtime_hero_data(run, false)
	_check(resolution.is_valid(), "Canonical Catabase hero resolves")
	_check(
		GameManager._prepare_preconfigured_run(run, resolution.heroes),
		"Prepared run uses real catalog and equipment services",
	)
	GameManager.set_run_ui_mode(PersistentRunUI.RunUIMode.NON_COMBAT)
	for id in CatabasePaintedIconCatalog.ITEM_IDS:
		_check(bool(GameManager.run_inventory.try_add(StringName(id), 1).get("success", false)), "Fixture grant "
			+ id)
	for id in ["catabase_levier", "catabase_cuirasse", "catabase_sandales"]:
		var instance := _find_item(id)
		var definition := GameManager.item_catalog.get_definition(instance.definition_id)
		_check(
			bool(
				GameManager
				.equip_inventory_item(instance.instance_id, &"achilles", definition.equipment_slot)
				.get("success", false)
			),
			"Equip " + id,
		)
	var persistent := GameManager.get_persistent_run_ui()
	_check(
		persistent.open_inventory_screen(&"achilles"),
		"Inventory opens with real modal ownership",
	)
	_screen = persistent.get_inventory_screen()
	# This fixture prepares a run without starting a combat/ExpeditionSession.
	CatabaseUITheme.apply_inventory(_screen, true)
	await _settle()
	await _capture("inventory_overview")
	var chosen := _find_item("catabase_lame_sang")
	for child in (_screen.get_node("%InventoryGrid") as GridContainer).get_children():
		var tile := child as InventoryItemTile
		if tile.instance_id == chosen.instance_id:
			await _click(tile)
	_check(
		(_screen.get_node("%DetailName") as Label).text
		== GameManager.item_catalog.get_definition(chosen.definition_id).display_name,
		"Mouse selects the actual item",
	)
	await _capture("inventory_selected")
	var search := _screen.find_child("InventorySearch", true, false) as LineEdit
	search.text = "lame"
	search.text_changed.emit(search.text)
	await _settle()
	await _capture("inventory_search")
	search.text = "zzzz"
	search.text_changed.emit(search.text)
	await _settle()
	_check(
		(_screen.find_child("SearchCount", true, false) as Label).text == "Aucun objet trouvé",
		"Empty results are explicit",
	)
	await _capture("inventory_no_results")
	search.text = ""
	search.text_changed.emit(search.text)
	var equip := _screen.get_node("%EquipButton") as Button
	var before_action := equip.get_global_rect()
	(_screen.get_node("%DetailDescription") as Label).text += "\n".repeat(25) + "Description longue de vérification."
	await _settle()
	(_screen.get_node("%DetailScroll") as ScrollContainer).scroll_vertical = 10000
	await _settle()
	_check(
		equip.get_global_rect() == before_action,
		"Action position stays fixed while details scroll",
	)
	await _capture("inventory_scrolled")
	await _click(equip)
	var equipped := GameManager.get_character_state(&"achilles").equipment_loadout.get_item(
		ItemDefinition.EquipmentSlot.WEAPON
	)
	_check(
		equipped != null and equipped.instance_id == chosen.instance_id,
		"Actual Equip click uses the selected instance",
	)
	await _capture("inventory_equipped")
	await _click(_screen.get_node("%UnequipButton") as Button)
	_check(
		GameManager.get_character_state(&"achilles").equipment_loadout.get_item(
			ItemDefinition.EquipmentSlot.WEAPON
		) == null,
		"Actual Unequip click returns item to bag",
	)
	await _click(_screen.get_node("%CloseButton") as Button)
	_check(not persistent.has_active_modal(), "Closing releases modal ownership")
	_screen = null
	GameManager.cleanup_run_state()
	await _settle()
	var file := FileAccess.open(_output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(
		JSON.stringify(
			{
				"checks": _checks,
				"failures": _failures,
				"captures": _captures,
				"scope": "Prepared Catabase hero/catalog and fixture item grants; actual inventory modal, mouse selection, equip/unequip/close, search and layout. No campaign transition or combat claim.",
			},
			"\t",
		)
	)
	file = null
	print("Inventory chrome: %d checks, %d failures" % [_checks, _failures.size()])
	for failure in _failures:
		printerr(failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _find_item(id: String) -> ItemInstance:
	for item in GameManager.run_inventory.get_slots():
		if item != null and String(item.definition_id) == id:
			return item
	return null


func _click(button: Button) -> void:
	_check(button.is_visible_in_tree() and not button.disabled, "Reachable button " + button.name)
	var point := button.get_global_rect().get_center()
	var move := InputEventMouseMotion.new()
	move.position = point
	move.global_position = point
	Input.parse_input_event(move)
	await get_tree().process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		event.global_position = point
		Input.parse_input_event(event)
		await get_tree().process_frame
	await _settle()


func _settle() -> void:
	if _review_size != Vector2i.ZERO and get_window().size != _review_size:
		get_window().mode = Window.MODE_WINDOWED
		get_window().size = _review_size
	for i in range(10):
		await get_tree().process_frame
	await get_tree().create_timer(0.18).timeout


func _capture(label: String) -> void:
	var viewport := get_viewport().get_visible_rect()
	for name in ["Panel", "EquipmentPanel", "BagPanel", "RightPanel", "CloseButton"]:
		var control := _screen.find_child(name, true, false) as Control
		_check(control != null and viewport.grow(1).encloses(control.get_global_rect()), label
			+ " contained: " + name)
	for name in ["EquipButton", "UseButton", "UnequipButton"]:
		var button := _screen.get_node("%" + name) as Button
		if button.visible:
			_check(
				viewport.encloses(button.get_global_rect()),
				label + " action on screen: " + name,
			)
	var grid := _screen.get_node("%InventoryGrid") as GridContainer
	_check(grid.columns >= 4, label + " compact grid has at least four columns")
	await RenderingServer.frame_post_draw
	_check(
		_review_size == Vector2i.ZERO or Vector2i(get_viewport().get_texture().get_size()) == _review_size,
		label + " requested resolution",
	)
	var shot := get_viewport().get_texture().get_image()
	_check(shot.save_png(_output.path_join(label + ".png")) == OK, label + " screenshot saved")
	_captures.append(label)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
