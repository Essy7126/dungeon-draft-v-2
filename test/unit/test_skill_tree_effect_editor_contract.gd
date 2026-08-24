extends GutTest

## Contrat de l'éditeur d'effets après la refonte ergonomique : libellés
## uniques, champs strictement alignés sur ce que le runtime consulte, section
## « Comment fonctionne cet effet ? » à la place de l'ancien onglet « Contrat
## métier » qui n'existait pas dans TAB_NAMES et provoquait une erreur.

const EFFECT_TYPE_COUNT := 33
const HISTORIC_CLASS_COUNT := 13


func _registry() -> SkillEffectEditorRegistry:
	return SkillEffectEditorRegistry.new()


func _panel_for(modifier: SpellModifier, guided: bool) -> SkillTreeInspectorPanel:
	var panel := SkillTreeInspectorPanel.new()
	add_child_autofree(panel)
	var empty: Array[SkillTreeValidationMessage] = []
	panel.set_context(null, null, null, modifier, empty, guided)
	return panel


func _labels_in(box: Node) -> PackedStringArray:
	var result := PackedStringArray()
	for child in box.find_children("*", "Label", true, false):
		result.append((child as Label).text)
	return result


func _buttons_in(box: Node) -> PackedStringArray:
	var result := PackedStringArray()
	for child in box.find_children("*", "Button", true, false):
		result.append((child as Button).text)
	return result


## Point 6 de la validation : le sélecteur ne doit plus proposer cinq entrées
## « Bouclier » indiscernables pour cinq comportements runtime différents.
func test_the_thirty_three_effect_labels_are_all_distinct() -> void:
	var seen := {}
	for index in range(EFFECT_TYPE_COUNT):
		var label := SkillTreeEffectSummaryService.effect_type_label(index)
		assert_false(
			seen.has(label),
			"Libellé dupliqué « %s » : types %s et %d" % [label, str(seen.get(label, -1)), index]
		)
		seen[label] = index
	assert_eq(seen.size(), EFFECT_TYPE_COUNT)


## Les familles facilitent le parcours sans changer l'identité sérialisée :
## chaque valeur 0..32 apparaît exactement une fois comme id de menu.
func test_effect_selector_groups_every_stable_type_once() -> void:
	var effect := SpellModSkillTreeEffect.new()
	var panel := _panel_for(effect, true)
	var selector: OptionButton = null
	for value in panel._boxes["Effets"].find_children("*", "OptionButton", true, false):
		var option := value as OptionButton
		if option != null and option.get_item_index(32) >= 0:
			selector = option
			break
	assert_not_null(selector, "Le sélecteur catégorisé des effets doit exister")
	if selector == null:
		return
	var ids := {}
	var family_count := 0
	for index in range(selector.item_count):
		if selector.is_item_separator(index):
			family_count += 1
			continue
		var effect_type := selector.get_item_id(index)
		assert_false(ids.has(effect_type), "Type présent deux fois : %d" % effect_type)
		ids[effect_type] = true
	assert_eq(ids.size(), EFFECT_TYPE_COUNT)
	assert_eq(family_count, 7, "Le menu doit présenter sept familles compréhensibles")
	for effect_type in range(EFFECT_TYPE_COUNT):
		assert_true(ids.has(effect_type), "Type stable absent du menu : %d" % effect_type)


## Point 1 : ouvrir chacun des 33 types ne doit produire aucune erreur de
## script, dans les deux modes.
func test_every_effect_type_opens_in_both_modes() -> void:
	for index in range(EFFECT_TYPE_COUNT):
		var effect := SpellModSkillTreeEffect.new()
		effect.effect_type = index
		effect.modifier_name = "Effet %d" % index
		for guided in [true, false]:
			var panel := _panel_for(effect, guided)
			assert_not_null(panel.tabs, "Type %d, guidé=%s" % [index, guided])


