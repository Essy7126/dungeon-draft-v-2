class_name ChampionCodex
extends Control

signal close_requested
signal build_changed

const STYLE := preload("res://ui/progression/theme/spell_codex_style.gd")
const GOLD := Color("d6b77c")
const TEXT := Color("f0ebdc")
const MUTED := Color("a6b4ad")
const GREEN := Color("95c6a8")

var character_state: CharacterRunState = null
var read_only := false
var _section_id: StringName = &""
var _selected_node_id: StringName = &""
var _selected_spell: Spell = null
var _title: Label
var _summary: Label
var _points: Label
var _xp: ProgressBar
var _navigation: VBoxContainer
var _content: VBoxContainer
var _detail: VBoxContainer
var _action: Button
var _notice: Label
var _spells: HBoxContainer
var _search: LineEdit
var _node_buttons: Dictionary = {}
var _nav_buttons: Dictionary = {}
var _close_button: Button
var _built := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	refresh()


func configure(state: CharacterRunState, p_read_only: bool = false) -> void:
	_disconnect_state()
	character_state = state
	read_only = p_read_only
	if character_state != null:
		character_state.champion_changed.connect(refresh)
	if is_node_ready():
		refresh()
		_focus_close.call_deferred()


func _exit_tree() -> void:
	_disconnect_state()


func _disconnect_state() -> void:
	if character_state != null and character_state.champion_changed.is_connected(refresh):
		character_state.champion_changed.disconnect(refresh)


func refresh() -> void:
	if not _built or character_state == null or character_state.champion_progression == null:
		return
	var champion := character_state.champion_progression
	var profile := champion.profile
	_title.text = "%s · Codex des maîtrises" % character_state.unit.unit_name
	_summary.text = "NIVEAU %d / %d     ·     %d / %d PV     ·     %d Prouesse     ·     %d PA / %d PM" % [champion.current_level, profile.level_cap, character_state.unit.current_hp, character_state.unit.max_hp.get_int(), character_state.unit.attack_power.get_int(), character_state.unit.max_ap.get_int(), character_state.unit.max_mp.get_int()]
	_points.text = "%d points de maîtrise    ·    %d caractéristiques" % [champion.unspent_mastery_points, champion.unspent_attribute_points]
	var threshold := profile.xp_for_level(champion.current_level)
	var next_threshold := profile.xp_for_level(mini(champion.current_level + 1, profile.level_cap))
	_xp.max_value = maxi(1, next_threshold - threshold)
	_xp.value = champion.current_xp - threshold if champion.current_level < profile.level_cap else _xp.max_value
	_xp.tooltip_text = "%d XP / %d · XP accordée à la victoire" % [champion.current_xp, next_threshold]
	_notice.text = "CONSULTATION · Explorez les effets et les prérequis" if read_only else "Les investissements sont définitifs pour cette run. Sélectionnez une maîtrise avant de l’acquérir."
	_build_navigation()
	_build_spell_strip()
	_build_content()
	_refresh_detail()


func get_node_buttons() -> Dictionary:
	return _node_buttons.duplicate()


func get_action_button() -> Button:
	return _action


func get_close_button() -> Button:
	return _close_button


func select_section(section_id: StringName) -> void:
	if character_state != null and section_id not in [&"advanced", &"attributes"]:
		var catalog := character_state.progression_profile.mastery_catalog
		if SkillTreeResolver.champion_doctrine_by_id(catalog.doctrines, section_id) == null:
			section_id = catalog.doctrines[0].discipline_id
	_section_id = section_id
	_selected_node_id = &""
	_selected_spell = null
	_search.text = ""
	refresh()
	_focus_navigation.call_deferred()


func inspect_node(node_id: StringName) -> void:
	_selected_node_id = node_id
	_selected_spell = null
	_refresh_node_styles()
	_refresh_detail()


func set_search_query(query: String) -> void:
	_search.text = query
	_build_content()


