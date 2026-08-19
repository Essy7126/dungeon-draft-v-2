@tool
class_name ItemEffectComposer
extends VBoxContainer

const ACCENT_COLOR := Color(0.48, 0.86, 1.0)
const MUTED_COLOR := Color(0.72, 0.77, 0.84)
const ERROR_COLOR := Color(1.0, 0.45, 0.35)
const STAT_ACCENT := Color(0.40, 0.70, 1.0)
const SPELL_ACCENT := Color(0.36, 0.85, 0.78)
const REACTIVE_ACCENT := Color(0.68, 0.60, 1.0)
const CARD_BACKGROUND := Color(0.157, 0.176, 0.208)
const NESTED_BACKGROUND := Color(0.118, 0.133, 0.161)
const WIDE_BREAKPOINT := 760.0
const FIELD_WIDTH := 180
const NUMBER_WIDTH := 110
const ACTION_DUPLICATE := 0
const ACTION_UP := 1
const ACTION_DOWN := 2
const ACTION_REMOVE := 3

var document: ItemStudioDocument = null
var registry := ItemEffectRegistry.new()
var relic_registry := RelicEffectRegistry.new()
var copy_service := ItemDeepCopyService.new()
var add_option: OptionButton
var _updating_controls := false
var _summary_labels := {}
var _parameter_grids: Array[GridContainer] = []


func _ready() -> void:
	resized.connect(_apply_grid_columns)
	_apply_grid_columns()


func setup(p_document: ItemStudioDocument) -> void:
	document = p_document
	rebuild()


func rebuild() -> void:
	_updating_controls = true
	_summary_labels.clear()
	_parameter_grids.clear()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	add_theme_constant_override("separation", 8)
	add_child(_build_header())
	if document == null or document.working_copy == null:
		add_child(_hint("Aucun objet chargé."))
		_updating_controls = false
		return
	for index in range(document.working_copy.stat_modifiers.size()):
		_add_stat_card(index, document.working_copy.stat_modifiers[index])
	for index in range(document.working_copy.spell_modifiers.size()):
		_add_spell_card(index, document.working_copy.spell_modifiers[index])
	for index in range(document.working_copy.reactive_effects.size()):
		_add_reactive_card(index, document.working_copy.reactive_effects[index])
	if document.working_copy.stat_modifiers.is_empty() \
			and document.working_copy.spell_modifiers.is_empty() \
			and document.working_copy.reactive_effects.is_empty():
		add_child(_hint("Aucun modificateur. Utilisez Ajouter pour composer l’objet."))
	_updating_controls = false
	_apply_grid_columns()


func refresh_summaries() -> void:
	if document == null or document.working_copy == null:
		return
	for modifier in document.working_copy.stat_modifiers:
		_refresh_summary(modifier)
	for modifier in document.working_copy.spell_modifiers:
		_refresh_summary(modifier)
	for effect in document.working_copy.reactive_effects:
		_refresh_summary(effect)


func _refresh_summary(resource: Resource) -> void:
	if resource == null:
		return
	var label := _summary_labels.get(resource.get_instance_id()) as Label
	if label == null:
		return
	var summary := registry.summarize(resource)
	label.text = str(summary.get("player", "Effet"))
	label.add_theme_color_override(
		"font_color",
		Color.WHITE if summary.get("supported", true) else ERROR_COLOR,
	)


func _build_header() -> Control:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	var title := Label.new()
	title.text = "COMPOSITEUR D’EFFETS"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", ACCENT_COLOR)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.clip_text = true
	header.add_child(title)
	add_option = OptionButton.new()
	add_option.custom_minimum_size.x = 170
	add_option.clip_text = true
	add_option.tooltip_text = "Type d’effet enregistré à ajouter"
	var is_relic := document != null and document.working_copy != null \
		and document.working_copy.is_relic()
	if is_relic:
		add_option.add_item("Bloc réactif")
		add_option.set_item_metadata(0, &"relic.reactive")
	else:
		for descriptor in registry.descriptors():
			if descriptor.effect_id.begins_with("use."):
				continue
			add_option.add_item(descriptor.display_name)
			add_option.set_item_metadata(add_option.item_count - 1, descriptor.effect_id)
	header.add_child(add_option)
	var add_button := Button.new()
	add_button.text = "Ajouter"
	add_button.tooltip_text = "Ajouter une instance du type enregistré"
	add_button.pressed.connect(_add_selected_effect)
	header.add_child(add_button)
	return header


