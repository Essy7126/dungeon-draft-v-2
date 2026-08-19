@tool
class_name ItemEffectComposer
extends VBoxContainer

var document: ItemStudioDocument = null
var registry := ItemEffectRegistry.new()
var relic_registry := RelicEffectRegistry.new()
var copy_service := ItemDeepCopyService.new()
var add_option: OptionButton
var _updating_controls := false
var _summary_labels := {}


func setup(p_document: ItemStudioDocument) -> void:
	document = p_document
	rebuild()


func rebuild() -> void:
	_updating_controls = true
	_summary_labels.clear()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var header := HBoxContainer.new()
	var title := Label.new()
	title.text = "COMPOSITEUR D’EFFETS"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	add_option = OptionButton.new()
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
	add_child(header)
	if document == null or document.working_copy == null:
		var empty := Label.new()
		empty.text = "Aucun objet chargé."
		add_child(empty)
		_updating_controls = false
		return
	for index in range(document.working_copy.stat_modifiers.size()):
		_add_stat_row(index, document.working_copy.stat_modifiers[index])
	for index in range(document.working_copy.spell_modifiers.size()):
		_add_spell_row(index, document.working_copy.spell_modifiers[index])
	for index in range(document.working_copy.reactive_effects.size()):
		_add_reactive_row(index, document.working_copy.reactive_effects[index])
	if document.working_copy.stat_modifiers.is_empty() \
			and document.working_copy.spell_modifiers.is_empty() \
			and document.working_copy.reactive_effects.is_empty():
		var empty := Label.new()
		empty.text = "Aucun modificateur. Utilisez Ajouter pour composer l’objet."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(empty)
	_updating_controls = false


func refresh_summaries() -> void:
	if document == null or document.working_copy == null:
		return
	for modifier in document.working_copy.spell_modifiers:
		var label := _summary_labels.get(modifier.get_instance_id()) as Label
		if label != null:
			label.text = str(registry.summarize(modifier).get("player", "Effet"))
	for effect in document.working_copy.reactive_effects:
		var label := _summary_labels.get(effect.get_instance_id()) as Label
		if label != null:
			label.text = relic_registry.summarize(effect)


func _add_reactive_row(index: int, effect: ItemReactiveEffectData) -> void:
	var panel := PanelContainer.new()
	var root := VBoxContainer.new()
	panel.add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	var preview_enabled := CheckBox.new()
	preview_enabled.button_pressed = document.is_preview_effect_enabled(&"reactive", index)
	preview_enabled.tooltip_text = "Inclure uniquement dans la prévisualisation ; la donnée sauvegardée reste inchangée"
	preview_enabled.toggled.connect(func(value): document.set_preview_effect_enabled(&"reactive", index, value))
	header.add_child(preview_enabled)
	var summary := Label.new()
	summary.text = relic_registry.summarize(effect)
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(summary)
	_summary_labels[effect.get_instance_id()] = summary
	_add_row_actions(header, &"reactive", index, effect)
	var fields := GridContainer.new()
	fields.columns = 2
	root.add_child(fields)
	_add_descriptor_field(fields, "Déclencheur", RelicEffectRegistry.KIND_TRIGGER, effect.trigger_id, effect, func(value): effect.trigger_id = value)
	_add_descriptor_field(fields, "Cible", RelicEffectRegistry.KIND_TARGET, effect.target_id, effect, func(value): effect.target_id = value)
	_add_descriptor_field(fields, "Résultat", RelicEffectRegistry.KIND_RESULT, effect.result_id, effect, func(value): effect.result_id = value)
	_add_descriptor_field(fields, "Fréquence", RelicEffectRegistry.KIND_FREQUENCY, effect.frequency_id, effect, func(value): effect.frequency_id = value)
	_add_number_field(fields, "Valeur principale", effect.value, -999, 999, 0.01, func(value): effect.value = value)
	_add_number_field(fields, "Seuil", effect.threshold, 0, 1, 0.01, func(value): effect.threshold = value)
	_add_number_field(fields, "Activations max.", effect.max_activations, 1, 99, 1, func(value): effect.max_activations = int(value))
	_add_number_field(fields, "Recharge (tours)", effect.recharge_turns, 1, 99, 1, func(value): effect.recharge_turns = int(value))
	var condition_header := HBoxContainer.new()
	root.add_child(condition_header)
	var condition_label := Label.new()
	condition_label.text = "Conditions"
	condition_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	condition_header.add_child(condition_label)
	var condition_option := OptionButton.new()
	for descriptor in relic_registry.compatible_descriptors(RelicEffectRegistry.KIND_CONDITION, effect):
		condition_option.add_item(str(descriptor.get("label", "Condition")))
		condition_option.set_item_metadata(condition_option.item_count - 1, descriptor.get("id", &""))
	condition_header.add_child(condition_option)
	var add_condition := Button.new()
	add_condition.text = "Ajouter une condition"
	add_condition.disabled = condition_option.item_count == 0
	add_condition.pressed.connect(func():
		if _updating_controls:
			return
		var condition := ItemReactiveConditionData.new()
		condition.condition_id = StringName(condition_option.get_item_metadata(condition_option.selected))
		document.record_edit("Ajouter une condition", func(): effect.conditions.append(condition), ItemStudioDocument.CHANGE_STRUCTURE, "reactive.conditions")
	)
	condition_header.add_child(add_condition)
	for condition_index in range(effect.conditions.size()):
		_add_condition_row(root, effect, condition_index, effect.conditions[condition_index])
	var issues := relic_registry.validate_effect(effect)
	if not issues.is_empty():
		var error := Label.new()
		error.text = "Invalide : %s" % issues[0].get("message", "combinaison incompatible")
		error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		error.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))
		root.add_child(error)
	add_child(panel)


