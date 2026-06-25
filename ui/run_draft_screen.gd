extends Control

const SLOT_COUNT := 3

var _hero_options: Array = []
var _energy_options: Array = []
var _trait_options: Array = []
var _selected_heroes: Array = []
var _selected_energies: Array = []
var _selected_traits: Array = []

var _slots_row: HBoxContainer
var _start_button: Button

func _ready() -> void:
	_hero_options = GameManager.get_draft_hero_options()
	_energy_options = GameManager.get_draft_energy_options()
	_trait_options = GameManager.get_draft_trait_options()
	_init_defaults()
	_build_ui()
	_refresh_slots()
	_refresh_start_button()

func _init_defaults() -> void:
	var defaults := GameManager.get_default_draft()
	_selected_heroes.clear()
	_selected_energies.clear()
	_selected_traits.clear()
	for i in range(SLOT_COUNT):
		var default_hero = defaults[i].get("hero_path", "") if i < defaults.size() else ""
		var default_energy = defaults[i].get("energy_path", "") if i < defaults.size() else ""
		var default_trait = defaults[i].get("trait_path", "") if i < defaults.size() else ""
		_selected_heroes.append(max(_find_option_index(_hero_options, default_hero), 0))
		_selected_energies.append(max(_find_option_index(_energy_options, default_energy), 0))
		_selected_traits.append(max(_find_option_index(_trait_options, default_trait), 0))

func _find_option_index(options: Array, path: String) -> int:
	for i in range(options.size()):
		if options[i].get("path", "") == path:
			return i
	return -1

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.035, 0.03, 0.026, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 36
	root.offset_top = 28
	root.offset_right = -36
	root.offset_bottom = -24
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 18)
	add_child(root)

	var title := Label.new()
	title.text = "Draft de run"
	title.add_theme_font_size_override("font_size", 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Choisis 3 heros, leur energie et leur trait de depart."
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.78, 0.73, 0.66))
	root.add_child(subtitle)

	_slots_row = HBoxContainer.new()
	_slots_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_slots_row.add_theme_constant_override("separation", 18)
	root.add_child(_slots_row)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 16)
	root.add_child(actions)

	var back_button := Button.new()
	back_button.text = "Retour"
	back_button.custom_minimum_size = Vector2(150, 44)
	back_button.pressed.connect(func(): GameManager.cancel_run_draft())
	actions.add_child(back_button)

	_start_button = Button.new()
	_start_button.text = "Commencer"
	_start_button.custom_minimum_size = Vector2(180, 44)
	_start_button.pressed.connect(_on_start_pressed)
	actions.add_child(_start_button)

func _refresh_slots() -> void:
	for child in _slots_row.get_children():
		_slots_row.remove_child(child)
		child.queue_free()

	for slot_index in range(SLOT_COUNT):
		_slots_row.add_child(_make_slot(slot_index))