func _add_stat_card(index: int, modifier: ItemStatModifierData) -> void:
	var card := _begin_card(STAT_ACCENT, "MODIFICATEUR DE STATISTIQUE", &"stat", index, modifier)
	var fields := _parameter_grid(card)
	var stat_label := Label.new()
	stat_label.text = "Statistique"
	fields.add_child(stat_label)
	var stat_option := OptionButton.new()
	stat_option.custom_minimum_size.x = FIELD_WIDTH
	stat_option.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	stat_option.clip_text = true
	for stat_id in ItemEffectRegistry.STAT_LABELS:
		stat_option.add_item(ItemEffectRegistry.STAT_LABELS[stat_id])
		stat_option.set_item_metadata(stat_option.item_count - 1, stat_id)
		if modifier != null and modifier.stat_id == stat_id:
			stat_option.select(stat_option.item_count - 1)
	stat_option.item_selected.connect(func(selected):
		if _updating_controls:
			return
		document.record_edit("Modifier la statistique", func():
			modifier.stat_id = StringName(stat_option.get_item_metadata(selected))
		, ItemStudioDocument.CHANGE_VALUE, "stat.stat_id")
	)
	fields.add_child(stat_option)
	var value_label := Label.new()
	value_label.text = "Valeur"
	fields.add_child(value_label)
	var value := SpinBox.new()
	value.min_value = -999.0
	value.max_value = 999.0
	value.step = 0.01
	value.value = modifier.value if modifier != null else 0.0
	value.custom_minimum_size.x = NUMBER_WIDTH
	value.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	value.value_changed.connect(func(new_value):
		if not _updating_controls:
			document.record_edit("Modifier la valeur d’effet", func(): modifier.value = new_value, ItemStudioDocument.CHANGE_VALUE, "stat.value", "stat_value_%d" % modifier.get_instance_id())
	)
	fields.add_child(value)
	var type_label := Label.new()
	type_label.text = "Type de valeur"
	fields.add_child(type_label)
	var type_option := OptionButton.new()
	type_option.custom_minimum_size.x = FIELD_WIDTH
	type_option.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	type_option.add_item("Fixe")
	type_option.add_item("Pourcentage")
	type_option.select(modifier.modifier_type if modifier != null else 0)
	type_option.item_selected.connect(func(selected):
		if not _updating_controls:
			document.record_edit("Modifier le type d’effet", func(): modifier.modifier_type = selected, ItemStudioDocument.CHANGE_VALUE, "stat.modifier_type")
	)
	fields.add_child(type_option)