func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var background := Panel.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.add_theme_stylebox_override("panel", STYLE.box(Color("101b1e"), GOLD, 9))
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 12)
	margin.add_child(main)
	var header := HBoxContainer.new()
	main.add_child(header)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(identity)
	identity.add_child(_label("LE LIVRE DU CHAMPION", 11, GOLD))
	_title = _label("Codex des maîtrises", 26, TEXT, true)
	identity.add_child(_title)
	_summary = _label("", 14, MUTED)
	identity.add_child(_summary)
	var status := VBoxContainer.new()
	status.custom_minimum_size.x = 295
	header.add_child(status)
	_points = _label("", 15, GOLD)
	_points.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.add_child(_points)
	_xp = ProgressBar.new()
	_xp.custom_minimum_size.y = 6
	_xp.show_percentage = false
	_xp.add_theme_stylebox_override("background", STYLE.box(Color("283431"), Color("283431"), 3))
	_xp.add_theme_stylebox_override("fill", STYLE.box(GOLD, GOLD, 3))
	status.add_child(_xp)
	_close_button = _button("Fermer  ×", 13)
	_close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_close_button.pressed.connect(func() -> void: close_requested.emit())
	status.add_child(_close_button)
	_spells = HBoxContainer.new()
	_spells.add_theme_constant_override("separation", 10)
	main.add_child(_spells)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	main.add_child(body)
	var nav_panel := _panel(Color("142125"), 14)
	nav_panel.custom_minimum_size.x = 205
	body.add_child(nav_panel)
	_navigation = VBoxContainer.new()
	_navigation.add_theme_constant_override("separation", 8)
	nav_panel.add_child(_navigation)
	var canvas := _panel(Color("17272a"), 16)
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(canvas)
	var canvas_box := VBoxContainer.new()
	canvas_box.add_theme_constant_override("separation", 12)
	canvas.add_child(canvas_box)
	_search = LineEdit.new()
	_search.placeholder_text = "Rechercher une maîtrise…"
	_search.custom_minimum_size.y = 36
	_search.add_theme_font_override("font", STYLE.BODY)
	_search.add_theme_font_size_override("font_size", 14)
	_search.add_theme_stylebox_override("normal", STYLE.box(STYLE.INK, STYLE.BORDER, 5, 9))
	_search.text_changed.connect(func(_query: String) -> void: _build_content())
	canvas_box.add_child(_search)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	canvas_box.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	scroll.add_child(_content)
	var detail_panel := _panel(Color("122024"), 17)
	detail_panel.custom_minimum_size.x = 318
	body.add_child(detail_panel)
	var detail_box := VBoxContainer.new()
	detail_box.add_theme_constant_override("separation", 12)
	detail_panel.add_child(detail_box)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_box.add_child(detail_scroll)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 12)
	detail_scroll.add_child(_detail)
	_action = _button("Sélectionnez une maîtrise", 15)
	_action.custom_minimum_size.y = 46
	_action.pressed.connect(_purchase_selected)
	detail_box.add_child(_action)
	_notice = _label("", 12, MUTED)
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main.add_child(_notice)


func _build_navigation() -> void:
	_clear(_navigation)
	_nav_buttons.clear()
	_navigation.add_child(_label("LES TROIS DOCTRINES", 11, GOLD))
	var catalog := character_state.progression_profile.mastery_catalog
	if _section_id == &"":
		_section_id = catalog.doctrines[0].discipline_id
	for doctrine in catalog.doctrines:
		var points := SkillTreeResolver.champion_doctrine_selected_cost(doctrine, character_state.champion_progression.selected_node_ids)
		var button := _button("%s\n%d point%s investi%s" % [doctrine.display_name, points, "s" if points > 1 else "", "s" if points > 1 else ""], 14)
		button.custom_minimum_size = Vector2(176, 60)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.tooltip_text = doctrine.description
		button.pressed.connect(select_section.bind(doctrine.discipline_id))
		_navigation.add_child(button)
		_nav_buttons[doctrine.discipline_id] = button
		STYLE.selected(button, _section_id == doctrine.discipline_id)
	_navigation.add_child(HSeparator.new())
	for entry in [[&"advanced", "Destin héroïque", "Sommets · Jonctions · Apothéoses"], [&"attributes", "Caractéristiques", "Vitalité · Puissance · Résolution · Sagesse"]]:
		var button := _button(str(entry[1]), 14)
		button.custom_minimum_size.y = 38
		button.tooltip_text = str(entry[2])
		button.pressed.connect(select_section.bind(StringName(entry[0])))
		_navigation.add_child(button)
		_nav_buttons[entry[0]] = button
		STYLE.selected(button, _section_id == StringName(entry[0]))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_navigation.add_child(spacer)
	var capstone_hint := _label("CAPSTONES : N10 PUIS N13\nMaîtrises du N2 au N14\n3 leçons achetables maximum", 12, MUTED)
	capstone_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_navigation.add_child(capstone_hint)