func _make_slot(slot_index: int) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(330, 520)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(302, 492)
	margin.add_child(scroll)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 9)
	scroll.add_child(box)

	var title := Label.new()
	title.text = "Emplacement %d" % (slot_index + 1)
	title.add_theme_font_size_override("font_size", 21)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var summary := Label.new()
	summary.text = "%s / %s / %s" % [
		_get_hero_name(_hero_options[_selected_heroes[slot_index]]),
		_get_energy_name(_energy_options[_selected_energies[slot_index]]),
		_get_trait_name(_trait_options[_selected_traits[slot_index]]),
	]
	summary.add_theme_font_size_override("font_size", 13)
	summary.add_theme_color_override("font_color", Color(0.94, 0.82, 0.48))
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(summary)

	_add_section_label(box, "Heros")
	for i in range(_hero_options.size()):
		var selected: bool = _selected_heroes[slot_index] == i
		var taken: bool = _is_hero_taken(i, slot_index)
		var button := _make_option_button(_get_hero_name(_hero_options[i]), selected, taken, "Deja choisi dans un autre emplacement." if taken else "")
		button.pressed.connect(_select_hero.bind(slot_index, i))
		box.add_child(button)

	_add_section_label(box, "Energie")
	for i in range(_energy_options.size()):
		var selected: bool = _selected_energies[slot_index] == i
		var button := _make_option_button(_get_energy_name(_energy_options[i]), selected, false)
		var data = _energy_options[i].get("data")
		if data != null and selected:
			button.modulate = data.color
		button.pressed.connect(_select_energy.bind(slot_index, i))
		box.add_child(button)

	_add_section_label(box, "Trait de depart")
	for i in range(_trait_options.size()):
		var selected: bool = _selected_traits[slot_index] == i
		var button := _make_option_button(_get_trait_name(_trait_options[i]), selected, false, _get_trait_description(_trait_options[i]))
		button.pressed.connect(_select_trait.bind(slot_index, i))
		box.add_child(button)

	var trait_note := Label.new()
	trait_note.text = _get_trait_description(_trait_options[_selected_traits[slot_index]])
	trait_note.add_theme_font_size_override("font_size", 12)
	trait_note.add_theme_color_override("font_color", Color(0.72, 0.68, 0.6))
	trait_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(trait_note)

	return panel

func _add_section_label(parent: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(0.82, 0.78, 0.7))
	label.add_theme_font_size_override("font_size", 14)
	parent.add_child(label)

func _make_option_button(label_text: String, selected: bool, disabled: bool, tooltip: String = "") -> Button:
	var button := Button.new()
	var marker := "[x] " if selected else "[ ] "
	button.text = ("[pris] " if disabled and not selected else marker) + label_text
	button.custom_minimum_size = Vector2(290, 30)
	button.toggle_mode = true
	button.button_pressed = selected
	button.disabled = disabled
	button.tooltip_text = tooltip
	if selected:
		button.modulate = Color(1.0, 0.86, 0.48)
	return button

func _is_hero_taken(option_index: int, except_slot: int) -> bool:
	for slot_index in range(_selected_heroes.size()):
		if slot_index != except_slot and _selected_heroes[slot_index] == option_index:
			return true
	return false

func _select_hero(slot_index: int, option_index: int) -> void:
	_selected_heroes[slot_index] = option_index
	_refresh_slots()
	_refresh_start_button()

func _select_energy(slot_index: int, option_index: int) -> void:
	_selected_energies[slot_index] = option_index
	_refresh_slots()
	_refresh_start_button()

func _select_trait(slot_index: int, option_index: int) -> void:
	_selected_traits[slot_index] = option_index
	_refresh_slots()
	_refresh_start_button()

func _refresh_start_button() -> void:
	_start_button.disabled = _hero_options.size() < SLOT_COUNT or _energy_options.is_empty() or _trait_options.is_empty()

func _on_start_pressed() -> void:
	var hero_paths: Array = []
	var energy_paths: Array = []
	var trait_paths: Array = []
	for i in range(SLOT_COUNT):
		hero_paths.append(_hero_options[_selected_heroes[i]]["path"])
		energy_paths.append(_energy_options[_selected_energies[i]]["path"])
		trait_paths.append(_trait_options[_selected_traits[i]].get("path", ""))
	GameManager.confirm_run_draft(hero_paths, energy_paths, trait_paths)

func _get_hero_name(option: Dictionary) -> String:
	var data = option.get("data")
	return data.unit_name if data != null else "Heros"

func _get_energy_name(option: Dictionary) -> String:
	var data = option.get("data")
	return data.energy_name if data != null else "Energie"

func _get_trait_name(option: Dictionary) -> String:
	var data = option.get("data")
	if data != null:
		return data.display_name
	return option.get("name", "Aucun trait")

func _get_trait_description(option: Dictionary) -> String:
	var data = option.get("data")
	if data != null:
		var description = data.get("description")
		return description if typeof(description) == TYPE_STRING else ""
	return option.get("description", "")