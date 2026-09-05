class_name InventoryScreen
extends Control

signal screen_closed

const ITEM_TILE_SCENE := preload("res://ui/inventory/InventoryItemTile.tscn")

@onready var _title: Label = %Title
@onready var _capacity_label: Label = %CapacityLabel
@onready var _hero_selector: OptionButton = %HeroSelector
@onready var _inventory_grid: GridContainer = %InventoryGrid
@onready var _equipment_list: VBoxContainer = %EquipmentList
@onready var _detail_name: Label = %DetailName
@onready var _detail_icon: TextureRect = %DetailIcon
@onready var _detail_rarity: Label = %DetailRarity
@onready var _detail_description: Label = %DetailDescription
@onready var _modifier_summary: Label = %ModifierSummary
@onready var _stats_summary: Label = %StatsSummary
@onready var _feedback: Label = %Feedback
@onready var _equip_button: Button = %EquipButton
@onready var _use_button: Button = %UseButton
@onready var _unequip_button: Button = %UnequipButton
@onready var _close_button: Button = %CloseButton
@onready var _panel: PanelContainer = %Panel
@onready var _detail_scroll: ScrollContainer = %DetailScroll

var _manager = null
var _hero_ids: Array[StringName] = []
var _selected_character_id: StringName = &""
var _selected_instance_id: StringName = &""
var _selected_equipment_slot := ItemDefinition.EquipmentSlot.NONE
var _test_viewport_size := Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	PremiumUI.apply(self)
	_close_button.pressed.connect(close_screen)
	_hero_selector.item_selected.connect(_on_hero_selected)
	_equip_button.pressed.connect(_on_equip_pressed)
	_use_button.pressed.connect(_on_use_pressed)
	_unequip_button.pressed.connect(_on_unequip_pressed)
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()
	hide()


func open_for_character(character_id: StringName, manager = GameManager) -> bool:
	if manager == null \
			or not bool(manager.get("run_active")) \
			or manager.get_run_inventory() == null \
			or manager.get_item_catalog() == null:
		return false
	_disconnect_manager()
	_manager = manager
	_connect_manager()
	_populate_heroes(character_id)
	if _selected_character_id == &"":
		_disconnect_manager()
		return false
	_selected_instance_id = &""
	_selected_equipment_slot = ItemDefinition.EquipmentSlot.NONE
	_feedback.text = ""
	_detail_scroll.scroll_vertical = 0
	show()
	move_to_front()
	_refresh()
	_close_button.grab_focus.call_deferred()
	return true


func close_screen() -> void:
	if not visible:
		return
	hide()
	_disconnect_manager()
	_selected_instance_id = &""
	_selected_equipment_slot = ItemDefinition.EquipmentSlot.NONE
	screen_closed.emit()


func is_open() -> bool:
	return visible


func get_selected_character_id() -> StringName:
	return _selected_character_id


func _exit_tree() -> void:
	_disconnect_manager()
	if get_viewport().size_changed.is_connected(_apply_responsive_layout):
		get_viewport().size_changed.disconnect(_apply_responsive_layout)


func _apply_responsive_layout() -> void:
	if not is_node_ready() or _panel == null:
		return
	var viewport_size := (
		_test_viewport_size
		if _test_viewport_size != Vector2.ZERO
		else get_viewport_rect().size
	)
	_panel.custom_minimum_size = Vector2(
		clampf(viewport_size.x - 48.0, 960.0, 1240.0),
		clampf(viewport_size.y - 40.0, 650.0, 820.0),
	)
	_inventory_grid.columns = 3


func apply_viewport_size_for_test(viewport_size: Vector2) -> void:
	_test_viewport_size = viewport_size
	size = viewport_size
	_apply_responsive_layout()


func get_layout_snapshot() -> Dictionary:
	var detail_scrollbar := _detail_scroll.get_v_scroll_bar()
	return {
		"screen_rect": get_global_rect(),
		"panel_global": _panel.get_global_rect(),
		"panel_minimum_size": _panel.custom_minimum_size,
		"detail_scroll_global": _detail_scroll.get_global_rect(),
		"detail_scroll_max": detail_scrollbar.max_value,
		"detail_scroll_page": detail_scrollbar.page,
		"inventory_columns": _inventory_grid.columns,
	}


