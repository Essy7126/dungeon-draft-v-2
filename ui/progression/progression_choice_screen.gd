class_name ProgressionChoiceScreen
extends Control

const ORNAMENT_SCRIPT := preload("res://ui/theme/premium_panel_ornament.gd")

var _choice: Dictionary = {}
var _selected_upgrade_id: StringName = &""
var _content: VBoxContainer = null
var _cards: Array[Button] = []
var _confirm_button: Button = null
var _feedback_label: Label = null
var _confirmation_in_flight: bool = false
var _closed: bool = false
var progression_controller = null


func _ready() -> void:
	if progression_controller == null:
		progression_controller = GameManager
	if progression_controller.has_method("register_progression_screen") \
			and not progression_controller.register_progression_screen(self):
		_closed = true
		hide()
		queue_free()
		return
	_build_ui()
	show_choice(progression_controller.get_next_pending_progression_choice())


func _exit_tree() -> void:
	_unregister_from_controller()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	PremiumUI.apply(self)

	var background := ColorRect.new()
	background.color = Color(0.008, 0.006, 0.009, 0.94)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 54)
	margin.add_theme_constant_override("margin_top", 34)
	margin.add_theme_constant_override("margin_right", 54)
	margin.add_theme_constant_override("margin_bottom", 34)
	add_child(margin)

	var shell := PanelContainer.new()
	shell.theme_type_variation = &"PremiumScreen"
	margin.add_child(shell)

	var ornament := ORNAMENT_SCRIPT.new() as PremiumPanelOrnament
	ornament.variant = "screen"
	ornament.accent_alpha = 0.82
	ornament.set_anchors_preset(Control.PRESET_FULL_RECT)
	shell.add_child(ornament)

	var safe_margin := MarginContainer.new()
	safe_margin.add_theme_constant_override("margin_left", 34)
	safe_margin.add_theme_constant_override("margin_top", 26)
	safe_margin.add_theme_constant_override("margin_right", 34)
	safe_margin.add_theme_constant_override("margin_bottom", 24)
	shell.add_child(safe_margin)

	_content = VBoxContainer.new()
	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_theme_constant_override("separation", 13)
	safe_margin.add_child(_content)


func show_choice(choice: Dictionary) -> void:
	if _closed:
		return
	_choice = choice.duplicate(true)
	_selected_upgrade_id = &""
	_confirmation_in_flight = false
	if _content == null:
		return
	_clear_content()
	if _choice.is_empty():
		var eyebrow := Label.new()
		eyebrow.theme_type_variation = &"PremiumEyebrow"
		eyebrow.text = "PROGRESSION"
		eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_content.add_child(eyebrow)
		var empty_label := Label.new()
		empty_label.text = "Aucun choix de progression en attente."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.theme_type_variation = &"PremiumTitle"
		_content.add_child(empty_label)
		return

	var eyebrow := Label.new()
	eyebrow.text = "DÉCISION DE PROGRESSION · CHOIX PERMANENT"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.theme_type_variation = &"PremiumEyebrow"
	_content.add_child(eyebrow)

	var title := Label.new()
	title.text = "%s · %s · RANG %d" % [
		_choice.get("character_name", "Personnage"),
		_choice.get("discipline_name", str(_choice.get("discipline_id", &""))),
		int(_choice.get("rank", 1)),
	]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.theme_type_variation = &"PremiumTitle"
	title.add_theme_font_size_override("font_size", 30)
	_content.add_child(title)

	var xp_label := Label.new()
	xp_label.text = "%d XP ACQUIS · SEUIL DU RANG : %d XP" % [
		int(_choice.get("xp", 0)),
		int(_choice.get("required_total_xp", 0)),
	]
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_label.theme_type_variation = &"PremiumSubtitle"
	xp_label.add_theme_font_size_override("font_size", 15)
	_content.add_child(xp_label)

	var prompt := Label.new()
	prompt.text = "Comparez les effets, sélectionnez une évolution, puis confirmez."
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.theme_type_variation = &"PremiumMuted"
	_content.add_child(prompt)

	var separator := HSeparator.new()
	separator.theme_type_variation = &"PremiumSeparator"
	_content.add_child(separator)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(row)

	_cards.clear()
	for upgrade_value in _choice.get("choices", []):
		var upgrade := upgrade_value as SkillUpgradeData
		if upgrade == null:
			continue
		var card := _make_upgrade_card(upgrade)
		_cards.append(card)
		row.add_child(card)

	_confirm_button = Button.new()
	_confirm_button.text = "CONFIRMER L’ÉVOLUTION"
	_confirm_button.custom_minimum_size = Vector2(310, 46)
	_confirm_button.disabled = true
	_confirm_button.focus_mode = Control.FOCUS_ALL
	_confirm_button.theme_type_variation = &"PremiumPrimaryButton"
	_confirm_button.pressed.connect(confirm_selection)
	_content.add_child(_confirm_button)

	_feedback_label = Label.new()
	_feedback_label.theme_type_variation = &"PremiumDanger"
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.hide()
	_content.add_child(_feedback_label)
	_configure_focus.call_deferred()