func _add_spell_card(index: int, modifier: SpellModifier) -> void:
	var card := _begin_card(SPELL_ACCENT, "MODIFICATEUR DE SORT", &"spell", index, modifier)
	if not modifier is ItemSpellModifierData:
		return
	var item_modifier := modifier as ItemSpellModifierData
	var fields := _parameter_grid(card)
	_add_text_field(fields, "ID sort", str(item_modifier.target_spell_id), func(value): item_modifier.target_spell_id = StringName(value))
	_add_text_field(fields, "Nom sort (legacy)", item_modifier.target_spell_name, func(value): item_modifier.target_spell_name = value)
	_add_number_field(fields, "Dégâts %", item_modifier.damage_percent * 100.0, 0, 500, 1, func(value): item_modifier.damage_percent = value / 100.0)
	_add_damage_type_field(fields, item_modifier)
	_add_bool_field(fields, "Élémentaire requis", item_modifier.require_elemental_damage, func(value): item_modifier.require_elemental_damage = value)
	_add_number_field(fields, "Seuil PV cible %", item_modifier.target_hp_at_or_below * 100.0 if item_modifier.target_hp_at_or_below >= 0.0 else -1.0, -1, 100, 1, func(value): item_modifier.target_hp_at_or_below = value / 100.0 if value >= 0.0 else -1.0)
	_add_number_field(fields, "Portée", item_modifier.range_bonus, 0, 10, 1, func(value): item_modifier.range_bonus = int(value))
	_add_number_field(fields, "Poussée", item_modifier.push_bonus, 0, 10, 1, func(value): item_modifier.push_bonus = int(value))
	_add_number_field(fields, "Soin/bouclier %", item_modifier.healing_and_shield_percent * 100.0, 0, 500, 1, func(value): item_modifier.healing_and_shield_percent = value / 100.0)


func _add_reactive_card(index: int, effect: ItemReactiveEffectData) -> void:
	var card := _begin_card(REACTIVE_ACCENT, "EFFET RÉACTIF", &"reactive", index, effect)
	var fields := _parameter_grid(card)
	_add_descriptor_field(fields, "Déclencheur", RelicEffectRegistry.KIND_TRIGGER, effect.trigger_id, effect, func(value): effect.trigger_id = value)
	_add_descriptor_field(fields, "Cible", RelicEffectRegistry.KIND_TARGET, effect.target_id, effect, func(value): effect.target_id = value)
	_add_descriptor_field(fields, "Résultat", RelicEffectRegistry.KIND_RESULT, effect.result_id, effect, func(value): effect.result_id = value)
	_add_descriptor_field(fields, "Fréquence", RelicEffectRegistry.KIND_FREQUENCY, effect.frequency_id, effect, func(value): effect.frequency_id = value)
	_add_number_field(fields, "Valeur principale", effect.value, -999, 999, 0.01, func(value): effect.value = value)
	_add_number_field(fields, "Seuil", effect.threshold, 0, 1, 0.01, func(value): effect.threshold = value)
	_add_number_field(fields, "Activations max.", effect.max_activations, 1, 99, 1, func(value): effect.max_activations = int(value))
	_add_number_field(fields, "Recharge (tours)", effect.recharge_turns, 1, 99, 1, func(value): effect.recharge_turns = int(value))
	card.add_child(_build_conditions_block(effect))
	var issues := relic_registry.validate_effect(effect)
	if issues.is_empty():
		return
	var error := Label.new()
	error.text = "Invalide : %s" % issues[0].get("message", "combinaison incompatible")
	error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	error.add_theme_color_override("font_color", ERROR_COLOR)
	card.add_child(error)


func _build_conditions_block(effect: ItemReactiveEffectData) -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = NESTED_BACKGROUND
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	box.add_child(header)
	var label := Label.new()
	label.text = "Conditions"
	label.add_theme_color_override("font_color", MUTED_COLOR)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(label)
	var condition_option := OptionButton.new()
	condition_option.clip_text = true
	condition_option.custom_minimum_size.x = 160
	for descriptor in relic_registry.compatible_descriptors(RelicEffectRegistry.KIND_CONDITION, effect):
		condition_option.add_item(str(descriptor.get("label", "Condition")))
		condition_option.set_item_metadata(condition_option.item_count - 1, descriptor.get("id", &""))
	header.add_child(condition_option)
	var add_condition := Button.new()
	add_condition.text = "Ajouter"
	add_condition.tooltip_text = "Ajouter une condition à cet effet réactif"
	add_condition.disabled = condition_option.item_count == 0
	add_condition.pressed.connect(func():
		if _updating_controls:
			return
		var condition := ItemReactiveConditionData.new()
		condition.condition_id = StringName(condition_option.get_item_metadata(condition_option.selected))
		document.record_edit("Ajouter une condition", func(): effect.conditions.append(condition), ItemStudioDocument.CHANGE_STRUCTURE, "reactive.conditions")
	)
	header.add_child(add_condition)
	if effect.conditions.is_empty():
		var empty := Label.new()
		empty.text = "Aucune condition : l’effet se déclenche dès que le déclencheur survient."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_color_override("font_color", MUTED_COLOR)
		box.add_child(empty)
	for condition_index in range(effect.conditions.size()):
		_add_condition_row(box, effect, condition_index, effect.conditions[condition_index])
	return panel