func _connect_manager() -> void:
	if _manager == null:
		return
	var callback := Callable(self, "_on_manager_state_changed")
	for signal_value in [
		_manager.inventory_changed,
		_manager.equipment_changed,
		_manager.item_used,
	]:
		var state_signal := signal_value as Signal
		if not state_signal.is_connected(callback):
			state_signal.connect(callback)


func _disconnect_manager() -> void:
	if _manager == null:
		return
	var callback := Callable(self, "_on_manager_state_changed")
	for signal_value in [
		_manager.inventory_changed,
		_manager.equipment_changed,
		_manager.item_used,
	]:
		var state_signal := signal_value as Signal
		if state_signal.is_connected(callback):
			state_signal.disconnect(callback)
	_manager = null


func _populate_heroes(preferred_id: StringName) -> void:
	_hero_selector.clear()
	_hero_ids.clear()
	var selected_index := 0
	for state in _manager.get_ordered_character_states():
		if state == null or state.unit == null:
			continue
		var index := _hero_ids.size()
		_hero_ids.append(state.character_id)
		_hero_selector.add_item(state.unit.unit_name)
		if state.character_id == preferred_id:
			selected_index = index
	if _hero_ids.is_empty():
		_selected_character_id = &""
		return
	_hero_selector.select(selected_index)
	_selected_character_id = _hero_ids[selected_index]


func _on_hero_selected(index: int) -> void:
	if index < 0 or index >= _hero_ids.size():
		return
	_selected_character_id = _hero_ids[index]
	_selected_equipment_slot = ItemDefinition.EquipmentSlot.NONE
	_feedback.text = ""
	_detail_scroll.scroll_vertical = 0
	_refresh()


func _on_manager_state_changed(_payload = {}) -> void:
	if visible:
		_refresh()


func _refresh() -> void:
	if _manager == null:
		return
	var inventory: RunInventory = _manager.get_run_inventory()
	var catalog: ItemCatalog = _manager.get_item_catalog()
	var state: CharacterRunState = _manager.get_character_state(
		_selected_character_id
	)
	if inventory == null or catalog == null or state == null:
		close_screen()
		return
	_title.text = "INVENTAIRE"
	_capacity_label.text = "%d / %d" % [
		inventory.capacity - inventory.get_empty_slot_count(),
		inventory.capacity,
	]
	_rebuild_inventory(inventory, catalog)
	_rebuild_equipment(state, catalog)
	_refresh_details(state, inventory, catalog)


func _rebuild_inventory(inventory: RunInventory, catalog: ItemCatalog) -> void:
	_ensure_inventory_tile_count(inventory.capacity)
	var state: CharacterRunState = (
		_manager.get_character_state(_selected_character_id)
		if _manager != null else null
	)
	for slot_index in range(inventory.capacity):
		var instance := inventory.get_slot(slot_index)
		var definition := (
			catalog.get_definition(instance.definition_id)
			if instance != null else null
		)
		var compatible := (
			definition == null
			or state == null
			or definition.is_compatible_with(state.character_id)
		)
		var tile := _inventory_grid.get_child(slot_index) as InventoryItemTile
		tile.configure_inventory(
			slot_index,
			instance,
			definition,
			instance != null and instance.instance_id == _selected_instance_id,
			compatible,
		)


func _rebuild_equipment(
		state: CharacterRunState,
		catalog: ItemCatalog
	) -> void:
	_ensure_equipment_tile_count(EquipmentLoadout.EQUIPMENT_SLOTS.size())
	for index in EquipmentLoadout.EQUIPMENT_SLOTS.size():
		var slot: int = EquipmentLoadout.EQUIPMENT_SLOTS[index]
		var instance := state.equipment_loadout.get_item(slot)
		var definition := (
			catalog.get_definition(instance.definition_id)
			if instance != null
			else null
		)
		var tile := _equipment_list.get_child(index) as InventoryItemTile
		tile.configure_equipment(
			slot,
			instance,
			definition,
			slot == _selected_equipment_slot,
		)


