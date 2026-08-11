@tool
class_name VFXComposer
extends Control

signal history_state_changed

const PROFILE_PATHS := [
	"res://vfx/profiles/test/shield_lifecycle.tres",
	"res://vfx/profiles/test/lightning_multi_target.tres",
	"res://vfx/profiles/test/player_path_preview.tres",
]
const SCENARIOS := ["Shield", "Cible unique", "Multi-cible", "Chemin court", "Chemin long"]

var document := VFXStudioDocument.new()
var draft_service := VFXDraftService.new()
var catalogue: ItemList
var sequence_list: ItemList
var module_list: ItemList
var scenario_option: OptionButton
var quality_option: OptionButton
var stage: VFXComposerPreviewStage
var timeline_label: RichTextLabel
var status_label: Label
var primary_color: ColorPickerButton
var secondary_color: ColorPickerButton
var gradient_start: ColorPickerButton
var gradient_end: ColorPickerButton
var duration_spin: SpinBox
var offset_spin: SpinBox
var intensity_spin: SpinBox
var curve_mid_spin: SpinBox
var seed_spin: SpinBox
var current_instance: VFXRuntimeInstance
var _selected_sequence := 0
var _selected_module := 0
var _refreshing := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	document.changed.connect(_refresh_all)
	document.history.history_changed.connect(func(): history_state_changed.emit())
	_load_catalogue()


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 6)
	add_child(root)
	var header := Label.new()
	header.text = "VFX COMPOSER — vertical slice technique — aucun ART_APPROVED automatique"
	header.add_theme_color_override("font_color", Color("77d9ff"))
	header.add_theme_font_size_override("font_size", 16)
	root.add_child(header)
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(split)
	_build_catalogue_panel(split)
	_build_preview_panel(split)
	_build_blackboard_panel(split)
	status_label = Label.new()
	status_label.text = "Initialisation du catalogue VFX…"
	status_label.add_theme_color_override("font_color", Color("a8c8d9"))
	root.add_child(status_label)


func _build_catalogue_panel(parent: Node) -> void:
	var panel := VBoxContainer.new()
	panel.custom_minimum_size.x = 230
	parent.add_child(panel)
	panel.add_child(_label("CATALOGUE VFXProfile"))
	catalogue = ItemList.new()
	catalogue.custom_minimum_size.y = 150
	catalogue.item_selected.connect(_on_profile_selected)
	panel.add_child(catalogue)
	panel.add_child(_label("Séquences"))
	sequence_list = ItemList.new()
	sequence_list.custom_minimum_size.y = 115
	sequence_list.item_selected.connect(_on_sequence_selected)
	panel.add_child(sequence_list)
	panel.add_child(_label("Contexte de preview"))
	scenario_option = OptionButton.new()
	for scenario in SCENARIOS:
		scenario_option.add_item(scenario)
	scenario_option.item_selected.connect(func(_index): play_preview())
	panel.add_child(scenario_option)
	var actions := HFlowContainer.new()
	panel.add_child(actions)
	_button(actions, "Play", play_preview)
	_button(actions, "Clear", clear_preview)
	_button(actions, "Replay", play_preview)
	_button(actions, "Draft", save_as_draft)
	_button(actions, "Reload", reload_draft)
	_button(actions, "Valider", validate_document)


func _build_preview_panel(parent: Node) -> void:
	var panel := VBoxContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var preview_header := HFlowContainer.new()
	panel.add_child(preview_header)
	preview_header.add_child(_label("PREVIEW — runner partagé"))
	for value in [0.25, 0.5, 1.0]:
		_button(preview_header, "%sx" % value, func():
			seed_spin.set_meta(&"speed_scale", value)
			play_preview()
		)
	quality_option = OptionButton.new()
	for label in ["LOW", "MEDIUM", "HIGH"]:
		quality_option.add_item(label)
	quality_option.select(2)
	quality_option.item_selected.connect(func(_index): play_preview())
	preview_header.add_child(quality_option)
	_button(preview_header, "Fond clair/sombre", func():
		stage.dark_background = not stage.dark_background
		stage.queue_redraw()
	)
	stage = VFXComposerPreviewStage.new()
	stage.custom_minimum_size = Vector2(680, 470)
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(stage)
	panel.add_child(_label("TIMELINE — chevauchement start/durée"))
	timeline_label = RichTextLabel.new()
	timeline_label.bbcode_enabled = true
	timeline_label.fit_content = true
	timeline_label.custom_minimum_size.y = 105
	panel.add_child(timeline_label)


