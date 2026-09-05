extends CanvasLayer

const TooltipLayer = preload("res://ui/keyword_tooltip_layer.gd")
const ACTION_SHORTCUT_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4]

signal move_pressed
signal attack_pressed
signal end_turn_pressed
signal spell_pressed(spell)

var _panel: PanelContainer
var _hbox: HBoxContainer
var _move_btn: Button
var _attack_btn: Button
var _end_btn: Button
var _info_label: Label
var _spell_box: HBoxContainer
var _spell_buttons: Array = []
var _ap_label: Label
var _player_controls_enabled := true
var _current_unit = null


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_top = -98.0
	add_child(_panel)

	_hbox = HBoxContainer.new()
	_hbox.add_theme_constant_override("separation", 10)
	_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(_hbox)

	_info_label = Label.new()
	_info_label.add_theme_font_size_override("font_size", 16)
	_info_label.custom_minimum_size = Vector2(150, 0)
	_info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hbox.add_child(_info_label)

	_ap_label = Label.new()
	_ap_label.add_theme_font_size_override("font_size", 16)
	_ap_label.custom_minimum_size = Vector2(185, 0)
	_ap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ap_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_hbox.add_child(_ap_label)

	_move_btn = Button.new()
	_move_btn.text = "Deplacer"
	_move_btn.custom_minimum_size = Vector2(92, 44)
	_move_btn.tooltip_text = "Déplacer (M) — les PM servent au déplacement."
	_move_btn.shortcut = _shortcut_for_key(KEY_M)
	_move_btn.shortcut_in_tooltip = true
	_move_btn.pressed.connect(func() -> void: move_pressed.emit())
	_hbox.add_child(_move_btn)

	_attack_btn = Button.new()
	_attack_btn.text = "Attaquer"
	_attack_btn.custom_minimum_size = Vector2(92, 44)
	_attack_btn.shortcut = _shortcut_for_key(KEY_A)
	_attack_btn.shortcut_in_tooltip = true
	_attack_btn.pressed.connect(func() -> void: attack_pressed.emit())
	_hbox.add_child(_attack_btn)

	_spell_box = HBoxContainer.new()
	_spell_box.add_theme_constant_override("separation", 6)
	_hbox.add_child(_spell_box)

	_hbox.add_child(VSeparator.new())
	_end_btn = Button.new()
	_end_btn.text = "Fin de tour"
	_end_btn.custom_minimum_size = Vector2(100, 44)
	_end_btn.tooltip_text = "Terminer le tour (F)."
	_end_btn.shortcut = _shortcut_for_key(KEY_F)
	_end_btn.shortcut_in_tooltip = true
	_end_btn.pressed.connect(func() -> void: end_turn_pressed.emit())
	_hbox.add_child(_end_btn)


func build_spell_buttons(unit) -> void:
	_clear_spell_buttons()
	if unit != null:
		for spell in unit.spells:
			if spell != null:
				_add_spell_button(unit, spell)
	_refresh_button_states()


func _clear_spell_buttons() -> void:
	if get_tree() != null:
		var tooltip = get_tree().get_first_node_in_group("keyword_tooltip_layer")
		if tooltip != null:
			tooltip.request_hide()
	for button_value in _spell_buttons:
		var button := button_value as Button
		if not is_instance_valid(button):
			continue
		button.set_block_signals(true)
		button.queue_free()
	_spell_buttons.clear()


func _add_spell_button(unit, spell) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(82, 72)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.tooltip_text = ""
	button.set_meta("spell", spell)
	button.mouse_entered.connect(func() -> void: _show_spell_card(unit, spell))
	button.mouse_exited.connect(_hide_keyword_tooltip)
	if spell.icon != null:
		button.icon = spell.icon
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	button.text = "%s\n%s" % [spell.spell_name, _get_spell_action_label(unit, spell)]
	button.add_theme_font_size_override("font_size", 9 if spell.icon != null else 10)
	button.pressed.connect(func() -> void: spell_pressed.emit(spell))
	var shortcut_index := _spell_buttons.size()
	if shortcut_index < ACTION_SHORTCUT_KEYS.size():
		button.shortcut = _shortcut_for_key(ACTION_SHORTCUT_KEYS[shortcut_index])
		button.shortcut_in_tooltip = true
	_spell_box.add_child(button)
	_spell_buttons.append(button)


func _shortcut_for_key(keycode: Key) -> Shortcut:
	var shortcut_event := InputEventKey.new()
	shortcut_event.physical_keycode = keycode
	var shortcut := Shortcut.new()
	shortcut.events = [shortcut_event]
	return shortcut


func _get_spell_action_label(unit, spell) -> String:
	var ap_cost: int = unit.get_spell_ap_cost(spell) if unit != null else spell.ap_cost
	if unit != null and unit.get_spell_cooldown_remaining(spell) > 0:
		return "CD %d" % unit.get_spell_cooldown_remaining(spell)
	return "%d PA" % ap_cost


func _can_use_spell(unit, spell) -> bool:
	return unit != null and spell != null and unit.can_use_spell(spell)