func _add_descriptor_field(
		parent: Control,
		label_text: String,
		kind: StringName,
		current: StringName,
		effect: ItemReactiveEffectData,
		setter: Callable
	) -> void:
	var label := Label.new()
	label.text = label_text
	parent.add_child(label)
	var option := OptionButton.new()
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
	parent.add_child(row)
	var label := Label.new()
	label.text = relic_registry.label(RelicEffectRegistry.KIND_CONDITION, condition.condition_id)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var comparison := OptionButton.new()
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
	value.value_changed.connect(func(new_value):
		if not _updating_controls:
			document.record_edit("Modifier une condition", func(): condition.value = new_value, ItemStudioDocument.CHANGE_VALUE, "reactive.condition", "reactive_condition_%d" % condition.get_instance_id())
	)
	row.add_child(value)
	var remove := Button.new()
	remove.text = "Retirer"
	remove.pressed.connect(func():
		if not _updating_controls:
			document.record_edit("Retirer une condition", func(): effect.conditions.remove_at(index), ItemStudioDocument.CHANGE_STRUCTURE, "reactive.conditions")
	)
	row.add_child(remove)


func _add_stat_row(index: int, modifier: ItemStatModifierData) -> void:
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	panel.add_child(row)
	var enabled := CheckBox.new()
	enabled.button_pressed = document.is_preview_effect_enabled(&"stat", index)
	enabled.tooltip_text = "Inclure uniquement dans la prévisualisation ; la donnée sauvegardée reste inchangée"
	enabled.toggled.connect(func(value): document.set_preview_effect_enabled(&"stat", index, value))
	row.add_child(enabled)
	var stat_option := OptionButton.new()
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
	row.add_child(stat_option)
	var value := SpinBox.new()
	value.min_value = -999.0
	value.max_value = 999.0
	value.step = 0.01
	value.value = modifier.value if modifier != null else 0.0
	value.custom_minimum_size.x = 95
	value.value_changed.connect(func(new_value):
		if not _updating_controls:
			document.record_edit("Modifier la valeur d’effet", func(): modifier.value = new_value, ItemStudioDocument.CHANGE_VALUE, "stat.value", "stat_value_%d" % modifier.get_instance_id())
	)
	row.add_child(value)
	var type_option := OptionButton.new()
	type_option.add_item("Fixe")
	type_option.add_item("Pourcentage")
	type_option.select(modifier.modifier_type if modifier != null else 0)
	type_option.item_selected.connect(func(selected):
		if not _updating_controls:
			document.record_edit("Modifier le type d’effet", func(): modifier.modifier_type = selected, ItemStudioDocument.CHANGE_VALUE, "stat.modifier_type")
	)
	row.add_child(type_option)
	_add_row_actions(row, &"stat", index, modifier)
	add_child(panel)