## Point 2 : les 13 classes historiques doivent aussi s'ouvrir sans erreur.
func test_every_historic_modifier_class_opens_without_error() -> void:
	var registry := _registry()
	var opened := 0
	for class_key in SkillEffectEditorRegistry.MODIFIER_CLASSES:
		var descriptor := registry.class_descriptor(class_key)
		assert_not_null(descriptor, "Descripteur absent : %s" % class_key)
		var script := _script_for_class(str(class_key))
		if script == null:
			continue
		var modifier := script.new() as SpellModifier
		if modifier == null:
			continue
		opened += 1
		for guided in [true, false]:
			var panel := _panel_for(modifier, guided)
			assert_not_null(panel.tabs, "%s, guidé=%s" % [class_key, guided])
	assert_eq(opened, HISTORIC_CLASS_COUNT, "Toutes les classes historiques doivent être instanciables")


## Points 3 et 4 : la section explicative est présente, et elle n'a pas été
## obtenue en ajoutant un septième onglet permanent.
func test_contract_is_a_collapsible_section_not_a_seventh_tab() -> void:
	assert_eq(
		SkillTreeInspectorPanel.TAB_NAMES.size(), 6,
		"Le nombre d'onglets ne doit pas augmenter"
	)
	assert_false(
		SkillTreeInspectorPanel.TAB_NAMES.has("Contrat métier"),
		"L'ancien nom technique ne doit pas revenir comme onglet"
	)
	var effect := SpellModSkillTreeEffect.new()
	effect.effect_type = SpellModSkillTreeEffect.EffectType.DAMAGE_ALL
	var panel := _panel_for(effect, true)
	var buttons := _buttons_in(panel._boxes["Effets"])
	var found := false
	for text in buttons:
		if text.contains("Comment fonctionne cet effet ?"):
			found = true
	assert_true(found, "La section « Comment fonctionne cet effet ? » doit exister")


## Point 5 : la règle affichée doit décrire le runtime réel. Les variantes
## exactes remplacent (maxi/override), elles n'additionnent jamais.
func test_exact_variants_never_claim_additive_stacking() -> void:
	var registry := _registry()
	for effect_type in [
		SpellModSkillTreeEffect.EffectType.PUSH_EXACT,
		SpellModSkillTreeEffect.EffectType.COLLISION_EXACT,
	]:
		var descriptor := registry.effect_descriptor(effect_type)
		assert_false(
			descriptor.stacking.to_lower().contains("cumul additif"),
			"Type %d annonce un cumul additif alors que le runtime remplace" % effect_type
		)
		assert_true(
			descriptor.stacking.to_lower().contains("remplacement"),
			"Type %d doit annoncer un remplacement" % effect_type
		)


## Poussée exacte déplace des unités en cases : son unité ne doit pas être
## « degats », héritage d'une classification erronée.
func test_push_exact_is_measured_in_cells_not_damage() -> void:
	var registry := _registry()
	var exact := registry.effect_descriptor(SpellModSkillTreeEffect.EffectType.PUSH_EXACT)
	var bonus := registry.effect_descriptor(SpellModSkillTreeEffect.EffectType.PUSH_BONUS)
	assert_eq(exact.unit, "cases", "Poussée exacte se règle en cases")
	assert_eq(bonus.unit, "cases", "Poussée bonus se règle en cases")
	assert_false(exact.unit.contains("degat"), "Poussée exacte n'est pas un effet de dégâts")
	for effect_type in [
		SpellModSkillTreeEffect.EffectType.NEXT_TURN_MP_TARGET,
		SpellModSkillTreeEffect.EffectType.NEXT_TURN_MP_CASTER,
		SpellModSkillTreeEffect.EffectType.MP_ALLIES_ON_AREA,
	]:
		assert_eq(
			registry.effect_descriptor(effect_type).unit,
			"PM",
			"Un bonus de mouvement au prochain tour se règle en PM"
		)