func _build_spell_strip() -> void:
	_clear(_spells)
	for spell in character_state.progression_profile.spells:
		var nodes := character_state.get_selected_mastery_nodes()
		var profile := MasteryStaticModifierResolver.resolve_spell_profile(spell, nodes)
		var button := _button("", 14)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 62
		button.pressed.connect(_inspect_spell.bind(spell))
		button.tooltip_text = "%s · %d PA\n%s" % [spell.spell_name, spell.ap_cost, _spell_values(spell, nodes)]
		_spells.add_child(button)
		var margin := MarginContainer.new()
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_left", 10)
		margin.add_theme_constant_override("margin_right", 10)
		button.add_child(margin)
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 9)
		margin.add_child(row)
		row.add_child(_icon(spell.icon, 38))
		var lines := VBoxContainer.new()
		lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lines.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(lines)
		var name_label := _label(spell.spell_name, 14, TEXT)
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		lines.add_child(name_label)
		lines.add_child(_label("%d PA · %s" % [spell.ap_cost, _range_text(int(profile.minimum_range), int(profile.maximum_range))], 12, GOLD))


func _build_content() -> void:
	if not _built or character_state == null:
		return
	_clear(_content)
	_node_buttons.clear()
	_search.visible = _section_id != &"attributes"
	if _section_id == &"attributes":
		_build_attributes()
		return
	var catalog := character_state.progression_profile.mastery_catalog
	var doctrine := SkillTreeResolver.champion_doctrine_by_id(catalog.doctrines, _section_id)
	_content.add_child(_label(doctrine.display_name if doctrine != null else "Destin héroïque", 23, TEXT, true))
	var subtitle := _label(doctrine.description if doctrine != null else "Les sommets récompensent une doctrine complète. Les jonctions relient deux doctrines.", 14, MUTED)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(subtitle)
	var nodes: Array[SkillTreeNodeData] = SkillTreeResolver.champion_doctrine_nodes(doctrine) if doctrine != null else catalog.get_advanced_nodes()
	var query := _search.text.strip_edges().to_lower()
	var tiers: Dictionary = {}
	for node in nodes:
		if not query.is_empty() and not node.display_name.to_lower().contains(query):
			continue
		if not tiers.has(node.tier):
			tiers[node.tier] = []
		(tiers[node.tier] as Array).append(node)
	var tier_ids: Array = tiers.keys()
	tier_ids.sort()
	for tier_value in tier_ids:
		var tier := int(tier_value)
		var heading := "PALIER %d" % tier
		if tier == 5:
			heading = "CAPSTONE · CHOIX EXCLUSIF"
		elif tier == 6:
			heading = "NIVEAU 13 · SOMMET DE SPÉCIALISTE"
		elif tier == 7:
			heading = "NIVEAU 14 · JONCTION MYTHIQUE"
		elif tier == 8:
			heading = "NIVEAU 14 · APOTHÉOSE"
		_content.add_child(_label(heading, 11, GOLD))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_content.add_child(row)
		for value in tiers[tier]:
			var node := value as SkillTreeNodeData
			# Three advanced alternatives remain readable as independent rows.
			var parent: Container = row if (tiers[tier] as Array).size() <= 2 else _content
			parent.add_child(_node_card(node, doctrine))
		if tier < 5 and query.is_empty():
			var connector := _label("↓", 14, Color("728f80"))
			connector.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_content.add_child(connector)
	if tiers.is_empty():
		_content.add_child(_label("Aucune maîtrise ne correspond à cette recherche.", 15, MUTED))
	_refresh_node_styles()