func _begin_card(
		accent: Color,
		family: String,
		kind: StringName,
		index: int,
		resource: Resource
	) -> VBoxContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_BACKGROUND
	style.border_color = accent
	style.border_width_left = 3
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	style.content_margin_left = 14
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 8)
	panel.add_child(card)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	card.add_child(header)
	var preview_enabled := CheckBox.new()
	preview_enabled.button_pressed = document.is_preview_effect_enabled(kind, index)
	preview_enabled.tooltip_text = "Inclure uniquement dans la prévisualisation ; la donnée sauvegardée reste inchangée"
	preview_enabled.toggled.connect(func(value): document.set_preview_effect_enabled(kind, index, value))
	header.add_child(preview_enabled)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 1)
	header.add_child(titles)
	var family_label := Label.new()
	family_label.text = family
	family_label.add_theme_font_size_override("font_size", 11)
	family_label.add_theme_color_override("font_color", accent)
	titles.add_child(family_label)
	var summary_data := registry.summarize(resource)
	var summary := Label.new()
	summary.add_theme_font_size_override("font_size", 14)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.text = str(summary_data.get("player", "Effet"))
	summary.tooltip_text = str(summary_data.get("technical", ""))
	summary.add_theme_color_override(
		"font_color",
		Color.WHITE if summary_data.get("supported", true) else ERROR_COLOR,
	)
	titles.add_child(summary)
	_summary_labels[resource.get_instance_id()] = summary
	header.add_child(_build_card_menu(kind, index, resource))
	return card


func _build_card_menu(kind: StringName, index: int, resource: Resource) -> MenuButton:
	var menu := MenuButton.new()
	menu.text = "⋯"
	menu.tooltip_text = "Actions de cet effet"
	menu.custom_minimum_size.x = 34
	var popup := menu.get_popup()
	popup.add_item("Dupliquer", ACTION_DUPLICATE)
	popup.add_item("Monter", ACTION_UP)
	popup.add_item("Descendre", ACTION_DOWN)
	popup.add_separator()
	popup.add_item("Retirer", ACTION_REMOVE)
	popup.set_item_disabled(popup.get_item_index(ACTION_UP), index == 0)
	popup.set_item_disabled(popup.get_item_index(ACTION_DOWN), index >= _effect_count(kind) - 1)
	popup.id_pressed.connect(func(id):
		match id:
			ACTION_DUPLICATE: _duplicate_effect(kind, index, resource)
			ACTION_UP: _move_effect(kind, index, index - 1)
			ACTION_DOWN: _move_effect(kind, index, index + 1)
			ACTION_REMOVE: _remove_effect(kind, index)
	)
	return menu


func _effect_count(kind: StringName) -> int:
	if document == null or document.working_copy == null:
		return 0
	if kind == &"stat":
		return document.working_copy.stat_modifiers.size()
	if kind == &"spell":
		return document.working_copy.spell_modifiers.size()
	return document.working_copy.reactive_effects.size()


func _parameter_grid(parent: Control) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	parent.add_child(grid)
	_parameter_grids.append(grid)
	return grid


func _apply_grid_columns() -> void:
	var columns := 4 if size.x >= WIDE_BREAKPOINT else 2
	for grid in _parameter_grids:
		if is_instance_valid(grid):
			grid.columns = columns


