extends CanvasLayer

const TooltipLayer = preload("res://ui/keyword_tooltip_layer.gd")

signal move_pressed
signal attack_pressed
signal end_turn_pressed
signal spell_pressed(spell, imprinted)
signal awakening_pressed

var _panel: PanelContainer
var _hbox: HBoxContainer
var _move_btn: Button
var _attack_btn: Button
var _awakening_btn: Button
var _end_btn: Button
var _info_label: Label
var _spell_box: HBoxContainer
var _spell_buttons: Array = []
var _elan_bar: ProgressBar
var _elan_label: Label
var _fervor_bar: ProgressBar
var _fervor_label: Label
var _player_controls_enabled: bool = true
var _current_unit = null

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_top = -98
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

	var resource_vbox := VBoxContainer.new()
	resource_vbox.custom_minimum_size = Vector2(185, 0)
	resource_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	resource_vbox.add_theme_constant_override("separation", 3)
	_hbox.add_child(resource_vbox)

	_elan_label = Label.new()
	_elan_label.add_theme_font_size_override("font_size", 12)
	_elan_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	resource_vbox.add_child(_elan_label)

	_elan_bar = ProgressBar.new()
	_elan_bar.custom_minimum_size = Vector2(185, 12)
	_elan_bar.max_value = 90.0
	_elan_bar.show_percentage = false
	resource_vbox.add_child(_elan_bar)

	_fervor_label = Label.new()
	_fervor_label.add_theme_font_size_override("font_size", 12)
	_fervor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	resource_vbox.add_child(_fervor_label)

	_fervor_bar = ProgressBar.new()
	_fervor_bar.custom_minimum_size = Vector2(185, 12)
	_fervor_bar.max_value = 100.0
	_fervor_bar.show_percentage = false
	resource_vbox.add_child(_fervor_bar)

	_move_btn = Button.new()
	_move_btn.text = "Deplacer"
	_move_btn.custom_minimum_size = Vector2(92, 44)
	_move_btn.tooltip_text = "PM : sert uniquement au deplacement. Elan : sert aux attaques et sorts."
	_move_btn.pressed.connect(func(): move_pressed.emit())
	_hbox.add_child(_move_btn)

	_attack_btn = Button.new()
	_attack_btn.text = "Attaquer"
	_attack_btn.custom_minimum_size = Vector2(92, 44)
	_attack_btn.tooltip_text = "Attaque de base : consomme de l'Elan pour frapper au contact."
	_attack_btn.pressed.connect(func(): attack_pressed.emit())
	_hbox.add_child(_attack_btn)

	_awakening_btn = Button.new()
	_awakening_btn.text = "Eveil"
	_awakening_btn.custom_minimum_size = Vector2(82, 44)
	_awakening_btn.tooltip_text = "Depense 50 Ferveur pour activer l'identite pendant 2 tours."
	_awakening_btn.pressed.connect(func(): awakening_pressed.emit())
	_hbox.add_child(_awakening_btn)

	_hbox.add_child(VSeparator.new())

	_spell_box = HBoxContainer.new()
	_spell_box.add_theme_constant_override("separation", 6)
	_hbox.add_child(_spell_box)

	_hbox.add_child(VSeparator.new())

	_end_btn = Button.new()
	_end_btn.text = "Fin de tour"
	_end_btn.custom_minimum_size = Vector2(100, 44)
	_end_btn.pressed.connect(func(): end_turn_pressed.emit())
	_hbox.add_child(_end_btn)

func build_spell_buttons(unit) -> void:
	for btn in _spell_buttons:
		btn.queue_free()
	_spell_buttons.clear()
	if unit == null:
		_refresh_button_states()
		return
	for spell in unit.spells:
		if spell == null:
			continue
		_add_spell_button(unit, spell, false)
		if spell.can_imprint():
			_add_spell_button(unit, spell, true)
	_refresh_button_states()