func _node_card(node: SkillTreeNodeData, _doctrine: DisciplineData) -> Button:
	var button := _button("", 14)
	button.name = str(node.upgrade_id)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(160, 68)
	button.tooltip_text = node.description
	button.pressed.connect(inspect_node.bind(node.upgrade_id))
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	button.add_child(margin)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(box)
	var title := _label(node.display_name, 15, TEXT)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(title)
	var chosen := character_state.champion_progression.selected_node_ids.has(node.upgrade_id)
	var decision := character_state.evaluate_mastery_node(node.upgrade_id)
	var available := bool(decision.get("allowed", false))
	var requirement := "DISPONIBLE" if available else "PRÉREQUIS"
	if str(decision.get("reason_id", "")) == "LEVEL_GATE":
		var level := node.required_champion_level
		if node.node_type == SkillTreeNodeData.NodeType.CAPSTONE and not character_state.champion_progression.selected_capstone_ids.is_empty():
			level = maxi(level, character_state.champion_progression.profile.second_capstone_level)
		requirement = "NIVEAU %d" % level
	elif str(decision.get("reason_id", "")) == "INSUFFICIENT_MASTERY":
		requirement = "POINTS REQUIS"
	elif str(decision.get("reason_id", "")) in ["EXCLUDED_BY_SELECTION", "EXCLUSIVE_GROUP"]:
		requirement = "CHOIX EXCLU"
	var badge := "ACQUIS" if chosen else "%d PMa · %s" % [node.mastery_cost, requirement]
	box.add_child(_label(badge, 11, GREEN if chosen or available else MUTED))
	_node_buttons[node.upgrade_id] = button
	return button


func _refresh_node_styles() -> void:
	for node_id in _node_buttons:
		var button := _node_buttons[node_id] as Button
		STYLE.selected(button, node_id == _selected_node_id)
		if character_state.champion_progression.selected_node_ids.has(node_id) and node_id != _selected_node_id:
			button.add_theme_stylebox_override("normal", STYLE.box(Color("223b31"), Color("618c73"), 5, 9))