func _build_blackboard_panel(parent: Node) -> void:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 320
	parent.add_child(scroll)
	var panel := VBoxContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(panel)
	panel.add_child(_label("PILE DE MODULES"))
	module_list = ItemList.new()
	module_list.custom_minimum_size.y = 170
	module_list.item_selected.connect(_on_module_selected)
	panel.add_child(module_list)
	var module_actions := HFlowContainer.new()
	panel.add_child(module_actions)
	_button(module_actions, "+ FlashModule", _add_flash_module)
	panel.add_child(_label("BLACKBOARD"))
	primary_color = _color_field(panel, "Couleur primaire", _edit_primary_color)
	secondary_color = _color_field(panel, "Couleur secondaire", _edit_secondary_color)
	gradient_start = _color_field(panel, "Gradient début", func(color): _edit_gradient(0, color))
	gradient_end = _color_field(panel, "Gradient fin", func(color): _edit_gradient(1, color))
	duration_spin = _spin_field(panel, "Durée", 0.01, 10.0, 0.01, _edit_duration)
	offset_spin = _spin_field(panel, "Start offset", 0.0, 10.0, 0.01, _edit_offset)
	intensity_spin = _spin_field(panel, "Intensité", 0.0, 4.0, 0.01, _edit_intensity)
	curve_mid_spin = _spin_field(panel, "Courbe — valeur médiane", 0.0, 1.0, 0.01, _edit_curve_mid)
	seed_spin = _spin_field(panel, "Seed preview", 0.0, 999999.0, 1.0, func(_value): play_preview())
	seed_spin.value = 424242
	seed_spin.set_meta(&"speed_scale", 1.0)


func _load_catalogue() -> void:
	catalogue.clear()
	for path in PROFILE_PATHS:
		var profile := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as VFXProfile
		if profile == null:
			continue
		var index := catalogue.add_item(profile.display_name)
		catalogue.set_item_metadata(index, path)
	if catalogue.item_count > 0:
		catalogue.select(0)
		_on_profile_selected(0)


func _on_profile_selected(index: int) -> void:
	clear_preview()
	var path := str(catalogue.get_item_metadata(index))
	var profile := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as VFXProfile
	if not document.open_profile(profile):
		_set_status("Profil impossible à ouvrir.", true)
		return
	_selected_sequence = 0
	_selected_module = 0
	_refresh_all()
	play_preview()


func _on_sequence_selected(index: int) -> void:
	_selected_sequence = index
	_selected_module = 0
	_refresh_all()
	play_preview()


func _on_module_selected(index: int) -> void:
	_selected_module = index
	_refresh_blackboard()


func _refresh_all() -> void:
	if document.working_copy == null or not is_instance_valid(sequence_list):
		return
	_refreshing = true
	sequence_list.clear()
	for sequence in document.working_copy.sequences:
		sequence_list.add_item("%s  [%s]" % [sequence.display_name, sequence.sequence_id])
	_selected_sequence = clampi(_selected_sequence, 0, maxi(document.working_copy.sequences.size() - 1, 0))
	if sequence_list.item_count > 0:
		sequence_list.select(_selected_sequence)
	_refresh_module_list()
	_refresh_blackboard()
	_refresh_timeline()
	_refreshing = false
	history_state_changed.emit()


func _refresh_module_list() -> void:
	module_list.clear()
	var sequence := _current_sequence()
	if sequence == null:
		return
	for module in sequence.modules:
		module_list.add_item("%s\n%s" % [module.module_id, module.module_type])
	_selected_module = clampi(_selected_module, 0, maxi(sequence.modules.size() - 1, 0))
	if module_list.item_count > 0:
		module_list.select(_selected_module)


func _refresh_blackboard() -> void:
	var module := _current_module()
	if module == null:
		return
	_refreshing = true
	primary_color.color = module.primary_color
	secondary_color.color = module.secondary_color
	duration_spin.value = module.duration
	offset_spin.value = module.start_offset
	intensity_spin.value = module.intensity
	curve_mid_spin.value = module.response_curve.sample(0.5) if module.response_curve != null else 0.5
	var gradient := module.color_gradient
	gradient_start.color = gradient.colors[0] if gradient != null and not gradient.colors.is_empty() else module.primary_color
	gradient_end.color = gradient.colors[-1] if gradient != null and not gradient.colors.is_empty() else module.secondary_color
	_refreshing = false


func _refresh_timeline() -> void:
	var sequence := _current_sequence()
	if sequence == null:
		timeline_label.text = ""
		return
	var lines: Array[String] = []
	for module in sequence.modules:
		var lead := "·".repeat(int(module.start_offset * 20.0))
		var body := "█".repeat(maxi(1, int(module.duration * 20.0)))
		lines.append("[color=#8edfff]%-20s[/color] %s%s  %.2f→%.2fs" % [
			module.module_id, lead, body, module.start_offset, module.end_time(),
		])
	timeline_label.text = "\n".join(lines)


