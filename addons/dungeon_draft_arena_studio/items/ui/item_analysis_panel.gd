@tool
class_name ItemAnalysisPanel
extends VBoxContainer

signal expanded_changed(expanded: bool)

const ACCENT_COLOR := Color(0.48, 0.86, 1.0)
const MUTED_COLOR := Color(0.72, 0.77, 0.84)
const ERROR_COLOR := Color(1.0, 0.45, 0.35)
const WARNING_COLOR := Color(1.0, 0.75, 0.41)
const OK_COLOR := Color(0.66, 0.9, 0.64)
const SECTION_RESULT := 0
const SECTION_WARNINGS := 1
const SECTION_REFERENCES := 2
const SECTION_COMPARISON := 3

var controls_container: HFlowContainer
var summary_label: RichTextLabel
var toggle_button: Button
var body: PanelContainer
var tabs: TabContainer
var result_text: RichTextLabel
var warning_box: VBoxContainer
var reference_box: VBoxContainer
var comparison_text: RichTextLabel

var _expanded := false
var _definition: ItemDefinition = null
var _validation := {}
var _analysis := {}
var _references: Array[String] = []
var _fingerprint := ""
var _comparison := {}
var _spell_projection := {}
var _previous_error_count := 0
var _had_comparison := false


func _ready() -> void:
	add_theme_constant_override("separation", 0)
	add_child(_build_bar())
	add_child(_build_body())
	_apply_expanded()
	_render()


func is_expanded() -> bool:
	return _expanded


func set_expanded(value: bool) -> void:
	if _expanded == value:
		return
	_expanded = value
	_apply_expanded()
	expanded_changed.emit(_expanded)


func open_section(section: int) -> void:
	if tabs != null:
		tabs.current_tab = clampi(section, 0, tabs.get_tab_count() - 1)
	set_expanded(true)


func show_report(
		definition: ItemDefinition,
		validation: Dictionary,
		analysis: Dictionary,
		references: Array[String],
		fingerprint: String,
		comparison := {},
		spell_projection := {}
	) -> void:
	_definition = definition
	_validation = validation
	_analysis = analysis
	_references = references
	_fingerprint = fingerprint
	_comparison = comparison
	_spell_projection = spell_projection
	var errors := int(validation.get("errors", 0))
	if errors > 0 and _previous_error_count == 0:
		open_section(SECTION_WARNINGS)
	_previous_error_count = errors
	var has_comparison := not comparison.is_empty()
	if has_comparison and not _had_comparison:
		open_section(SECTION_COMPARISON)
	_had_comparison = has_comparison
	_render()


func _build_bar() -> Control:
	var panel := PanelContainer.new()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)
	var title := Label.new()
	title.text = "ANALYSE"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", ACCENT_COLOR)
	row.add_child(title)
	summary_label = RichTextLabel.new()
	summary_label.bbcode_enabled = true
	summary_label.scroll_active = false
	summary_label.fit_content = true
	summary_label.custom_minimum_size.y = 22
	summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(summary_label)
	toggle_button = Button.new()
	toggle_button.tooltip_text = "Afficher ou masquer le détail de l’analyse"
	toggle_button.pressed.connect(func(): set_expanded(not _expanded))
	row.add_child(toggle_button)
	return panel


func _build_body() -> Control:
	body = PanelContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 10)
	body.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	controls_container = HFlowContainer.new()
	controls_container.add_theme_constant_override("h_separation", 8)
	controls_container.add_theme_constant_override("v_separation", 6)
	box.add_child(controls_container)
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.custom_minimum_size.y = 190
	box.add_child(tabs)
	result_text = _add_text_tab("Résultat", "Projection runtime isolée du sort et de l’objet")
	warning_box = _add_list_tab("Avertissements", "Messages de validation, erreurs d’abord")
	reference_box = _add_list_tab("Références", "Ressources qui référencent cet objet")
	comparison_text = _add_text_tab("Comparaison", "Comparaison prudente avec un objet compatible")
	return body


func _add_text_tab(tab_title: String, tooltip: String) -> RichTextLabel:
	var text := RichTextLabel.new()
	text.name = tab_title
	text.bbcode_enabled = true
	text.scroll_active = true
	text.tooltip_text = tooltip
	text.selection_enabled = true
	tabs.add_child(text)
	tabs.set_tab_title(tabs.get_tab_count() - 1, tab_title)
	return text