func _refresh_detail() -> void:
	_clear(_detail)
	_action.disabled = true
	_action.text = "Sélectionnez une maîtrise"
	if character_state == null:
		return
	if _selected_spell != null:
		_show_spell_detail(_selected_spell)
		return
	var node := character_state.progression_profile.mastery_catalog.node_catalog().get(_selected_node_id) as SkillTreeNodeData
	if node == null:
		_detail.add_child(_label("COMPRENDRE SON BUILD", 11, GOLD))
		_detail.add_child(_label("Un héros, trois voies", 24, TEXT, true))
		var intro := _label("Sélectionnez une maîtrise pour découvrir ses effets, ses conditions d’accès et ce qu’elle change sur vos techniques.", 16, MUTED)
		intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail.add_child(intro)
		_detail.add_child(_label("Les quatre techniques ci-dessus affichent leurs valeurs calculées avec vos statistiques actuelles.", 14, MUTED))
		(_detail.get_child(_detail.get_child_count() - 1) as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_action.text = "Consultation" if read_only else "Choisissez une maîtrise"
		return
	var chosen := character_state.champion_progression.selected_node_ids.has(node.upgrade_id)
	var decision := character_state.evaluate_mastery_node(node.upgrade_id)
	_detail.add_child(_label("MAÎTRISE ACQUISE" if chosen else "MAÎTRISE · %d POINT%s" % [node.mastery_cost, "S" if node.mastery_cost > 1 else ""], 11, GREEN if chosen else GOLD))
	_detail.add_child(_wrapped(node.display_name, 23, TEXT, true))
	_detail.add_child(_wrapped(node.description, 16, TEXT))
	_detail.add_child(HSeparator.new())
	_detail.add_child(_label("CONDITIONS D’ACCÈS", 11, GOLD))
	for line in _requirements(node):
		_detail.add_child(_wrapped(line, 13, MUTED))
	_detail.add_child(HSeparator.new())
	_detail.add_child(_label("APERÇU DES TECHNIQUES", 11, GOLD))
	var before := character_state.get_selected_mastery_nodes()
	var after := before.duplicate()
	if not chosen:
		after.append(node)
	for spell in character_state.progression_profile.spells:
		if node.affected_spell_ids.has(spell.get_effective_spell_id()):
			_detail.add_child(_label(spell.spell_name, 14, TEXT))
			var current := _spell_values(spell, before)
			var projected := _spell_values(spell, after)
			_detail.add_child(_wrapped(current if chosen or current == projected else "%s  →  %s" % [current, projected], 13, GREEN if current != projected else MUTED))
	if not node.reactive_effects.is_empty():
		_detail.add_child(_wrapped("Les bonus conditionnels s’appliquent lorsque les conditions décrites ci-dessus sont remplies. Les valeurs indiquées sont avant armure et résistances.", 12, MUTED))
	_action.text = "Acquise" if chosen else ("Consultation" if read_only else "Investir %d point%s" % [node.mastery_cost, "s" if node.mastery_cost > 1 else ""])
	_action.disabled = chosen or read_only or not bool(decision.get("allowed", false))
	if not chosen and not bool(decision.get("allowed", false)):
		_detail.add_child(_wrapped(_reason_text(str(decision.get("reason_id", ""))), 13, GOLD))


func _requirements(node: SkillTreeNodeData) -> PackedStringArray:
	var lines := PackedStringArray()
	var level := node.required_champion_level
	if node.node_type == SkillTreeNodeData.NodeType.CAPSTONE and not character_state.champion_progression.selected_capstone_ids.is_empty() and not character_state.champion_progression.selected_node_ids.has(node.upgrade_id):
		level = maxi(level, character_state.champion_progression.profile.second_capstone_level)
	lines.append("Niveau %d · %d point%s de maîtrise" % [level, node.mastery_cost, "s" if node.mastery_cost > 1 else ""])
	if not node.prerequisite_node_ids.is_empty():
		lines.append("Requiert : " + _node_names(node.prerequisite_node_ids))
	if not node.requires_any_node_ids.is_empty():
		lines.append("Au moins un : " + _node_names(node.requires_any_node_ids))
	if not node.excluded_node_ids.is_empty():
		lines.append("Exclusif avec : " + _node_names(node.excluded_node_ids))
	var catalog := character_state.progression_profile.mastery_catalog
	for doctrine_id in node.requires_completed_tree_ids:
		var doctrine := SkillTreeResolver.champion_doctrine_by_id(catalog.doctrines, doctrine_id)
		if doctrine != null:
			lines.append("Doctrine complète : " + doctrine.display_name)
	for requirement in node.doctrine_point_requirements:
		var doctrine := SkillTreeResolver.champion_doctrine_by_id(catalog.doctrines, requirement.tree_id)
		if doctrine != null:
			lines.append("%d points dans %s" % [requirement.minimum_points, doctrine.display_name])
	return lines


func _node_names(ids: Array[StringName]) -> String:
	var names := PackedStringArray()
	var catalog := character_state.progression_profile.mastery_catalog.node_catalog()
	for node_id in ids:
		var node := catalog.get(node_id) as SkillTreeNodeData
		if node != null:
			names.append(node.display_name)
	return " / ".join(names)


func _inspect_spell(spell: Spell) -> void:
	_selected_spell = spell
	_selected_node_id = &""
	_refresh_node_styles()
	_refresh_detail()


func _show_spell_detail(spell: Spell) -> void:
	var profile := MasteryStaticModifierResolver.resolve_spell_profile(spell, character_state.get_selected_mastery_nodes())
	_detail.add_child(_icon(spell.icon, 64))
	_detail.add_child(_label("TECHNIQUE DU CHAMPION", 11, GOLD))
	_detail.add_child(_wrapped(spell.spell_name, 24, TEXT, true))
	_detail.add_child(_wrapped(spell.description, 16, TEXT))
	_detail.add_child(HSeparator.new())
	_detail.add_child(_label("AVEC VOS STATISTIQUES", 11, GOLD))
	_detail.add_child(_wrapped(_spell_values(spell, character_state.get_selected_mastery_nodes()), 18, GREEN))
	_detail.add_child(_wrapped("%d PA · %s · Une fois par activation" % [spell.ap_cost, _range_text(int(profile.minimum_range), int(profile.maximum_range))], 14, MUTED))
	if spell.damage_scaling != null:
		_detail.add_child(_wrapped(_formula(spell.damage_scaling), 13, MUTED))
	if spell.shield_scaling != null:
		_detail.add_child(_wrapped(_formula(spell.shield_scaling), 13, MUTED))
		_detail.add_child(_wrapped("Expire au début de votre prochaine activation. Une Garde plus forte remplace la précédente ; les autres sources de bouclier sont conservées.", 13, MUTED))
	_detail.add_child(_wrapped("Les dégâts sont affichés avant armure et résistances. Les conditions des maîtrises sont évaluées en combat.", 12, MUTED))
	_action.text = "Technique de base"


func _spell_values(spell: Spell, nodes: Array[SkillTreeNodeData]) -> String:
	var profile := MasteryStaticModifierResolver.resolve_spell_profile(spell, nodes)
	var unit := character_state.unit
	var level := character_state.champion_progression.current_level
	var parts := PackedStringArray()
	if spell.damage > 0 or spell.damage_scaling != null:
		var base_damage := spell.get_scaled_damage(unit, level)
		var target_values := PackedStringArray()
		for target_index in range(maxi(1, int(profile.maximum_targets))):
			target_values.append(str(MasteryStaticModifierResolver.resolve_target_damage(
				base_damage, profile, target_index
			)))
		parts.append("%s dégâts" % " / ".join(target_values))
	if spell.shield_grant > 0 or spell.shield_scaling != null:
		var amount := MasteryStaticModifierResolver.resolve_shield_amount(
			spell.get_scaled_shield(unit, level), profile, unit.shield_creation_multiplier
		)
		parts.append("%d bouclier" % amount)
	parts.append(_range_text(int(profile.minimum_range), int(profile.maximum_range)))
	if int(profile.maximum_targets) > 1:
		parts.append("%d cibles" % int(profile.maximum_targets))
	if int(profile.ignore_armor_flat) > 0:
		parts.append("ignore %d armure" % int(profile.ignore_armor_flat))
	return " · ".join(parts)


func _formula(scaling: SpellScalingData) -> String:
	var parts := PackedStringArray()
	if not is_zero_approx(scaling.flat_value):
		parts.append(str(scaling.flat_value))
	if not is_zero_approx(scaling.prowess_coefficient):
		parts.append("%s %% Prouesse" % (scaling.prowess_coefficient * 100.0))
	if not is_zero_approx(scaling.max_hp_coefficient):
		parts.append("%s %% PV maximum" % (scaling.max_hp_coefficient * 100.0))
	return "Calcul : " + " + ".join(parts)


func _build_attributes() -> void:
	_content.add_child(_label("Façonnez votre champion", 23, TEXT, true))
	_content.add_child(_wrapped("Un point de caractéristique à chaque niveau du N2 au N10. Les points de maîtrise se gagnent jusqu’au N14.", 14, MUTED))
	for row in character_state.get_champion_attribute_rows():
		var panel := _panel(Color("1d3032"), 13)
		_content.add_child(panel)
		var line := HBoxContainer.new()
		panel.add_child(line)
		var text_box := VBoxContainer.new()
		text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(text_box)
		text_box.add_child(_label("%s · %d points" % [row.name, row.points], 17, TEXT))
		text_box.add_child(_wrapped(str(row.effect), 13, MUTED))
		text_box.add_child(_label("%s → %s %s" % [row.current, row.next, row.unit], 15, GREEN))
		for impact in row.get("spell_impacts", []):
			var current_text := _target_values_text(impact.get("current_targets", []), int(impact.current))
			var next_text := _target_values_text(impact.get("next_targets", []), int(impact.next))
			text_box.add_child(_wrapped("%s : %s → %s %s" % [impact.name, current_text, next_text, "bouclier" if impact.kind == &"shield" else "dégâts"], 12, MUTED))
		var button := _button("+", 21)
		button.custom_minimum_size = Vector2(40, 40)
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.disabled = read_only or not bool(row.can_spend)
		button.tooltip_text = "Investir 1 point dans %s" % row.name
		button.pressed.connect(_spend_attribute.bind(StringName(row.id)))
		line.add_child(button)
	_content.add_child(_wrapped("Vitalité et montée de niveau augmentent vos PV actuels uniquement du gain de PV maximum. La Sagesse est figée au début de chaque rencontre.", 13, MUTED))
	var champion := character_state.champion_progression
	var next_level := mini(champion.current_level + 1, champion.profile.level_cap)
	_content.add_child(_label("PROCHAIN NIVEAU · %d XP CUMULÉES" % champion.profile.xp_for_level(next_level), 12, GOLD))
	_content.add_child(_wrapped("Base au niveau %d : %d PV · %d Prouesse" % [next_level, champion.profile.base_hp_for_level(next_level), champion.profile.base_prowess_for_level(next_level)], 15, TEXT))


func _purchase_selected() -> void:
	if read_only or character_state == null:
		return
	var result := character_state.purchase_mastery_node(_selected_node_id)
	if bool(result.get("purchased", false)):
		build_changed.emit()
		refresh()
		_focus_inspected.call_deferred()


func _spend_attribute(attribute_id: StringName) -> void:
	if read_only or character_state == null:
		return
	if character_state.spend_champion_attribute(attribute_id):
		build_changed.emit()
		refresh()


func _reason_text(reason: String) -> String:
	return str({
		"LEVEL_GATE": "Le niveau requis n’est pas encore atteint.",
		"INSUFFICIENT_MASTERY": "Vous n’avez pas assez de points de maîtrise.",
		"MISSING_PREREQUISITE": "Acquérez d’abord la maîtrise requise.",
		"MISSING_ANY_PREREQUISITE": "Acquérez au moins une maîtrise du palier précédent.",
		"EXCLUDED_BY_SELECTION": "Votre choix actuel exclut cette maîtrise.",
		"EXCLUSIVE_GROUP": "Une autre option exclusive est déjà acquise.",
		"TREE_NOT_COMPLETE": "Complétez la doctrine requise pour ouvrir ce sommet.",
		"TREE_POINTS_GATE": "Investissez les points requis dans chacune des doctrines.",
	}.get(reason, "Cette maîtrise n’est pas disponible."))


func _range_text(minimum: int, maximum: int) -> String:
	if maximum == 0:
		return "Personnel"
	return "PO %d" % maximum if minimum == maximum else "PO %d–%d" % [minimum, maximum]


func _panel(fill: Color, padding: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", STYLE.box(fill, STYLE.BORDER, 7, padding))
	return panel


func _button(text: String, font_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", font_size)
	STYLE.button(button)
	return button


func _label(text: String, font_size: int, color: Color, display: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", STYLE.DISPLAY if display else STYLE.BODY)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _wrapped(text: String, font_size: int, color: Color, display: bool = false) -> Label:
	var label := _label(text, font_size, color, display)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _icon(texture: Texture2D, extent: float) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(extent, extent)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _focus_close() -> void:
	if is_inside_tree() and is_visible_in_tree() and is_instance_valid(_close_button):
		_close_button.grab_focus()


func _focus_navigation() -> void:
	if not is_inside_tree() or not is_visible_in_tree():
		return
	var selected := _nav_buttons.get(_section_id) as Button
	if is_instance_valid(selected) and selected.is_inside_tree():
		selected.grab_focus()


func _focus_inspected() -> void:
	if not is_inside_tree() or not is_visible_in_tree():
		return
	var selected := _node_buttons.get(_selected_node_id) as Button
	if is_instance_valid(selected) and selected.is_inside_tree():
		selected.grab_focus()


func _target_values_text(values, fallback: int) -> String:
	var labels := PackedStringArray()
	for value in values:
		labels.append(str(value))
	return " / ".join(labels) if not labels.is_empty() else str(fallback)