func _refresh_details(
		state: CharacterRunState,
		inventory: RunInventory,
		catalog: ItemCatalog
	) -> void:
	var instance: ItemInstance = null
	if _selected_instance_id != &"":
		instance = inventory.get_instance(_selected_instance_id)
		if instance == null:
			_selected_instance_id = &""
	if instance == null and _selected_equipment_slot != ItemDefinition.EquipmentSlot.NONE:
		instance = state.equipment_loadout.get_item(_selected_equipment_slot)
	var definition := (
		catalog.get_definition(instance.definition_id)
		if instance != null
		else null
	)
	_detail_name.text = definition.display_name if definition != null else "Sélectionnez un objet"
	_detail_icon.texture = InventoryItemTile.presentation_icon(definition)
	_detail_rarity.text = (
		PremiumUI.rarity_label(definition.rarity)
		if definition != null else ""
	)
	_detail_rarity.modulate = (
		PremiumUI.rarity_color(definition.rarity)
		if definition != null else Color.WHITE
	)
	_detail_description.text = definition.description if definition != null else (
		"Choisissez un objet du sac ou un emplacement équipé."
	)
	_modifier_summary.text = _modifier_text(definition)
	_stats_summary.text = _stats_text(state.unit)
	var from_inventory := instance != null and _selected_instance_id != &""
	_equip_button.visible = definition != null and definition.is_equippable() and from_inventory
	_equip_button.disabled = (
		definition == null
		or not definition.is_compatible_with(state.character_id)
	)
	_use_button.visible = definition != null and definition.is_consumable() and from_inventory
	_use_button.disabled = definition == null or not definition.is_compatible_with(state.character_id)
	_unequip_button.visible = (
		_selected_equipment_slot != ItemDefinition.EquipmentSlot.NONE
		and instance != null
	)
	_unequip_button.disabled = not _unequip_button.visible
	if definition != null and definition.is_relic():
		_equip_button.hide()
		_use_button.hide()
		_unequip_button.hide()
	_refresh_action_truth(state, inventory, definition, from_inventory)


func _select_inventory_item(instance_id: StringName) -> void:
	_selected_instance_id = instance_id
	_selected_equipment_slot = ItemDefinition.EquipmentSlot.NONE
	_feedback.text = ""
	_detail_scroll.scroll_vertical = 0
	_refresh()


func _select_equipment_slot(slot: int) -> void:
	_selected_instance_id = &""
	_selected_equipment_slot = slot
	_feedback.text = ""
	_detail_scroll.scroll_vertical = 0
	_refresh()


func _on_equip_pressed() -> void:
	var inventory: RunInventory = _manager.get_run_inventory()
	var instance := inventory.get_instance(_selected_instance_id)
	var definition: ItemDefinition = (
		_manager.get_item_catalog().get_definition(instance.definition_id)
		if instance != null
		else null
	)
	if definition == null:
		return
	var result: Dictionary = _manager.equip_inventory_item(
		_selected_instance_id,
		_selected_character_id,
		definition.equipment_slot,
	)
	_feedback.text = (
		"Objet équipé."
		if result.get("success", false)
		else str(result.get("error", "Équipement impossible."))
	)
	_set_feedback_state(bool(result.get("success", false)))
	if result.get("success", false):
		_selected_instance_id = &""
		_selected_equipment_slot = definition.equipment_slot
	_refresh()


func _on_use_pressed() -> void:
	var result: Dictionary = _manager.use_inventory_item(
		_selected_instance_id,
		_selected_character_id,
	)
	_feedback.text = (
		"Objet utilisé."
		if result.get("success", false)
		else str(result.get("error", "Utilisation impossible."))
	)
	_set_feedback_state(bool(result.get("success", false)))
	if result.get("success", false):
		_selected_instance_id = &""
	_refresh()


func _on_unequip_pressed() -> void:
	var result: Dictionary = _manager.unequip_inventory_item(
		_selected_character_id,
		_selected_equipment_slot,
	)
	_feedback.text = (
		"Objet rangé dans le sac."
		if result.get("success", false)
		else str(result.get("error", "Retrait impossible."))
	)
	_set_feedback_state(bool(result.get("success", false)))
	if result.get("success", false):
		_selected_equipment_slot = ItemDefinition.EquipmentSlot.NONE
	_refresh()