func play_preview() -> void:
	if _refreshing or document.working_copy == null or _current_sequence() == null:
		return
	clear_preview()
	var context := _preview_context()
	var result := VFXProfileRunner.play(
		document.working_copy, context, _current_sequence().sequence_id, stage, true
	)
	if not bool(result.ok):
		_set_status("Preview refusée : %s" % result.errors, true)
		return
	current_instance = result.instance as VFXRuntimeInstance
	_set_status("Preview — %s — seed %d — fingerprint %s" % [
		document.working_copy.profile_id, int(seed_spin.value), document.current_fingerprint().left(12),
	])


func clear_preview() -> void:
	if is_instance_valid(current_instance):
		current_instance.clear()
		current_instance.free()
	current_instance = null
	if is_instance_valid(stage):
		for child in stage.get_children():
			if child is VFXRuntimeInstance:
				child.free()


func validate_document() -> void:
	var result := VFXProfileValidator.validate(document.working_copy, _preview_context(), _current_sequence().sequence_id)
	_set_status(
		"Validation OK — TECHNICAL_PLACEHOLDER" if bool(result.ok) else "Validation : %s" % result.errors,
		not bool(result.ok),
	)


func test_document() -> void:
	validate_document()
	play_preview()


func save_as_draft() -> void:
	var result := draft_service.save_draft(document)
	_set_status("Draft sauvé : %s" % result.get("path", "") if bool(result.ok) else str(result.error), not bool(result.ok))


func reload_draft() -> void:
	if document.working_copy == null:
		return
	var result := draft_service.load_draft(document.working_copy.profile_id)
	if not bool(result.ok):
		_set_status(str(result.error), true)
		return
	document.open_profile(result.profile as VFXProfile)
	_set_status("Draft rechargé depuis user://.")
	play_preview()


func _preview_context() -> VFXExecutionContext:
	var seed := int(seed_spin.value) if is_instance_valid(seed_spin) else 424242
	var speed := float(seed_spin.get_meta(&"speed_scale", 1.0)) if is_instance_valid(seed_spin) else 1.0
	var quality := quality_option.selected if is_instance_valid(quality_option) else 2
	var scenario := scenario_option.selected if is_instance_valid(scenario_option) else 0
	var values := {
		"seed": seed, "speed_scale": speed, "quality_tier": quality,
		"preview_mode": true, "target_layer": stage, "magnitude": 0.78,
		"consumer_kind": &"PLAYER_CONTROLLED",
	}
	match scenario:
		0:
			values.merge({"target_world": Vector2(350, 235), "impact_world_points": PackedVector2Array([Vector2(390, 220)])})
		1:
			values.merge({"origin_world": Vector2(150, 255), "target_world": Vector2(520, 220), "impact_world_points": PackedVector2Array([Vector2(520, 220)])})
		2:
			values.merge({"origin_world": Vector2(150, 245), "target_world": Vector2(500, 245), "impact_world_points": PackedVector2Array([Vector2(430, 125), Vector2(545, 245), Vector2(430, 365)])})
		3, 4:
			var cells: Array[Vector2i] = []
			var points := PackedVector2Array()
			var count := 5 if scenario == 3 else 9
			for index in count:
				cells.append(Vector2i(index, index % 2))
				points.append(Vector2(120 + index * 57, 215 + (index % 2) * 28))
			values.merge({
				"origin_cell": cells[0], "target_cell": cells[-1],
				"ordered_path_cells": cells, "path_world_points": points,
				"origin_world": points[0], "target_world": points[-1],
				"impact_world_points": PackedVector2Array([points[-1]]), "path_valid": true,
			})
	return VFXExecutionContext.create(values)


func _add_flash_module() -> void:
	var sequence := _current_sequence()
	if sequence == null:
		return
	document.record_edit("Ajouter FlashModule", func():
		var module := VFXModuleData.new()
		module.module_id = StringName("flash_%d" % sequence.modules.size())
		module.module_type = &"FlashModule"
		module.start_offset = sequence.duration() * 0.5
		module.duration = 0.4
		module.context_requirements = [&"target_world"]
		module.primary_color = Color(0.8, 0.95, 1.0, 0.9)
		module.parameters = {"count": 7}
		sequence.modules.append(module)
	)
	_selected_module = sequence.modules.size() - 1
	_refresh_all()


func _edit_primary_color(value: Color) -> void:
	_edit_module("Couleur primaire", func(module): module.primary_color = value)


