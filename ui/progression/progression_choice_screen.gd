class_name ProgressionChoiceScreen
extends Control

var _choice: Dictionary = {}
var _selected_upgrade_id: StringName = &""
var _content: VBoxContainer = null
var _cards: Array[Button] = []
var _confirm_button: Button = null
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

	var background := ColorRect.new()
	background.color = Color(0.025, 0.02, 0.035, 0.97)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 90)
	margin.add_theme_constant_override("margin_top", 55)
	margin.add_theme_constant_override("margin_right", 90)
	margin.add_theme_constant_override("margin_bottom", 55)
	add_child(margin)

	_content = VBoxContainer.new()
	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_theme_constant_override("separation", 20)
	margin.add_child(_content)


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
		var empty_label := Label.new()
		empty_label.text = "Aucun choix de progression en attente."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_content.add_child(empty_label)
		return

	var title := Label.new()
	title.text = "%s — %s, rang %d" % [
		_choice.get("character_name", "Personnage"),
		_choice.get("discipline_name", str(_choice.get("discipline_id", &""))),
		int(_choice.get("rank", 1)),
	]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	_content.add_child(title)

	var xp_label := Label.new()
	xp_label.text = "Progression : %d XP (seuil du rang : %d)" % [
		int(_choice.get("xp", 0)),
		int(_choice.get("required_total_xp", 0)),
	]
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_label.add_theme_font_size_override("font_size", 18)
	_content.add_child(xp_label)

	var prompt := Label.new()
	prompt.text = "Choisissez une évolution, puis confirmez."
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(prompt)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
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
	_confirm_button.text = "Confirmer l’évolution"
	_confirm_button.custom_minimum_size = Vector2(260, 48)
	_confirm_button.disabled = true
	_confirm_button.pressed.connect(confirm_selection)
	_content.add_child(_confirm_button)


func _make_upgrade_card(upgrade: SkillUpgradeData) -> Button:
	var card := Button.new()
	card.toggle_mode = true
	card.custom_minimum_size = Vector2(360, 230)
	card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.text = "%s\n\n%s" % [upgrade.display_name, upgrade.description]
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
		card.button_pressed = card.get_meta("upgrade_id", &"") == upgrade_id
	if _confirm_button != null:
		_confirm_button.disabled = false
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
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