func _add_descriptor_field(
		parent: Control,
		label_text: String,
		kind: StringName,
		current: StringName,
		effect: ItemReactiveEffectData,
		setter: Callable
	) -> void:
	parent.add_child(_field_label(label_text))
	var option := OptionButton.new()
	option.custom_minimum_size.x = FIELD_WIDTH
	option.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	option.clip_text = true
	for descriptor in relic_registry.compatible_descriptors(kind, effect):
		option.add_item(str(descriptor.get("label", descriptor.get("id", &""))))
		option.set_item_metadata(option.item_count - 1, descriptor.get("id", &""))
		if StringName(descriptor.get("id", &"")) == current:
			option.select(option.item_count - 1)
	option.item_selected.connect(func(selected):
		if _updating_controls:
			return
		document.record_edit("Modifier %s" % label_text.to_lower(), func():
			setter.call(StringName(option.get_item_metadata(selected)))
		, ItemStudioDocument.CHANGE_VALUE, "reactive.descriptor")
	)
	parent.add_child(option)


func _add_condition_row(
		parent: Control,
		effect: ItemReactiveEffectData,
		index: int,
		condition: ItemReactiveConditionData
	) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var label := Label.new()
	label.text = relic_registry.label(RelicEffectRegistry.KIND_CONDITION, condition.condition_id)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(label)
	var comparison := OptionButton.new()
	comparison.custom_minimum_size.x = 58
	for value in [["=", &"equal"], ["<", &"less"], ["≤", &"less_or_equal"], [">", &"greater"], ["≥", &"greater_or_equal"]]:
		comparison.add_item(value[0])
		comparison.set_item_metadata(comparison.item_count - 1, value[1])
		if condition.comparison == value[1]:
			comparison.select(comparison.item_count - 1)
	comparison.item_selected.connect(func(selected):
		if not _updating_controls:
			document.record_edit("Modifier une condition", func(): condition.comparison = StringName(comparison.get_item_metadata(selected)), ItemStudioDocument.CHANGE_VALUE, "reactive.condition")
	)
	row.add_child(comparison)
	var value := SpinBox.new()
	value.min_value = -999
	value.max_value = 999
	value.step = 0.01
	value.value = condition.value
	value.custom_minimum_size.x = 92
	value.value_changed.connect(func(new_value):
		if not _updating_controls:
			document.record_edit("Modifier une condition", func(): condition.value = new_value, ItemStudioDocument.CHANGE_VALUE, "reactive.condition", "reactive_condition_%d" % condition.get_instance_id())
	)
	row.add_child(value)
	var remove := Button.new()
	remove.text = "Retirer"
	remove.tooltip_text = "Retirer cette condition"
	remove.pressed.connect(func():
		if not _updating_controls:
			document.record_edit("Retirer une condition", func(): effect.conditions.remove_at(index), ItemStudioDocument.CHANGE_STRUCTURE, "reactive.conditions")
	)
	row.add_child(remove)


func _add_number_field(
		parent: Control, label_text: String, current: float,
		minimum: float, maximum: float, step: float, setter: Callable
	) -> void:
	parent.add_child(_field_label(label_text))
	var input := SpinBox.new()
	input.min_value = minimum
	input.max_value = maximum
	input.step = step
	input.value = current
	input.custom_minimum_size.x = NUMBER_WIDTH
	input.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	input.value_changed.connect(func(value):
		if not _updating_controls:
			document.record_edit("Modifier un paramètre", func(): setter.call(value), ItemStudioDocument.CHANGE_VALUE, label_text, "number_%d" % input.get_instance_id())
	)
	parent.add_child(input)


func _add_text_field(
		parent: Control, label_text: String, current: String, setter: Callable
	) -> void:
	parent.add_child(_field_label(label_text))
	var input := LineEdit.new()
	input.text = current
	input.custom_minimum_size.x = 125
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.focus_exited.connect(func():
		if not _updating_controls:
			document.record_edit("Modifier un filtre de sort", func(): setter.call(input.text), ItemStudioDocument.CHANGE_VALUE, label_text)
	)
	parent.add_child(input)