func _edit_secondary_color(value: Color) -> void:
	_edit_module("Couleur secondaire", func(module): module.secondary_color = value)


func _edit_duration(value: float) -> void:
	_edit_module("Durée du module", func(module): module.duration = value)


func _edit_offset(value: float) -> void:
	_edit_module("Start offset", func(module): module.start_offset = value)


func _edit_intensity(value: float) -> void:
	_edit_module("Intensité", func(module): module.intensity = value)


func _edit_gradient(index: int, color: Color) -> void:
	_edit_module("Gradient", func(module):
		if module.color_gradient == null:
			module.color_gradient = Gradient.new()
		var colors: PackedColorArray = module.color_gradient.colors
		if colors.size() < 2:
			colors = PackedColorArray([module.primary_color, module.secondary_color])
		colors[index] = color
		module.color_gradient.colors = colors
	)


func _edit_curve_mid(value: float) -> void:
	_edit_module("Courbe de réponse", func(module):
		var curve := Curve.new()
		curve.add_point(Vector2(0, 0))
		curve.add_point(Vector2(0.5, value))
		curve.add_point(Vector2(1, 1))
		module.response_curve = curve
	)


func _edit_module(action_name: String, mutator: Callable) -> void:
	if _refreshing or _current_module() == null:
		return
	document.record_edit(action_name, func(): mutator.call(_current_module()))
	_refresh_timeline()
	play_preview()


func _current_sequence() -> VFXSequenceData:
	if document.working_copy == null or document.working_copy.sequences.is_empty():
		return null
	return document.working_copy.sequences[clampi(_selected_sequence, 0, document.working_copy.sequences.size() - 1)]


func _current_module() -> VFXModuleData:
	var sequence := _current_sequence()
	if sequence == null or sequence.modules.is_empty():
		return null
	return sequence.modules[clampi(_selected_module, 0, sequence.modules.size() - 1)]


func history_can_undo() -> bool: return document.history.can_undo()
func history_can_redo() -> bool: return document.history.can_redo()
func history_undo() -> bool: return document.history.undo()
func history_redo() -> bool: return document.history.redo()
func history_undo_name() -> String: return document.history.get_undo_action_name()
func history_redo_name() -> String: return document.history.get_redo_action_name()
func history_entries() -> Array[Dictionary]: return document.history.get_history_entries()
func history_current_index() -> int: return document.history.get_current_index()
func history_jump_to(index: int) -> bool: return document.history.jump_to(index)
func history_document_name() -> String: return document.working_copy.display_name if document.working_copy != null else "Aucun VFXProfile"
func history_opening_is_saved() -> bool: return document.history.get_current_index() == 0 and document.history.is_at_saved_state()
func history_is_at_saved_state() -> bool: return document.history.is_at_saved_state()
func ensure_initial_content_loaded() -> void:
	if document.working_copy == null:
		_load_catalogue()
func prepare_for_close() -> void: clear_preview()


func get_state_snapshot() -> Dictionary:
	return {
		"profile": catalogue.get_selected_items()[0] if not catalogue.get_selected_items().is_empty() else 0,
		"sequence": _selected_sequence,
		"scenario": scenario_option.selected,
		"quality": quality_option.selected,
	}


func apply_state_snapshot(state: Dictionary) -> void:
	if catalogue == null or catalogue.item_count == 0:
		return
	var profile_index := clampi(int(state.get("profile", 0)), 0, catalogue.item_count - 1)
	catalogue.select(profile_index)
	_on_profile_selected(profile_index)
	_selected_sequence = clampi(int(state.get("sequence", 0)), 0, maxi(sequence_list.item_count - 1, 0))
	scenario_option.select(clampi(int(state.get("scenario", 0)), 0, SCENARIOS.size() - 1))
	quality_option.select(clampi(int(state.get("quality", 2)), 0, 2))
	_refresh_all()


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _color_field(parent: VBoxContainer, label_text: String, callback: Callable) -> ColorPickerButton:
	parent.add_child(_label(label_text))
	var field := ColorPickerButton.new()
	field.color_changed.connect(callback)
	parent.add_child(field)
	return field


func _spin_field(parent: VBoxContainer, label_text: String, minimum: float, maximum: float, step: float, callback: Callable) -> SpinBox:
	parent.add_child(_label(label_text))
	var field := SpinBox.new()
	field.min_value = minimum
	field.max_value = maximum
	field.step = step
	field.value_changed.connect(callback)
	parent.add_child(field)
	return field


func _set_status(text: String, error := false) -> void:
	status_label.text = text
	status_label.add_theme_color_override("font_color", Color("ff8f89") if error else Color("9fe6bd"))