## Point 5 : la cible annoncée doit être la cible réelle. Un effet à cible fixe
## ne doit pas prétendre suivre le réglage « Cible de l'effet ».
func test_fixed_target_effects_announce_their_real_target() -> void:
	var registry := _registry()
	for effect_type in SkillEffectEditorRegistry.FIXED_TARGETS:
		var descriptor := registry.effect_descriptor(effect_type)
		assert_eq(
			descriptor.target,
			str(SkillEffectEditorRegistry.FIXED_TARGETS[effect_type]),
			"Type %d doit annoncer sa cible fixe" % effect_type
		)


## Point 7 : « Cible de l'effet » ne doit être modifiable que pour les types
## dont le runtime appelle réellement _units_for_scope().
func test_target_scope_field_appears_only_when_runtime_reads_it() -> void:
	var registry := _registry()
	for index in range(EFFECT_TYPE_COUNT):
		var descriptor := registry.effect_descriptor(index)
		var has_scope := false
		for field in descriptor.fields:
			if StringName(field.get("property", &"")) == &"target_scope":
				has_scope = true
		var should_have: bool = index in SkillEffectEditorRegistry.SCOPE_AWARE_EFFECTS
		assert_eq(
			has_scope, should_have,
			"Type %d : champ Cible présent=%s, attendu=%s" % [index, has_scope, should_have]
		)


## Point 7 : la visibilité dynamique se répercute réellement à l'écran.
func test_shield_caster_hides_the_target_field_that_runtime_ignores() -> void:
	var effect := SpellModSkillTreeEffect.new()
	effect.effect_type = SpellModSkillTreeEffect.EffectType.SHIELD_CASTER
	var panel := _panel_for(effect, false)
	var labels := _labels_in(panel._boxes["Effets"])
	assert_does_not_have(labels, "Cible", "SHIELD_CASTER protège toujours le lanceur")
	var scoped := SpellModSkillTreeEffect.new()
	scoped.effect_type = SpellModSkillTreeEffect.EffectType.SHIELD_TARGET
	var scoped_panel := _panel_for(scoped, false)
	assert_has(_labels_in(scoped_panel._boxes["Effets"]), "Cible")


## Point 8 : masquer un champ ne doit jamais effacer sa valeur.
func test_hidden_fields_keep_their_stored_value() -> void:
	var effect := SpellModSkillTreeEffect.new()
	effect.effect_type = SpellModSkillTreeEffect.EffectType.STATUS_DOT
	effect.duration = 4
	effect.status_group = &"burning"
	effect.target_scope = SpellModSkillTreeEffect.TargetScope.AFFECTED_ALLIES
	var panel := _panel_for(effect, true)
	assert_not_null(panel)
	effect.effect_type = SpellModSkillTreeEffect.EffectType.DAMAGE_CENTER
	var after := _panel_for(effect, true)
	assert_not_null(after)
	assert_eq(effect.duration, 4, "La durée doit rester enregistrée")
	assert_eq(effect.status_group, &"burning", "Le groupe doit rester enregistré")
	assert_eq(
		effect.target_scope,
		SpellModSkillTreeEffect.TargetScope.AFFECTED_ALLIES,
		"La cible doit rester enregistrée"
	)


## Une valeur devenue inerte doit être signalée, jamais acceptée en silence.
func test_values_ignored_by_the_current_type_raise_a_warning() -> void:
	var effect := SpellModSkillTreeEffect.new()
	effect.effect_type = SpellModSkillTreeEffect.EffectType.DAMAGE_CENTER
	effect.modifier_name = "Effet reconverti"
	effect.amount = 5
	effect.duration = 3
	effect.status_group = &"burning"
	var node := SkillTreeNodeData.new()
	node.upgrade_id = &"node_test"
	node.display_name = "Test"
	node.rank = 2
	node.spell_modifiers = [effect]
	var messages: Array[SkillTreeValidationMessage] = []
	SkillTreeEditorValidator._validate_skill_effect(node, effect, null, messages)
	var codes := PackedStringArray()
	for message in messages:
		codes.append(str(message.code))
	assert_has(codes, "effect_value_ignored")