func _refresh_button_states() -> void:
	if _move_btn == null:
		return
	_move_btn.disabled = not _player_controls_enabled
	_end_btn.disabled = not _player_controls_enabled
	var attack_available: bool = (
		_current_unit != null and bool(_current_unit.can_use_basic_attack())
	)
	_attack_btn.visible = _current_unit == null or _current_unit.basic_attack_enabled
	_attack_btn.disabled = not _player_controls_enabled or not attack_available
	if _current_unit != null:
		_attack_btn.text = "Attaquer\n%d PA" % _current_unit.get_basic_attack_ap_cost()
		_attack_btn.tooltip_text = _attack_tooltip(_current_unit)
	else:
		_attack_btn.text = "Attaquer"
		_attack_btn.tooltip_text = "Attaque de base au contact."
	for button_value in _spell_buttons:
		var button := button_value as Button
		var spell = button.get_meta("spell") if button.has_meta("spell") else null
		button.disabled = not _player_controls_enabled or not _can_use_spell(_current_unit, spell)
	_apply_base_button_modulates()


func update_info(unit) -> void:
	_disconnect_current_unit()
	_current_unit = unit
	if unit == null:
		_info_label.text = ""
		_ap_label.text = ""
		_refresh_button_states()
		return
	_info_label.text = "Tour : %s\nPM : %d / %d" % [
		CombatGlossary.unit_display_name(unit),
		unit.current_mp,
		unit.max_mp.get_int(),
	]
	if not unit.stats_changed.is_connected(_on_resource_changed):
		unit.stats_changed.connect(_on_resource_changed)
	_refresh_resource_bars(unit)
	_refresh_button_states()


func _disconnect_current_unit() -> void:
	if _current_unit == null or not is_instance_valid(_current_unit):
		return
	if _current_unit.stats_changed.is_connected(_on_resource_changed):
		_current_unit.stats_changed.disconnect(_on_resource_changed)


func _on_resource_changed(unit) -> void:
	if unit == _current_unit:
		_refresh_resource_bars(unit)
		_refresh_button_states()


func _refresh_resource_bars(unit, _animate_changes: bool = true) -> void:
	_ap_label.text = "" if unit == null else "PA  %s" % _ap_pips(
		unit.current_ap,
		unit.max_ap.get_int()
	)


func _ap_pips(current: int, max_value: int) -> String:
	var shown_max := maxi(max_value, 0)
	var filled := clampi(current, 0, shown_max)
	var pips := "".join(["●".repeat(filled), "○".repeat(shown_max - filled)])
	if current > shown_max:
		pips += " +%d" % (current - shown_max)
	return pips


func set_player_controls_enabled(enabled: bool) -> void:
	_player_controls_enabled = enabled
	_refresh_button_states()


func are_player_controls_enabled() -> bool:
	return _player_controls_enabled


func set_active_mode(mode: String, active_spell = null) -> void:
	_apply_base_button_modulates()
	if mode == "move" and not _move_btn.disabled:
		_move_btn.modulate = Color(0.6, 1.0, 0.6)
	if mode == "attack" and not _attack_btn.disabled:
		_attack_btn.modulate = Color(1.0, 0.6, 0.6)
	for button_value in _spell_buttons:
		var button := button_value as Button
		var spell = button.get_meta("spell") if button.has_meta("spell") else null
		if mode == "spell" and spell == active_spell and not button.disabled:
			button.modulate = Color(0.7, 0.85, 1.0)


func _apply_base_button_modulates() -> void:
	for button in [_move_btn, _attack_btn, _end_btn]:
		if button != null:
			button.modulate = (
				Color(0.48, 0.48, 0.48, 0.78) if button.disabled else Color.WHITE
			)
	for button_value in _spell_buttons:
		var button := button_value as Button
		button.modulate = (
			Color(0.48, 0.48, 0.48, 0.78) if button.disabled else Color.WHITE
		)


func _attack_tooltip(unit) -> String:
	if unit == null:
		return "Aucun combattant actif."
	if not unit.basic_attack_enabled:
		return "Ce personnage ne possede pas d'attaque de base."
	var cost: int = unit.get_basic_attack_ap_cost()
	if unit.current_ap < cost:
		return "Injouable : PA insuffisants (%d / %d)." % [unit.current_ap, cost]
	return "Attaque de base : coute %d PA et frappe une cible adjacente." % cost


func _show_spell_card(unit, spell: Spell) -> void:
	var layer = _tooltip_layer()
	if layer != null:
		layer.show_spell(
			unit,
			spell,
			_spell_unusable_reason(unit, spell),
			get_viewport().get_mouse_position()
		)


func _hide_keyword_tooltip() -> void:
	var layer = _tooltip_layer()
	if layer != null:
		layer.request_hide()


func _tooltip_layer():
	if get_tree() == null:
		return null
	var layer = get_tree().get_first_node_in_group("keyword_tooltip_layer")
	if layer == null:
		layer = TooltipLayer.new()
		get_tree().root.add_child(layer)
	return layer


func _spell_unusable_reason(unit, spell: Spell) -> String:
	if unit == null:
		return "aucun lanceur actif"
	if spell == null:
		return "sort invalide"
	var ap_cost: int = unit.get_spell_ap_cost(spell)
	if unit.current_ap < ap_cost:
		return "PA insuffisants (%d / %d)" % [unit.current_ap, ap_cost]
	return ""
