@tool
class_name ItemAnalysisPanel
extends VBoxContainer

var title_label: Label
var content: RichTextLabel


func _ready() -> void:
	custom_minimum_size.x = 310
	title_label = Label.new()
	title_label.text = "ANALYSE ET INTÉGRATION"
	title_label.add_theme_font_size_override("font_size", 16)
	add_child(title_label)
	content = RichTextLabel.new()
	content.bbcode_enabled = true
	content.fit_content = false
	content.scroll_active = true
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(content)


func show_report(
		definition: ItemDefinition,
		validation: Dictionary,
		analysis: Dictionary,
		references: Array[String],
		fingerprint: String,
		comparison := {},
		spell_projection := {}
	) -> void:
	if content == null:
		return
	if definition == null:
		content.text = "[i]Aucun objet sélectionné.[/i]"
		return
	var lines: Array[String] = []
	lines.append("[b]%s[/b] · %s" % [definition.display_name, definition.item_id])
	lines.append("[color=#8fd3ff]Empreinte[/color] %s" % fingerprint.left(16))
	lines.append("\n[b]Validation[/b] — %d erreur(s), %d avertissement(s)" % [
		validation.get("errors", 0), validation.get("warnings", 0),
	])
	for value in validation.get("messages", []) as Array:
		var message := value as Dictionary
		var marker := "✖" if int(message.get("severity", 0)) == ItemStudioValidationMessage.Severity.ERROR else "⚠" \
			if int(message.get("severity", 0)) == ItemStudioValidationMessage.Severity.WARNING else "•"
		lines.append("%s %s" % [marker, message.get("message", "")])
	lines.append("\n[b]Projection runtime isolée[/b]")
	for hero_value in analysis.get("heroes", []) as Array:
		var hero := hero_value as Dictionary
		lines.append("[color=#a8e6a3]%s[/color] — %s" % [hero.get("display_name", "Héros"), "OK" if hero.get("ok", false) else hero.get("error", "non vérifié")])
		var delta := hero.get("delta", {}) as Dictionary
		var changed: Array[String] = []
		for key in delta:
			if not is_zero_approx(float(delta[key])):
				changed.append("%s %+.2f" % [key, delta[key]])
		if not changed.is_empty():
			lines.append("  " + ", ".join(changed))
	for breakpoint_value in analysis.get("breakpoints", []) as Array:
		var breakpoint_data := breakpoint_value as Dictionary
		lines.append("[color=#ffbf69]⚠ %s[/color]" % breakpoint_data.get("message", "Breakpoint"))
	for scenario_value in analysis.get("scenarios", []) as Array:
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
	var frequency_resets := analysis.get("frequency_resets", {}) as Dictionary
	if not frequency_resets.is_empty():
		lines.append("  Réinitialisations : action %s · tour %s · round %s · combat %s" % [
			"OK" if frequency_resets.get(ItemReactiveEffectData.FREQUENCY_ACTION, false) else "ÉCHEC",
			"OK" if frequency_resets.get(ItemReactiveEffectData.FREQUENCY_TURN, false) else "ÉCHEC",
			"OK" if frequency_resets.get(ItemReactiveEffectData.FREQUENCY_ROUND, false) else "ÉCHEC",
			"OK" if frequency_resets.get(ItemReactiveEffectData.FREQUENCY_COMBAT, false) else "ÉCHEC",
		])
	if analysis.has("canonical_unchanged"):
		lines.append("  Définition canonique : %s" % (
			"inchangée" if analysis.get("canonical_unchanged", false) else "MODIFIÉE"
		))
	if not spell_projection.is_empty():
		lines.append("\n[b]Sort projeté[/b] — %s · %s · cible à %.0f %% PV" % [
			spell_projection.get("hero_name", "Héros"),
			spell_projection.get("spell_name", "Sort"),
			float(spell_projection.get("target_hp_ratio", 1.0)) * 100.0,
		])
		if not spell_projection.get("ok", false):
			lines.append("[color=#ff8a80]%s[/color]" % spell_projection.get("error", "Projection impossible"))
		else:
			lines.append("Portée %d → %d · dégâts %d → %d" % [
				spell_projection.get("range_before", 0), spell_projection.get("range_after", 0),
				spell_projection.get("damage_before", 0), spell_projection.get("damage_after", 0),
			])
			lines.append("Soin %d → %d · bouclier %d → %d · poussée %d → %d" % [
				spell_projection.get("heal_before", 0), spell_projection.get("heal_after", 0),
				spell_projection.get("shield_before", 0), spell_projection.get("shield_after", 0),
				spell_projection.get("push_before", 0), spell_projection.get("push_after", 0),
			])
			lines.append("%s · élément %s" % [
				spell_projection.get("damage_type_label", "Type inconnu"),
				spell_projection.get("element_label", "Élément inconnu"),
			])
			for modifier_value in spell_projection.get("modifiers", []) as Array:
				var modifier := modifier_value as Dictionary
				var applicability := "applicable" if modifier.get("applies_to_spell", false) \
					and modifier.get("target_condition_passes", false) else "non applicable"
				lines.append("• %s — %s" % [modifier.get("name", "Effet"), applicability])
			if spell_projection.get("battle_context_required", false):
				lines.append("[i]Les valeurs sont projetées ; la résolution de cible finale requiert le contexte de bataille.[/i]")
	if not comparison.is_empty():
		lines.append("\n[b]Comparaison[/b] — %s" % comparison.get("status", ""))
		lines.append(str(comparison.get("reason", "")))
	lines.append("\n[b]Références entrantes[/b] (%d)" % references.size())
	for path in references.slice(0, 8):
		lines.append("• %s" % path)
	if references.size() > 8:
		lines.append("• … %d autre(s)" % (references.size() - 8))
	lines.append("\n[i]Les diagnostics n’ajustent jamais les données automatiquement.[/i]")
	content.text = "\n".join(lines)


func _target_text(value) -> String:
	if value is Unit:
		return str((value as Unit).get_runtime_stable_id())
	if value is Array:
		var ids: Array[String] = []
		for entry in value as Array:
			ids.append(_target_text(entry))
		return ", ".join(ids)
	return "—" if value == null else str(value)
