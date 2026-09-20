extends "res://ui/expedition/class_workshop.gd"
## Dedicated paper doll and bag; transactions remain in the shared workshop.
const P := preload("res://ui/expedition/class_card_presentation.gd")
const LootIcon := preload("res://ui/expedition/class_loot_icon.gd")
var category := "all"


func _ready() -> void:
	cards = GameManager.expedition.cards
	name = "ClassInventoryView"
	_render()


func _render() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var session: ExpeditionSession = cards.owner()
	read_only = read_only or session.route.phase == "combat"
	add_theme_constant_override("separation", 10)
	_label(
		self,
		"Consultation en combat · équipement verrouillé." if read_only else "Sélectionnez un objet pour comparer ses effets, l'équiper ou le vendre.",
		16,
	)
	if not notice.is_empty():
		_label(self, notice, 16)
	var columns := HBoxContainer.new()
	columns.name = "InventoryColumns"
	columns.add_theme_constant_override("separation", 18)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.custom_minimum_size.y = 360
	add_child(columns)
	var figure := P.section(columns, 330)
	var hero := session.character.unit
	_label(
		figure,
		"%s · niveau %d" % [hero.unit_name, session.character.champion_progression.current_level],
		23,
	)
	_label(
		figure,
		"%s · %d / %d PV"
		% [Catalog.CLASSES[cards.primary_class][0], hero.current_hp, hero.max_hp.get_int()],
		17,
	)
	var doll := HBoxContainer.new()
	doll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	figure.add_child(doll)
	var left := VBoxContainer.new()
	doll.add_child(left)
	var preview := preload("res://ui/characters/CharacterPreview3D.tscn").instantiate()
	preview.name = "InventoryCharacterPreview"
	preview.custom_minimum_size = Vector2(190, 290)
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	doll.add_child(preview)
	preview.configure(hero.character_data)
	var right := VBoxContainer.new()
	doll.add_child(right)
	for index in EquipmentLoadout.EQUIPMENT_SLOTS.size():
		var slot: int = EquipmentLoadout.EQUIPMENT_SLOTS[index]
		var host := left if index < 3 else right
		var worn := session.character.equipment_loadout.get_item(slot)
		var label := _label(host, EquipmentLoadout.get_slot_display_name(slot), 13)
		label.custom_minimum_size.x = 66
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if worn != null:
			_item_icon(host, worn, "EquipmentSlot_%d" % slot)
		else:
			var empty := Button.new()
			empty.name = "EquipmentSlot_%d" % slot
			empty.custom_minimum_size = Vector2(64, 64)
			empty.icon = preload("res://core/expedition/class_icon_catalog.gd").empty_slot(index)
			empty.expand_icon = true
			empty.add_theme_constant_override("icon_max_width", 42)
			empty.tooltip_text = EquipmentLoadout.get_slot_display_name(slot) + " · vide"
			empty.focus_mode = Control.FOCUS_NONE
			empty.disabled = true
			CardSkin.icon_button(empty, Color("647a70"))
			host.add_child(empty)
	_label(figure, "Les six emplacements se remplissent avec le butin de la run.", 15)
	var bag := P.section(columns, 280)
	_label(bag, "SAC · %d oboles" % session.gold, 22)
	var tabs := HFlowContainer.new()
	bag.add_child(tabs)
	for entry in [["all", "Tout"], ["equipment", "Équipement"], ["other", "Reliques & runes"]]:
		var tab := _button(
			tabs,
			entry[1],
			func():
				category = entry[0]
				_render(),
		)
		tab.toggle_mode = true
		tab.button_pressed = category == entry[0]
	var scroll := ScrollContainer.new()
	scroll.name = "InventoryBagScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	bag.add_child(scroll)
	var grid := GridContainer.new()
	grid.name = "InventoryItemGrid"
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	var available: Array[String] = []
	for item in session.card_inventory.get_slots():
		if item == null:
			continue
		var definition := session.card_inventory.get_catalog().get_definition(item.definition_id)
		if category == "equipment" and not definition.is_equippable():
			continue
		if category == "other" and definition.is_equippable():
			continue
		available.append(str(item.instance_id))
		_item_icon(grid, item, "InventoryItem_" + str(item.instance_id))
	if available.is_empty():
		var empty := _label(
			bag,
			"Aucun objet dans cette catégorie.\nVos prochains butins apparaîtront ici.",
			16,
		)
		empty.name = "InventoryEmptyState"
		bag.move_child(empty, bag.get_child_count() - 2)
	var pane := ScrollContainer.new()
	pane.name = "InventoryDetailScroll"
	pane.custom_minimum_size.x = 285
	pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pane.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pane.follow_focus = true
	columns.add_child(pane)
	detail = P.section(pane)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 12)
	for worn in session.character.equipment_loadout.get_equipped_items():
		available.append(str(worn.instance_id))
	if selected_id not in available:
		selected_id = available[0] if not available.is_empty() else ""
	_show_detail()


func _item_icon(parent: Node, item: ItemInstance, control_name: String) -> void:
	var definition: ItemDefinition = cards.owner().card_inventory.get_catalog().get_definition(
		item.definition_id
	)
	var tile := LootIcon.new()
	tile.name = control_name
	tile.configure(
		definition.display_name,
		definition.icon,
		P.item_description(definition),
		item.quantity,
		str(definition.rarity),
		P.item_badge(definition),
	)
	tile.set_meta("inventory_instance", str(item.instance_id))
	tile.set_meta("worn", control_name.begins_with("EquipmentSlot_"))
	parent.add_child(tile)
	var select := func():
		selected_id = str(item.instance_id)
		_show_detail()
	tile.pressed.connect(select)
	tile.focus_entered.connect(select)


func _show_detail() -> void:
	super._show_detail()
	for tile in find_children("*", "Button", true, false):
		if tile.has_meta("inventory_instance"):
			tile.set_marked(
				tile.get_meta("inventory_instance") == selected_id,
				tile.get_meta("worn", false),
			)
	var inventory: RunInventory = cards.owner().card_inventory
	var item := inventory.get_instance(StringName(selected_id))
	if item == null:
		for worn in cards.owner().character.equipment_loadout.get_equipped_items():
			if str(worn.instance_id) == selected_id:
				item = worn
	if item != null:
		var icon := P.icon(
			detail,
			inventory.get_catalog().get_definition(item.definition_id).icon,
			80,
		)
		detail.move_child(icon, 0)