func _add_list_tab(tab_title: String, tooltip: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = tab_title
	scroll.tooltip_text = tooltip
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	tabs.set_tab_title(tabs.get_tab_count() - 1, tab_title)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	scroll.add_child(box)
	return box


func _apply_expanded() -> void:
	if body != null:
		body.visible = _expanded
	if toggle_button != null:
		toggle_button.text = "Fermer ▾" if _expanded else "Ouvrir ▴"
	size_flags_vertical = Control.SIZE_EXPAND_FILL if _expanded else Control.SIZE_SHRINK_BEGIN


func _render() -> void:
	if summary_label == null:
		return
	_render_summary()
	_render_result()
	_render_warnings()
	_render_references()
	_render_comparison()


func _render_summary() -> void:
	if _definition == null:
		summary_label.text = "[i]Aucun objet sélectionné.[/i]"
		return
	var errors := int(_validation.get("errors", 0))
	var warnings := int(_validation.get("warnings", 0))
	var parts: Array[String] = []
	parts.append("[color=#%s]%s %d erreur%s[/color]" % [
		(ERROR_COLOR if errors > 0 else OK_COLOR).to_html(false),
		"✖" if errors > 0 else "✓", errors, "s" if errors > 1 else "",
	])
	parts.append("[color=#%s]⚠ %d avertissement%s[/color]" % [
		(WARNING_COLOR if warnings > 0 else MUTED_COLOR).to_html(false),
		warnings, "s" if warnings > 1 else "",
	])
	parts.append("[color=#%s]%d référence%s[/color]" % [
		MUTED_COLOR.to_html(false), _references.size(), "s" if _references.size() > 1 else "",
	])
	summary_label.text = " · ".join(parts)


func _render_result() -> void:
	if _definition == null:
		result_text.text = "[i]Aucun objet sélectionné.[/i]"
		return
	var lines: Array[String] = []
	lines.append("[b]%s[/b] · %s" % [_definition.display_name, _definition.item_id])
	lines.append("[color=#%s]Empreinte %s[/color]" % [MUTED_COLOR.to_html(false), _fingerprint.left(16)])
	lines.append("\n[b]Projection runtime isolée[/b]")
	for hero_value in _analysis.get("heroes", []) as Array:
		var hero := hero_value as Dictionary
		lines.append("[color=#%s]%s[/color] — %s" % [
			OK_COLOR.to_html(false), hero.get("display_name", "Héros"),
			"OK" if hero.get("ok", false) else hero.get("error", "non vérifié"),
		])
		var delta := hero.get("delta", {}) as Dictionary
		var changed: Array[String] = []
		for key in delta:
			if not is_zero_approx(float(delta[key])):
				changed.append("%s %+.2f" % [key, delta[key]])
		if not changed.is_empty():
			lines.append("  " + ", ".join(changed))
	for breakpoint_value in _analysis.get("breakpoints", []) as Array:
		var breakpoint_data := breakpoint_value as Dictionary
		lines.append("[color=#%s]⚠ %s[/color]" % [
			WARNING_COLOR.to_html(false), breakpoint_data.get("message", "Breakpoint"),
		])
	for scenario_value in _analysis.get("scenarios", []) as Array:
		var scenario := scenario_value as Dictionary
		lines.append("%s Effet %d — %s" % [
			"✓" if scenario.get("triggered", false) else "–",
			int(scenario.get("effect_index", 0)) + 1,
			scenario.get("reason", ""),
		])
		var remaining := int(scenario.get("remaining", -1))
		lines.append("  Scénario %s · déclencheur %s · cible %s" % [
			scenario.get("scenario_id", &"runtime"),
			scenario.get("trigger_id", &"inconnu"),
			_target_text(scenario.get("target")),
		])
		lines.append("  Avant %s → après %s · activations %s" % [
			str(scenario.get("before", {})), str(scenario.get("after", {})),
			"sans limite" if remaining < 0 else str(remaining),
		])
	var frequency_resets := _analysis.get("frequency_resets", {}) as Dictionary
	if not frequency_resets.is_empty():
		lines.append("  Réinitialisations : action %s · tour %s · round %s · combat %s" % [
			"OK" if frequency_resets.get(ItemReactiveEffectData.FREQUENCY_ACTION, false) else "ÉCHEC",
			"OK" if frequency_resets.get(ItemReactiveEffectData.FREQUENCY_TURN, false) else "ÉCHEC",
			"OK" if frequency_resets.get(ItemReactiveEffectData.FREQUENCY_ROUND, false) else "ÉCHEC",
			"OK" if frequency_resets.get(ItemReactiveEffectData.FREQUENCY_COMBAT, false) else "ÉCHEC",
		])
	if _analysis.has("canonical_unchanged"):
		lines.append("  Définition canonique : %s" % (
			"inchangée" if _analysis.get("canonical_unchanged", false) else "MODIFIÉE"
		))
	if not _spell_projection.is_empty():
		lines.append("\n[b]Sort projeté[/b] — %s · %s · cible à %.0f %% PV" % [
			_spell_projection.get("hero_name", "Héros"),
			_spell_projection.get("spell_name", "Sort"),
			float(_spell_projection.get("target_hp_ratio", 1.0)) * 100.0,
		])
		if not _spell_projection.get("ok", false):
			lines.append("[color=#%s]%s[/color]" % [
				ERROR_COLOR.to_html(false),
				_spell_projection.get("error", "Projection impossible"),
			])
		else:
			lines.append("Portée %d → %d · dégâts %d → %d" % [
				_spell_projection.get("range_before", 0), _spell_projection.get("range_after", 0),
				_spell_projection.get("damage_before", 0), _spell_projection.get("damage_after", 0),
			])
			lines.append("Soin %d → %d · bouclier %d → %d · poussée %d → %d" % [
				_spell_projection.get("heal_before", 0), _spell_projection.get("heal_after", 0),
				_spell_projection.get("shield_before", 0), _spell_projection.get("shield_after", 0),
				_spell_projection.get("push_before", 0), _spell_projection.get("push_after", 0),
			])
			lines.append("%s · élément %s" % [
				_spell_projection.get("damage_type_label", "Type inconnu"),
				_spell_projection.get("element_label", "Élément inconnu"),
			])
			for modifier_value in _spell_projection.get("modifiers", []) as Array:
				var modifier := modifier_value as Dictionary
				var applicability := "applicable" if modifier.get("applies_to_spell", false) \
					and modifier.get("target_condition_passes", false) else "non applicable"
				lines.append("• %s — %s" % [modifier.get("name", "Effet"), applicability])
			if _spell_projection.get("battle_context_required", false):
				lines.append("[i]Les valeurs sont projetées ; la résolution de cible finale requiert le contexte de bataille.[/i]")
	lines.append("\n[i]Les diagnostics n’ajustent jamais les données automatiquement.[/i]")
	result_text.text = "\n".join(lines)


func _render_warnings() -> void:
	for child in warning_box.get_children():
		warning_box.remove_child(child)
		child.queue_free()
	var messages := (_validation.get("messages", []) as Array).duplicate()
	messages.sort_custom(func(a, b) -> bool:
		return int((a as Dictionary).get("severity", 0)) > int((b as Dictionary).get("severity", 0))
	)
	if messages.is_empty():
		warning_box.add_child(_muted_label(
			"Aucun message de validation." if _definition != null else "Aucun objet sélectionné."
		))
	for value in messages:
		var message := value as Dictionary
		var severity := int(message.get("severity", 0))
		var marker := "•"
		var color := MUTED_COLOR
		if severity == ItemStudioValidationMessage.Severity.ERROR:
			marker = "✖"
			color = ERROR_COLOR
		elif severity == ItemStudioValidationMessage.Severity.WARNING:
			marker = "⚠"
			color = WARNING_COLOR
		var label := Label.new()
		label.text = "%s  %s" % [marker, message.get("message", "")]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_color_override("font_color", color)
		warning_box.add_child(label)
	_set_tab_counter(SECTION_WARNINGS, "Avertissements", messages.size())


func _render_references() -> void:
	for child in reference_box.get_children():
		reference_box.remove_child(child)
		child.queue_free()
	if _references.is_empty():
		reference_box.add_child(_muted_label("Aucune référence entrante observée."))
	for path in _references:
		var label := Label.new()
		label.text = path
		label.tooltip_text = path
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.add_theme_color_override("font_color", MUTED_COLOR)
		reference_box.add_child(label)
	_set_tab_counter(SECTION_REFERENCES, "Références", _references.size())


func _render_comparison() -> void:
	if _comparison.is_empty():
		comparison_text.text = "[i]Choisissez un objet dans « Comparer avec… » pour confronter deux définitions compatibles.[/i]"
		return
	comparison_text.text = "[b]%s[/b]\n%s" % [
		_comparison.get("status", ""), _comparison.get("reason", ""),
	]


func _set_tab_counter(index: int, tab_title: String, count: int) -> void:
	if tabs == null or index >= tabs.get_tab_count():
		return
	tabs.set_tab_title(index, tab_title if count == 0 else "%s (%d)" % [tab_title, count])


func _muted_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", MUTED_COLOR)
	return label


func _target_text(value) -> String:
	if value is Unit:
		return str((value as Unit).get_runtime_stable_id())
	if value is Array:
		var ids: Array[String] = []
		for entry in value as Array:
			ids.append(_target_text(entry))
		return ", ".join(ids)
	return "—" if value == null else str(value)