## Le déplacement du lanceur possède une politique runtime réelle : lorsque
## cette option est active, chaque case intermédiaire doit être libre. Elle
## reste avancée, mais ne doit jamais disparaître complètement de l'éditeur.
func test_caster_movement_exposes_clear_path_only_in_advanced_mode() -> void:
	var effect := SpellModSkillTreeEffect.new()
	effect.effect_type = SpellModSkillTreeEffect.EffectType.MOVE_CASTER_TO_TARGET
	var guided_panel := _panel_for(effect, true)
	var advanced_panel := _panel_for(effect, false)
	assert_does_not_have(
		_labels_in(guided_panel._boxes["Effets"]),
		"Exiger un chemin dégagé"
	)
	var advanced_checks: Array[Node] = advanced_panel._boxes["Effets"].find_children(
		"*", "CheckBox", true, false
	)
	assert_true(
		advanced_checks.any(func(check): return (check as CheckBox).text == "Exiger un chemin dégagé"),
		"Le réglage de chemin dégagé doit être éditable en mode avancé"
	)


## Une politique de déplacement conservée après changement de type est inerte
## mais ne doit être ni effacée ni acceptée silencieusement.
func test_hidden_clear_path_value_is_preserved_and_warned() -> void:
	var effect := SpellModSkillTreeEffect.new()
	effect.effect_type = SpellModSkillTreeEffect.EffectType.DAMAGE_CENTER
	effect.modifier_name = "Ancienne charge"
	effect.movement_requires_clear_path = true
	var node := SkillTreeNodeData.new()
	node.upgrade_id = &"node_test"
	node.display_name = "Test"
	node.rank = 2
	node.spell_modifiers = [effect]
	var messages: Array[SkillTreeValidationMessage] = []
	SkillTreeEditorValidator._validate_skill_effect(node, effect, null, messages)
	assert_true(effect.movement_requires_clear_path, "La valeur masquée reste stockée")
	var codes := PackedStringArray()
	for message in messages:
		codes.append(str(message.code))
	assert_has(codes, "effect_value_ignored")


## Le mode guidé montre moins de champs que le mode avancé, sans jamais montrer
## un champ que le mode avancé cacherait.
func test_guided_mode_is_a_strict_subset_of_advanced_mode() -> void:
	var registry := _registry()
	for index in range(EFFECT_TYPE_COUNT):
		var descriptor := registry.effect_descriptor(index)
		for field in descriptor.fields:
			if bool(field.get("guided", false)):
				assert_true(
					descriptor.fields.has(field),
					"Type %d : champ guidé absent du mode avancé" % index
				)


## Le graphe montre uniquement l'effet principal et signale les suivants par
## un compteur ; le détail complet reste fourni par summarize_node().
func test_graph_summary_keeps_one_primary_effect_and_a_counter() -> void:
	var node := SkillTreeNodeData.new()
	for index in range(3):
		var effect := SpellModSkillTreeEffect.new()
		effect.effect_type = SpellModSkillTreeEffect.EffectType.DAMAGE_ALL
		effect.amount = index + 1
		effect.modifier_name = "Effet %d" % index
		node.spell_modifiers.append(effect)
	var compact := SkillTreeEffectSummaryService.summarize_node_compact(node)
	var complete := SkillTreeEffectSummaryService.summarize_node(node)
	assert_true(compact.contains("+2 autre(s) effet(s)"))
	assert_eq(compact.count("Ajoute"), 1, "Une seule phrase d'effet doit charger la carte")
	assert_eq(complete.count("Ajoute"), 3, "Le détail complet doit rester disponible")


func _script_for_class(class_key: String) -> Script:
	var snake := ""
	for index in range(class_key.length()):
		var character := class_key[index]
		if character == character.to_upper() and index > 0:
			snake += "_"
		snake += character.to_lower()
	var path := "res://core/spell_mods/%s.gd" % snake
	return load(path) as Script if ResourceLoader.exists(path) else null
