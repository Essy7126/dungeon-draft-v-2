extends GutTest
## Run-management access must preserve the fight and remain usable at small sizes.

class CombatContext extends Node:
	var active_unit: Unit
	var external_locks: Dictionary = {}
	func get_active_unit(): return active_unit
	func get_combat_presentation_snapshot() -> Dictionary: return {"phase_name": &"PLAYER_IDLE"}
	func set_external_interaction_lock(source: StringName, locked: bool) -> void:
		if locked: external_locks[source] = true
		else: external_locks.erase(source)
	func _on_move_pressed() -> void: pass
	func _on_attack_pressed() -> void: pass
	func _on_spell_pressed(_spell) -> void: pass
	func _on_end_turn_pressed() -> void: pass
	func _on_item_activation_requested(_instance_id: StringName) -> void: pass

var _window_size: Vector2i
var _save_path: String
var _previous_save_path: String

func before_each() -> void:
	_window_size = get_window().size
	_previous_save_path = GameManager.expedition_save_path
	GameManager.cleanup_run_state()
	await get_tree().process_frame
	_save_path = "res://artifacts/run_access_test_%d.json" % Time.get_ticks_usec()
	GameManager.expedition_save_path = _save_path
	var run := ExpeditionRunFactory.create(2401)
	var resolution := GameManager.resolve_run_hero_data(run, false)
	assert_true(GameManager._prepare_preconfigured_run(run, resolution.heroes))
	GameManager.expedition = ExpeditionSession.new()
	GameManager.expedition.initialize(GameManager.get_character_state(&"achilles"), 2401)
	assert_true(GameManager.expedition.enter("d01_0"))

func after_each() -> void:
	GameManager.cleanup_run_state()
	GameManager.expedition_save_path = _previous_save_path
	get_window().size = _window_size
	if FileAccess.file_exists(_save_path): DirAccess.remove_absolute(_save_path)
	await get_tree().process_frame

func test_unillustrated_items_get_category_symbols_but_empty_slots_stay_empty() -> void:
	assert_null(InventoryItemTile.presentation_icon(null))
	var icons: Array[Texture2D] = []
	for category in ItemDefinition.Category.values():
		var definition := ItemDefinition.new()
		definition.category = category
		var fallback := InventoryItemTile.presentation_icon(definition)
		assert_not_null(fallback, "Category %d has a visible placeholder" % category)
		assert_same(InventoryItemTile.presentation_icon(definition), fallback)
		icons.append(fallback)
	assert_ne(icons[0], icons[1], "Weapon and armour have different symbols")
	var tile := load("res://ui/inventory/InventoryItemTile.tscn").instantiate() as InventoryItemTile
	add_child_autofree(tile)
	tile.configure_equipment(ItemDefinition.EquipmentSlot.ACCESSORY, null, null, false)
	assert_false(tile.get_node("%IconFrame").visible, "An empty equipped slot does not look like an item")


func test_characteristics_button_owns_modal_and_restores_combat() -> void:
	var ui := GameManager.get_persistent_run_ui()
	var context := CombatContext.new()
	context.active_unit = GameManager.get_character_state(&"achilles").unit
	add_child_autofree(context)
	ui.bind_combat_context(context)
	ui.set_ui_mode(PersistentRunUI.RunUIMode.COMBAT)
	var hud = ui.combat_hud
	hud.update_info(context.active_unit)
	hud.set_player_controls_enabled(true)
	await _settle()
	var button := hud.get_node("%AttributesButton") as Button
	assert_true(button.is_visible_in_tree())
	assert_false(button.disabled)
	assert_not_null(button.icon)
	assert_eq((button.shortcut.events[0] as InputEventKey).physical_keycode, KEY_P)
	var before := GameManager.expedition.to_snapshot()
	button.pressed.emit()
	await _settle()
	var inspection := ui.get("_expedition_inspection") as Control
	assert_not_null(inspection)
	assert_eq(str(inspection.get("_page")), "attributes")
	assert_true(bool(inspection.get("inspection_only")))
	assert_true(ui.has_active_modal())
	assert_true(context.external_locks.has(&"run_modal"))
	assert_false(bool(ui.get("_hud_port").are_controls_enabled()))
	assert_false(ui.open_inventory_screen(), "A second modal cannot steal ownership")
	assert_eq(GameManager.expedition.to_snapshot(), before, "Inspecting attributes is read-only")
	ui.call("_close_expedition_inspection")
	await _settle()
	assert_false(ui.has_active_modal())
	assert_true(context.external_locks.is_empty())
	assert_true(bool(ui.get("_hud_port").are_controls_enabled()))
	GameManager.expedition = null
	hud.update_info(context.active_unit)
	assert_false(button.visible, "No Catabase attributes entry in other run modes")

func test_inventory_panel_and_close_fit_at_960_and_1200() -> void:
	var ui := GameManager.get_persistent_run_ui()
	ui.set_ui_mode(PersistentRunUI.RunUIMode.NON_COMBAT)
	for width in [960, 1200]:
		get_window().size = Vector2i(width, 720)
		assert_true(ui.open_inventory_screen(&"achilles"))
		var inventory := ui.get_inventory_screen()
		inventory.call("_apply_responsive_layout")
		await _settle()
		var bounds := Rect2(Vector2.ZERO, Vector2(width, 720)).grow(1.0)
		assert_true(bounds.encloses(inventory.get_node("%Panel").get_global_rect()), "Inventory fits at %d: %s" % [width, inventory.get_node("%Panel").get_global_rect()])
		assert_true(bounds.encloses(inventory.get_node("%CloseButton").get_global_rect()), "Close stays reachable at %d" % width)
		assert_eq(inventory.get_node("%InventoryGrid").columns, 2 if width < 1180 else 3)
		assert_false(inventory.get_node("%HeroSelector").visible, "The solo run has no unnecessary hero choice")
		assert_false("STATISTIQUES ACTUELLES" in inventory.get_node("%StatsSummary").text)
		ui.close_inventory_screen()

func test_four_hud_utilities_do_not_overlap_at_small_resolutions() -> void:
	var ui := GameManager.get_persistent_run_ui()
	ui.set_ui_mode(PersistentRunUI.RunUIMode.COMBAT)
	var hud = ui.combat_hud
	hud.update_info(GameManager.get_character_state(&"achilles").unit)
	hud.set_player_controls_enabled(true)
	for width in [960, 1200]:
		get_window().size = Vector2i(width, 720)
		hud.call("_apply_layout_metrics")
		await _settle()
		var previous := Rect2()
		for id in ["InventoryButton", "SkillsButton", "AttributesButton", "MapButton"]:
			var button := hud.get_node("%" + id) as Button
			assert_true(button.visible, id)
			var rect := button.get_global_rect()
			assert_false(rect.intersects((hud.get_node("%EndTurnButton") as Control).get_global_rect()), "%s overlaps end turn at %d" % [id, width])
			assert_false(rect.intersects(previous), "%s overlaps previous at %d" % [id, width])
			assert_true(Rect2(Vector2.ZERO, Vector2(width, 720)).grow(1.0).encloses(rect), "%s leaves viewport at %d: %s" % [id, width, rect])
			previous = rect

func _settle() -> void:
	for frame in 5: await get_tree().process_frame