func _add_spell_button(unit, spell, imprinted: bool) -> void:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(82, 72)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.tooltip_text = ""
	btn.mouse_entered.connect(func(): _show_spell_card(unit, spell, imprinted))
	btn.mouse_exited.connect(_hide_keyword_tooltip)
	btn.set_meta("spell", spell)
	btn.set_meta("imprinted", imprinted)
	var action_label: String = _get_spell_action_label(unit, spell, imprinted)
	var name_prefix := "Emp. " if imprinted else ""
	if spell.icon != null:
		btn.icon = spell.icon
		btn.expand_icon = true
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		btn.text = "%s%s\n%s" % [name_prefix, spell.spell_name, action_label]
		btn.add_theme_font_size_override("font_size", 9)
	else:
		btn.text = "%s%s\n%s" % [name_prefix, spell.spell_name, action_label]
		btn.add_theme_font_size_override("font_size", 10)
	btn.pressed.connect(func(): spell_pressed.emit(spell, imprinted))
	_spell_box.add_child(btn)
	_spell_buttons.append(btn)

func _get_spell_action_label(unit, spell, imprinted: bool = false) -> String:
	var parts: Array = []
	if unit != null and unit.has_energy():
		var elan_cost: float = unit.get_spell_elan_cost(spell)
		var fervor_cost: float = unit.get_spell_fervor_cost(spell, imprinted)
		if elan_cost > 0.0:
			parts.append("%d Elan" % int(elan_cost))
		if fervor_cost > 0.0:
			parts.append("%d %s" % [int(fervor_cost), unit.energy_type.energy_name])
	else:
		parts.append("%d PA" % spell.ap_cost)
	if parts.is_empty():
		return "0 Elan"
	return " / ".join(parts)

func _can_use_spell(unit, spell, imprinted: bool = false) -> bool:
	if unit == null or spell == null:
		return false
	if unit.has_energy() and not unit.can_afford_spell_resources(spell, imprinted):
		return false
	return true

func _refresh_button_states() -> void:
	if _move_btn == null:
		return
	_move_btn.disabled = not _player_controls_enabled
	_end_btn.disabled = not _player_controls_enabled
	var attack_blocked := _current_unit == null
	if _current_unit != null and _current_unit.has_energy():
		attack_blocked = not _current_unit.can_afford_elan(_current_unit.get_basic_attack_elan_cost())
	_attack_btn.disabled = not _player_controls_enabled or attack_blocked
	if _current_unit != null and _current_unit.has_energy():
		_attack_btn.text = "Attaquer\n%d Elan" % int(_current_unit.get_basic_attack_elan_cost())
		_attack_btn.tooltip_text = _attack_tooltip(_current_unit)
	else:
		_attack_btn.text = "Attaquer"
		_attack_btn.tooltip_text = "Attaque de base au contact."
	var can_awaken: bool = _current_unit != null and _current_unit.has_method("can_activate_awakening") and _current_unit.can_activate_awakening()
	_awakening_btn.disabled = not _player_controls_enabled or not can_awaken
	for btn in _spell_buttons:
		var spell = btn.get_meta("spell") if btn.has_meta("spell") else null
		var imprinted: bool = btn.get_meta("imprinted") if btn.has_meta("imprinted") else false
		btn.disabled = not _player_controls_enabled or not _can_use_spell(_current_unit, spell, imprinted)
	_apply_base_button_modulates()

func update_info(unit) -> void:
	_disconnect_current_unit()
	_current_unit = unit
	if unit == null:
		_info_label.text = ""
		_refresh_resource_bars(null)
		_refresh_button_states()
		return
	_info_label.text = "Tour : %s\nPM : %d / %d" % [unit.unit_name, unit.current_mp, unit.max_mp.get_int()]
	if not unit.energy_changed.is_connected(_on_resource_changed):
		unit.energy_changed.connect(_on_resource_changed)
	if not unit.elan_changed.is_connected(_on_resource_changed):
		unit.elan_changed.connect(_on_resource_changed)
	_refresh_resource_bars(unit)
	_refresh_button_states()

func _disconnect_current_unit() -> void:
	if _current_unit == null or not is_instance_valid(_current_unit):
		return
	if _current_unit.energy_changed.is_connected(_on_resource_changed):
		_current_unit.energy_changed.disconnect(_on_resource_changed)
	if _current_unit.elan_changed.is_connected(_on_resource_changed):
		_current_unit.elan_changed.disconnect(_on_resource_changed)

func _on_resource_changed(unit) -> void:
	if unit == _current_unit:
		_refresh_resource_bars(unit)
		_refresh_button_states()