func _modifier_text(definition: ItemDefinition) -> String:
	if definition == null:
		return ""
	if definition.is_relic():
		var registry := RelicEffectRegistry.new()
		var lines: Array[String] = ["ACTIVE POUR LA RUN", "Effets réactifs :"]
		for effect in definition.reactive_effects:
			if effect != null:
				lines.append("• %s" % registry.summarize(effect))
		return "\n".join(lines)
	if definition.is_consumable():
		match definition.use_effect:
			ItemDefinition.UseEffect.HEAL_FLAT:
				return "Effet : rend %d PV" % int(round(definition.use_value))
			ItemDefinition.UseEffect.RESTORE_AP_FLAT:
				return "Effet : rend %d PA" % int(round(definition.use_value))
			_:
				return "Effet consommable."
	if definition.stat_modifiers.is_empty():
		return "Aucun bonus de statistique."
	var lines: Array[String] = []
	for modifier in definition.stat_modifiers:
		var value_text := (
			"%+.0f%%" % (modifier.value * 100.0)
			if modifier.modifier_type == ItemStatModifierData.ModifierType.PERCENT
			else "%+.1f" % modifier.value
		)
		lines.append("%s %s" % [_stat_label(modifier.stat_id), value_text])
	return "Bonus :\n" + "\n".join(lines)


func _stats_text(unit: Unit) -> String:
	if unit == null:
		return ""
	return "STATISTIQUES ACTUELLES · Niv. %d\nPV %d/%d · %s %d · Initiative %.0f\nPA %d · PM %d · Armure %.0f\nRés. magique %.0f · Rés. glace %.0f\nCritique %.0f%% · Force %.0f" % [
		CombatGlossary.champion_level(unit),
		unit.current_hp,
		unit.max_hp.get_int(),
		"Prouesse" if CombatGlossary.uses_champion_progression(unit) else "Attaque",
		unit.attack_power.get_int(),
		unit.initiative.get_value(),
		unit.max_ap.get_int(),
		unit.max_mp.get_int(),
		unit.armure.get_value(),
		unit.resist_magique.get_value(),
		unit.get_resistance_value(Spell.Element.ICE) * 100.0,
		unit.crit_chance.get_value() * 100.0,
		unit.force.get_value(),
	]


func _stat_label(stat_id: StringName) -> String:
	match stat_id:
		&"max_hp": return "PV maximum"
		&"attack_power": return "Attaque"
		&"armure": return "Armure"
		&"resist_magique": return "Résistance magique"
		&"initiative": return "Initiative"
		&"max_ap": return "PA maximum"
		&"max_mp": return "PM maximum"
		&"esquive": return "Esquive"
		&"crit_chance": return "Chance critique"
		&"crit_multi": return "Dégâts critiques"
		&"force": return "Force"
		&"resistance_ice": return "Résistance glace"
		_: return str(stat_id)


func _ensure_inventory_tile_count(wanted_count: int) -> void:
	while _inventory_grid.get_child_count() < wanted_count:
		var tile := ITEM_TILE_SCENE.instantiate() as InventoryItemTile
		tile.inventory_item_requested.connect(_select_inventory_item)
		_inventory_grid.add_child(tile)
	while _inventory_grid.get_child_count() > wanted_count:
		var child := _inventory_grid.get_child(_inventory_grid.get_child_count() - 1)
		_inventory_grid.remove_child(child)
		child.queue_free()


func _ensure_equipment_tile_count(wanted_count: int) -> void:
	while _equipment_list.get_child_count() < wanted_count:
		var tile := ITEM_TILE_SCENE.instantiate() as InventoryItemTile
		tile.equipment_slot_requested.connect(_select_equipment_slot)
		_equipment_list.add_child(tile)
	while _equipment_list.get_child_count() > wanted_count:
		var child := _equipment_list.get_child(_equipment_list.get_child_count() - 1)
		_equipment_list.remove_child(child)
		child.queue_free()


func _refresh_action_truth(
		state: CharacterRunState,
		inventory: RunInventory,
		definition: ItemDefinition,
		from_inventory: bool
	) -> void:
	if definition == null:
		return
	if _use_button.visible:
		match definition.use_effect:
			ItemDefinition.UseEffect.HEAL_FLAT:
				_use_button.disabled = (
					not from_inventory
					or state.unit == null
					or state.unit.current_hp <= 0
					or state.unit.current_hp >= state.unit.max_hp.get_int()
				)
			ItemDefinition.UseEffect.RESTORE_AP_FLAT:
				_use_button.disabled = (
					not from_inventory
					or state.unit == null
					or state.unit.current_ap >= state.unit.max_ap.get_int()
				)
	if _unequip_button.visible:
		_unequip_button.disabled = inventory.get_empty_slot_count() <= 0


func _set_feedback_state(success: bool) -> void:
	_feedback.theme_type_variation = &"PremiumPositive" if success else &"PremiumDanger"


func _clear_children(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.free()
