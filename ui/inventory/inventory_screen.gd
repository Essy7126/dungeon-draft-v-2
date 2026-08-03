class_name InventoryScreen
extends Control

signal screen_closed

@onready var _title: Label = %Title
@onready var _hero_selector: OptionButton = %HeroSelector
@onready var _inventory_grid: GridContainer = %InventoryGrid
@onready var _equipment_list: VBoxContainer = %EquipmentList
@onready var _detail_name: Label = %DetailName
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

var _manager = null
var _hero_ids: Array[StringName] = []
var _selected_character_id: StringName = &""
var _selected_instance_id: StringName = &""
var _selected_equipment_slot := ItemDefinition.EquipmentSlot.NONE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	var viewport_size := get_viewport_rect().size
	_panel.custom_minimum_size = Vector2(
		minf(1120.0, maxf(960.0, viewport_size.x - 48.0)),
		minf(760.0, maxf(600.0, viewport_size.y - 40.0)),
	)


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
	_title.text = "INVENTAIRE DE LA RUN · %d/%d emplacements" % [
		inventory.capacity - inventory.get_empty_slot_count(),
		inventory.capacity,
	]
	_rebuild_inventory(inventory, catalog)
	_rebuild_equipment(state, catalog)
	_refresh_details(state, inventory, catalog)


func _rebuild_inventory(inventory: RunInventory, catalog: ItemCatalog) -> void:
	_clear_children(_inventory_grid)
	for slot_index in range(inventory.capacity):
		var instance := inventory.get_slot(slot_index)
		var button := Button.new()
		button.custom_minimum_size = Vector2(148.0, 82.0)
		button.focus_mode = Control.FOCUS_ALL
		if instance == null:
			button.text = "Emplacement %02d\n—" % (slot_index + 1)
			button.disabled = true
		else:
			var definition := catalog.get_definition(instance.definition_id)
			button.text = "%s\n%s" % [
				definition.display_name if definition != null else str(instance.definition_id),
				"x%d" % instance.quantity if instance.quantity > 1 else "Objet unique",
			]
			button.tooltip_text = definition.description if definition != null else ""
			button.icon = definition.icon if definition != null else null
			button.toggle_mode = true
			button.button_pressed = instance.instance_id == _selected_instance_id
			button.pressed.connect(_select_inventory_item.bind(instance.instance_id))
		_inventory_grid.add_child(button)


func _rebuild_equipment(
		state: CharacterRunState,
		catalog: ItemCatalog
	) -> void:
	_clear_children(_equipment_list)
	for slot in EquipmentLoadout.EQUIPMENT_SLOTS:
		var instance := state.equipment_loadout.get_item(slot)
		var definition := (
			catalog.get_definition(instance.definition_id)
			if instance != null
			else null
		)
		var button := Button.new()
		button.custom_minimum_size = Vector2(330.0, 58.0)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.button_pressed = slot == _selected_equipment_slot
		button.text = "%s : %s" % [
			EquipmentLoadout.get_slot_display_name(slot),
			definition.display_name if definition != null else "Vide",
		]
		button.pressed.connect(_select_equipment_slot.bind(slot))
		_equipment_list.add_child(button)


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
	_detail_rarity.text = (
		str(definition.rarity).to_upper() if definition != null else ""
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


func _select_inventory_item(instance_id: StringName) -> void:
	_selected_instance_id = instance_id
	_selected_equipment_slot = ItemDefinition.EquipmentSlot.NONE
	_feedback.text = ""
	_refresh()


func _select_equipment_slot(slot: int) -> void:
	_selected_instance_id = &""
	_selected_equipment_slot = slot
	_feedback.text = ""
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
	if result.get("success", false):
		_selected_equipment_slot = ItemDefinition.EquipmentSlot.NONE
	_refresh()


func _modifier_text(definition: ItemDefinition) -> String:
	if definition == null:
		return ""
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
	return "STATISTIQUES ACTUELLES\nPV %d/%d · Attaque %d\nArmure %.0f · Résistance magique %.0f\nCritique %.0f%% · Force %.0f" % [
		unit.current_hp,
		unit.max_hp.get_int(),
		unit.attack_power.get_int(),
		unit.armure.get_value(),
		unit.resist_magique.get_value(),
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
		_: return str(stat_id)


func _clear_children(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.free()