func _add_spell_row(index: int, modifier: SpellModifier) -> void:
	var panel := PanelContainer.new()
	var root := VBoxContainer.new()
	panel.add_child(root)
	var row := HBoxContainer.new()
	root.add_child(row)
	var enabled := CheckBox.new()
	enabled.button_pressed = document.is_preview_effect_enabled(&"spell", index)
	enabled.tooltip_text = "Inclure uniquement dans la prévisualisation"
	enabled.toggled.connect(func(value): document.set_preview_effect_enabled(&"spell", index, value))
	row.add_child(enabled)
	var summary := Label.new()
	var summary_data := registry.summarize(modifier)
	summary.text = str(summary_data.get("player", "Effet"))
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not summary_data.get("supported", false):
		summary.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))
	row.add_child(summary)
	_summary_labels[modifier.get_instance_id()] = summary
	_add_row_actions(row, &"spell", index, modifier)
	if modifier is ItemSpellModifierData:
		var item_modifier := modifier as ItemSpellModifierData
		var fields := HFlowContainer.new()
		root.add_child(fields)
		_add_text_field(fields, "ID sort", str(item_modifier.target_spell_id), func(value): item_modifier.target_spell_id = StringName(value))
		_add_text_field(fields, "Nom sort (legacy)", item_modifier.target_spell_name, func(value): item_modifier.target_spell_name = value)
		_add_number_field(fields, "Dégâts %", item_modifier.damage_percent * 100.0, 0, 500, 1, func(value): item_modifier.damage_percent = value / 100.0)
		_add_damage_type_field(fields, item_modifier)
		_add_bool_field(fields, "Élémentaire requis", item_modifier.require_elemental_damage, func(value): item_modifier.require_elemental_damage = value)
		_add_number_field(fields, "Seuil PV cible %", item_modifier.target_hp_at_or_below * 100.0 if item_modifier.target_hp_at_or_below >= 0.0 else -1.0, -1, 100, 1, func(value): item_modifier.target_hp_at_or_below = value / 100.0 if value >= 0.0 else -1.0)
		_add_number_field(fields, "Portée", item_modifier.range_bonus, 0, 10, 1, func(value): item_modifier.range_bonus = int(value))
		_add_number_field(fields, "Poussée", item_modifier.push_bonus, 0, 10, 1, func(value): item_modifier.push_bonus = int(value))
		_add_number_field(fields, "Soin/bouclier %", item_modifier.healing_and_shield_percent * 100.0, 0, 500, 1, func(value): item_modifier.healing_and_shield_percent = value / 100.0)
	add_child(panel)


func _add_number_field(
		parent: Control, label_text: String, current: float,
		minimum: float, maximum: float, step: float, setter: Callable
	) -> void:
	var label := Label.new()
	label.text = label_text
	parent.add_child(label)
	var input := SpinBox.new()
	input.min_value = minimum
	input.max_value = maximum
	input.step = step
	input.value = current
	input.custom_minimum_size.x = 78
	input.value_changed.connect(func(value):
		if not _updating_controls:
			document.record_edit("Modifier un paramètre", func(): setter.call(value), ItemStudioDocument.CHANGE_VALUE, label_text, "number_%d" % input.get_instance_id())
	)
	parent.add_child(input)


func _add_text_field(
		parent: Control, label_text: String, current: String, setter: Callable
	) -> void:
	var label := Label.new()
	label.text = label_text
	parent.add_child(label)
	var input := LineEdit.new()
	input.text = current
	input.custom_minimum_size.x = 125
	input.focus_exited.connect(func():
		if not _updating_controls:
			document.record_edit("Modifier un filtre de sort", func(): setter.call(input.text), ItemStudioDocument.CHANGE_VALUE, label_text)
	)
	parent.add_child(input)


func _add_damage_type_field(parent: Control, modifier: ItemSpellModifierData) -> void:
	var label := Label.new()
	label.text = "Type de dégâts"
	parent.add_child(label)
	var option := OptionButton.new()
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
	var input := CheckBox.new()
	input.text = label_text
	input.button_pressed = current
	input.toggled.connect(func(value):
		if not _updating_controls:
			document.record_edit("Modifier une condition de sort", func(): setter.call(value), ItemStudioDocument.CHANGE_VALUE, label_text)
	)
	parent.add_child(input)


func _add_row_actions(row: HBoxContainer, kind: StringName, index: int, resource: Resource) -> void:
	var duplicate_button := Button.new()
	duplicate_button.text = "Dupliquer"
	duplicate_button.pressed.connect(func(): _duplicate_effect(kind, index, resource))
	row.add_child(duplicate_button)
	var up := Button.new()
	up.text = "↑"
	up.disabled = index == 0
	up.tooltip_text = "Monter l’effet"
	up.pressed.connect(func(): _move_effect(kind, index, index - 1))
	row.add_child(up)
	var down := Button.new()
	down.text = "↓"
	var count := document.working_copy.stat_modifiers.size() if kind == &"stat" \
		else (document.working_copy.spell_modifiers.size() if kind == &"spell" \
		else document.working_copy.reactive_effects.size())
	down.disabled = index >= count - 1
	down.tooltip_text = "Descendre l’effet"
	down.pressed.connect(func(): _move_effect(kind, index, index + 1))
	row.add_child(down)
	var remove := Button.new()
	remove.text = "Retirer"
	remove.pressed.connect(func(): _remove_effect(kind, index))
	row.add_child(remove)


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