func _refresh_resource_bars(unit) -> void:
	if unit == null:
		_elan_label.text = ""
		_elan_bar.value = 0.0
		_fervor_label.text = ""
		_fervor_bar.value = 0.0
		return
	_elan_bar.max_value = unit.max_elan
	_elan_bar.value = unit.current_elan
	_elan_bar.modulate = Color(0.25, 0.72, 1.0)
	_elan_label.text = "Elan : %d / %d" % [int(unit.current_elan), int(unit.max_elan)]
	if not unit.has_energy():
		_fervor_label.text = ""
		_fervor_bar.value = 0.0
		_fervor_bar.modulate = Color.WHITE
		return
	var et: EnergyTypeData = unit.energy_type
	_fervor_bar.max_value = et.max_energy
	_fervor_bar.value = unit.current_energy
	_fervor_bar.modulate = et.color
	var suffix := ""
	if unit.charge_threshold_active:
		suffix = " | %s %dt" % [et.threshold_name, unit.awakening_turns_remaining]
	elif unit.current_energy >= et.reaction_cost:
		suffix = " | Reaction"
	_fervor_label.text = "%s : %d / %d%s" % [et.energy_name, int(unit.current_energy), int(et.max_energy), suffix]

func set_player_controls_enabled(enabled: bool) -> void:
	_player_controls_enabled = enabled
	_refresh_button_states()

func set_active_mode(mode: String, active_spell = null, imprinted: bool = false) -> void:
	_apply_base_button_modulates()
	if mode == "move" and not _move_btn.disabled:
		_move_btn.modulate = Color(0.6, 1.0, 0.6)
	if mode == "attack" and not _attack_btn.disabled:
		_attack_btn.modulate = Color(1.0, 0.6, 0.6)
	for btn in _spell_buttons:
		var spell = btn.get_meta("spell") if btn.has_meta("spell") else null
		var btn_imprinted: bool = btn.get_meta("imprinted") if btn.has_meta("imprinted") else false
		if mode == "spell" and spell == active_spell and btn_imprinted == imprinted and not btn.disabled:
			btn.modulate = Color(0.7, 0.85, 1.0)

func _apply_base_button_modulates() -> void:
	for button in [_move_btn, _attack_btn, _awakening_btn, _end_btn]:
		if button != null:
			button.modulate = Color(0.48, 0.48, 0.48, 0.78) if button.disabled else Color.WHITE
	for btn in _spell_buttons:
		btn.modulate = Color(0.48, 0.48, 0.48, 0.78) if btn.disabled else Color.WHITE

func _attack_tooltip(unit) -> String:
	if unit == null:
		return "Aucun combattant actif."
	if not unit.has_energy():
		return "Attaque de base au contact."
	var cost := int(unit.get_basic_attack_elan_cost())
	if not unit.can_afford_elan(cost):
		return "Injouable : Elan insuffisant (%d / %d)." % [int(unit.current_elan), cost]
	return "Attaque de base : coute %d Elan et frappe une cible adjacente." % cost

func _show_spell_card(unit, spell: Spell, imprinted: bool) -> void:
	var layer = _tooltip_layer()
	if layer == null:
		return
	layer.show_spell(unit, spell, imprinted, _spell_unusable_reason(unit, spell, imprinted), get_viewport().get_mouse_position())

func _hide_keyword_tooltip() -> void:
	var layer = _tooltip_layer()
	if layer != null:
		layer.request_hide()

func _tooltip_layer():
	if get_tree() == null:
		return null
	var layer = get_tree().get_first_node_in_group("keyword_tooltip_layer")
	if layer != null:
		return layer
	layer = TooltipLayer.new()
	get_tree().root.add_child(layer)
	return layer

func _spell_unusable_reason(unit, spell: Spell, imprinted: bool) -> String:
	if unit == null:
		return "aucun lanceur actif"
	if spell == null:
		return "sort invalide"
	if unit.has_energy():
		var elan_cost: float = unit.get_spell_elan_cost(spell)
		var fervor_cost: float = unit.get_spell_fervor_cost(spell, imprinted)
		if not unit.can_afford_elan(elan_cost):
			return "Elan insuffisant (%d / %d)" % [int(unit.current_elan), int(elan_cost)]
		if not unit.can_afford_energy(fervor_cost):
			return "Ferveur insuffisante (%d / %d)" % [int(unit.current_energy), int(fervor_cost)]
	elif unit.current_ap < spell.ap_cost:
		return "PA insuffisants"
	return ""