func _make_upgrade_card(upgrade: SkillUpgradeData) -> Button:
	var card := Button.new()
	card.toggle_mode = true
	card.focus_mode = Control.FOCUS_ALL
	card.theme_type_variation = &"PremiumTileButton"
	card.custom_minimum_size = Vector2(372, 238)
	card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.text = "ÉVOLUTION · RANG %d\n\n%s\n\n%s" % [
		upgrade.rank,
		upgrade.display_name.to_upper(),
		upgrade.description,
	]
	card.alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.tooltip_text = upgrade.description
	card.set_meta("upgrade_id", upgrade.upgrade_id)
	if upgrade.icon != null:
		card.icon = upgrade.icon
		card.expand_icon = true
	card.pressed.connect(func(): select_upgrade_card(upgrade.upgrade_id))
	return card


func select_upgrade_card(upgrade_id: StringName) -> bool:
	if _closed or _confirmation_in_flight \
			or upgrade_id == &"" or _choice.is_empty():
		return false
	var exists := false
	for upgrade_value in _choice.get("choices", []):
		var upgrade := upgrade_value as SkillUpgradeData
		if upgrade != null and upgrade.upgrade_id == upgrade_id:
			exists = true
			break
	if not exists:
		return false
	_selected_upgrade_id = upgrade_id
	for card in _cards:
		PremiumUI.set_button_state(
			card,
			card.get_meta("upgrade_id", &"") == upgrade_id,
		)
	if _confirm_button != null:
		_confirm_button.disabled = false
	if _feedback_label != null:
		_feedback_label.hide()
	return true


func confirm_selection() -> bool:
	if _closed or _confirmation_in_flight \
			or _selected_upgrade_id == &"" or _choice.is_empty():
		return false
	_confirmation_in_flight = true
	if _confirm_button != null:
		_confirm_button.disabled = true
	var accepted: bool = progression_controller.choose_progression_upgrade(
		_choice.get("character_id", &""),
		_choice.get("discipline_id", &""),
		int(_choice.get("rank", 1)),
		_selected_upgrade_id
	)
	if not accepted:
		_confirmation_in_flight = false
		if _confirm_button != null:
			_confirm_button.disabled = false
		if _feedback_label != null:
			_feedback_label.text = "Cette évolution ne peut pas être appliquée."
			_feedback_label.show()
		return false
	var next_choice: Dictionary = progression_controller.get_next_pending_progression_choice()
	if not next_choice.is_empty():
		show_choice(next_choice)
	else:
		_closed = true
		hide()
		_choice.clear()
		_selected_upgrade_id = &""
		_unregister_from_controller()
	return true


func get_selected_upgrade_id() -> StringName:
	return _selected_upgrade_id


func is_confirmation_enabled() -> bool:
	return _confirm_button != null and not _confirm_button.disabled


func get_choice_card_count() -> int:
	return _cards.size()


func get_current_choice() -> Dictionary:
	return _choice.duplicate(true)


func is_closed_for_progression() -> bool:
	return _closed


func close_for_run_cleanup() -> void:
	if _closed:
		return
	_closed = true
	hide()
	_confirmation_in_flight = false
	_choice.clear()
	_selected_upgrade_id = &""
	if _confirm_button != null:
		_confirm_button.disabled = true
	_unregister_from_controller()
	if is_inside_tree():
		queue_free()


func _unregister_from_controller() -> void:
	if progression_controller != null \
			and progression_controller.has_method("unregister_progression_screen"):
		progression_controller.unregister_progression_screen(self)


func _clear_content() -> void:
	_cards.clear()
	_confirm_button = null
	_feedback_label = null
	for child in _content.get_children():
		if child is Control:
			child.hide()
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not child.is_queued_for_deletion():
			child.queue_free()


func _configure_focus() -> void:
	if _cards.is_empty() or _confirm_button == null:
		return
	for index in _cards.size():
		var previous := _cards[(index - 1 + _cards.size()) % _cards.size()]
		var next := _cards[(index + 1) % _cards.size()]
		_cards[index].focus_neighbor_left = previous.get_path()
		_cards[index].focus_neighbor_right = next.get_path()
		_cards[index].focus_neighbor_bottom = _confirm_button.get_path()
	_confirm_button.focus_neighbor_top = _cards[0].get_path()
	_confirm_button.focus_neighbor_left = _cards[0].get_path()
	_confirm_button.focus_neighbor_right = _cards[_cards.size() - 1].get_path()
	_cards[0].grab_focus()
