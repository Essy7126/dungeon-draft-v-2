class_name ChampionCampScreen
extends Control

signal closed

const STYLE := preload("res://ui/progression/theme/spell_codex_style.gd")
var _title: Label
var _offers: GridContainer
var _status: Label
var _target_by_offer: Dictionary = {}
var _buy_buttons: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.025, 0.045, 0.05, 0.97)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	_title = _label("", 25)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	var inventory := Button.new()
	inventory.text = "GÉRER MES ÉQUIPEMENTS"
	STYLE.button(inventory)
	inventory.pressed.connect(func() -> void:
		closed.emit()
		var ui := GameManager.get_persistent_run_ui()
		if ui != null:
			ui.open_inventory_screen()
	)
	header.add_child(inventory)
	var close := Button.new()
	close.text = "REVENIR AU BILAN  ×"
	STYLE.button(close)
	close.pressed.connect(func() -> void: closed.emit())
	header.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_offers = GridContainer.new()
	_offers.columns = 2
	_offers.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_offers.add_theme_constant_override("h_separation", 16)
	_offers.add_theme_constant_override("v_separation", 16)
	scroll.add_child(_offers)
	_status = _label("Les propositions et les achats sont conservés dans votre run.", 15)
	column.add_child(_status)
	refresh()
	close.grab_focus.call_deferred()


func refresh(focus_offer: StringName = &"") -> void:
	var snapshot := GameManager.get_champion_camp_snapshot()
	_title.text = "%s · %d drachmes" % [snapshot.get("name", "Préparation"), snapshot.get("currency", 0)]
	_buy_buttons.clear()
	for child in _offers.get_children():
		_offers.remove_child(child)
		child.queue_free()
	for offer in snapshot.get("offers", []):
		_offers.add_child(_card(offer))
	if focus_offer != &"":
		var focus_button := _buy_buttons.get(focus_offer) as Button
		if focus_button == null or focus_button.disabled:
			for button: Button in _buy_buttons.values():
				if not button.disabled:
					focus_button = button
					break
		if focus_button != null and not focus_button.disabled:
			focus_button.grab_focus.call_deferred()


func _card(offer: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", STYLE.box(STYLE.SURFACE, STYLE.BORDER, 8, 18))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	column.add_child(_label(offer.name, 20))
	var description := _label(offer.description, 15)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(description)
	var targets: Array = offer.targets
	if not targets.is_empty():
		var select := OptionButton.new()
		select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		select.fit_to_longest_item = false
		select.custom_minimum_size.y = 38
		for target in targets:
			select.add_item(target.name)
			select.set_item_metadata(select.item_count - 1, target.id)
		var selected_id := StringName(_target_by_offer.get(offer.id, targets[0].id))
		var selected_index := 0
		for index in range(targets.size()):
			if StringName(targets[index].id) == selected_id:
				selected_index = index
		select.select(selected_index)
		_target_by_offer[offer.id] = targets[selected_index].id
		var effect_label := _label(str(targets[selected_index].description), 14)
		effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		select.tooltip_text = str(targets[selected_index].description)
		select.item_selected.connect(func(index: int) -> void:
			_target_by_offer[offer.id] = select.get_item_metadata(index)
			select.tooltip_text = str(targets[index].description)
			effect_label.text = str(targets[index].description)
		)
		column.add_child(select)
		column.add_child(effect_label)
	var buy := Button.new()
	buy.text = "%d DRACHMES · %d ACHAT(S) RESTANT(S)" % [offer.cost, offer.remaining]
	buy.disabled = not bool(offer.available) or not GameManager.can_edit_champion_build()
	STYLE.button(buy)
	_buy_buttons[offer.id] = buy
	buy.pressed.connect(func() -> void:
		var result := GameManager.purchase_champion_camp_offer(offer.id, StringName(_target_by_offer.get(offer.id, &"")))
		_status.text = "Achat effectué : %s." % offer.name if bool(result.get("success", false)) else str(result.get("error", "Achat impossible."))
		refresh(StringName(offer.id))
	)
	column.add_child(buy)
	return panel


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()


func _label(value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	STYLE.label(label, font_size > 19)
	label.add_theme_font_size_override("font_size", font_size)
	return label