func _add_damage_type_field(parent: Control, modifier: ItemSpellModifierData) -> void:
	parent.add_child(_field_label("Type de dégâts"))
	var option := OptionButton.new()
	option.custom_minimum_size.x = FIELD_WIDTH
	option.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	option.clip_text = true
	for value in [["Tous", -1], ["Physique", 0], ["Magique", 1]]:
		option.add_item(value[0])
		option.set_item_metadata(option.item_count - 1, value[1])
		if int(value[1]) == modifier.damage_type_filter:
			option.select(option.item_count - 1)
	option.item_selected.connect(func(index):
		if _updating_controls:
			return
		document.record_edit("Modifier le type de dégâts", func():
			modifier.damage_type_filter = int(option.get_item_metadata(index))
		, ItemStudioDocument.CHANGE_VALUE, "spell.damage_type")
	)
	parent.add_child(option)


func _add_bool_field(
		parent: Control, label_text: String, current: bool, setter: Callable
	) -> void:
	parent.add_child(_field_label(label_text))
	var input := CheckBox.new()
	input.button_pressed = current
	input.tooltip_text = label_text
	input.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	input.toggled.connect(func(value):
		if not _updating_controls:
			document.record_edit("Modifier une condition de sort", func(): setter.call(value), ItemStudioDocument.CHANGE_VALUE, label_text)
	)
	parent.add_child(input)


func _field_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", MUTED_COLOR)
	return label


func _hint(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", MUTED_COLOR)
	return label


func _add_selected_effect() -> void:
	if document == null or document.working_copy == null or add_option == null or add_option.item_count == 0:
		return
	var effect_id := StringName(add_option.get_item_metadata(add_option.selected))
	if effect_id == &"relic.reactive":
		var reactive := ItemReactiveEffectData.new()
		document.record_edit("Ajouter un effet réactif", func(): document.working_copy.reactive_effects.append(reactive), ItemStudioDocument.CHANGE_STRUCTURE, "reactive_effects")
		return
	var effect := registry.create_effect(effect_id)
	if effect == null:
		return
	document.record_edit("Ajouter un effet", func():
		if effect is ItemStatModifierData:
			document.working_copy.stat_modifiers.append(effect)
		elif effect is SpellModifier:
			document.working_copy.spell_modifiers.append(effect)
	, ItemStudioDocument.CHANGE_STRUCTURE, "effects")


func _duplicate_effect(kind: StringName, index: int, resource: Resource) -> void:
	var duplicate := copy_service.duplicate_effect(resource)
	document.record_edit("Dupliquer un effet", func():
		if kind == &"stat":
			document.working_copy.stat_modifiers.insert(index + 1, duplicate)
		elif kind == &"spell":
			document.working_copy.spell_modifiers.insert(index + 1, duplicate)
		else:
			document.working_copy.reactive_effects.insert(index + 1, duplicate)
	, ItemStudioDocument.CHANGE_STRUCTURE, "effects")


func _remove_effect(kind: StringName, index: int) -> void:
	document.record_edit("Retirer un effet", func():
		if kind == &"stat":
			document.working_copy.stat_modifiers.remove_at(index)
		elif kind == &"spell":
			document.working_copy.spell_modifiers.remove_at(index)
		else:
			document.working_copy.reactive_effects.remove_at(index)
	, ItemStudioDocument.CHANGE_STRUCTURE, "effects")


func _move_effect(kind: StringName, from_index: int, to_index: int) -> void:
	document.record_edit("Réordonner les effets", func():
		var values: Array = document.working_copy.stat_modifiers if kind == &"stat" \
			else (document.working_copy.spell_modifiers if kind == &"spell" \
			else document.working_copy.reactive_effects)
		var temporary = values[from_index]
		values[from_index] = values[to_index]
		values[to_index] = temporary
	, ItemStudioDocument.CHANGE_STRUCTURE, "effects")
