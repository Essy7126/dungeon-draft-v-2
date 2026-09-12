class_name ChampionCodex
extends Control

signal close_requested
signal build_changed

const STYLE := preload("res://ui/progression/theme/spell_codex_style.gd")
const GOLD := STYLE.GOLD
const TEXT := STYLE.TEXT
const MUTED := STYLE.MUTED
const GREEN := Color("b8d5ac")
const ART := preload("res://ui/progression/champion/mastery_atlas_art.gd")
const GRAPH := preload("res://ui/progression/champion/champion_mastery_graph.gd")
const DOCTRINE_ART := [preload("res://assets/catabase/emerald_icons_v2/emblems/colere.png"), preload("res://assets/catabase/emerald_icons_v2/emblems/chiron.png"), preload("res://assets/catabase/emerald_icons_v2/emblems/eaque.png")]

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
var _graph: ChampionMasteryGraph
var _attribute_scroll: ScrollContainer
var _graph_title: Label
var _graph_subtitle: Label
var _graph_status: Label
var _zoom_label: Label
var _next_available_button: Button
var _graph_controls: HBoxContainer
var _detail_scroll: ScrollContainer
var _nav_panel: PanelContainer
var _detail_panel: PanelContainer
var _last_node_by_section: Dictionary = {}
var _feedback: Label
var _feedback_tween: Tween
var _entry_tween: Tween
var _main: VBoxContainer
var _xp_text: Label
var _legend: HBoxContainer
var _feedback_panel: PanelContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	refresh()
	resized.connect(_apply_responsive_layout)
	_apply_responsive_layout()
	AudioManager.play_feedback(&"open")


func configure(state: CharacterRunState, p_read_only: bool = false) -> void:
	_disconnect_state()
	character_state = state
	read_only = p_read_only
	if character_state != null:
		character_state.champion_changed.connect(refresh)
	if is_node_ready():
		refresh()
		_focus_close.call_deferred()
		_animate_entry()


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
	_title.text = "%s · Atlas des maîtrises" % character_state.unit.unit_name
	_summary.text = "NIVEAU %d / %d     ·     %d / %d PV     ·     %d Prouesse     ·     %d PA / %d PM" % [champion.current_level, profile.level_cap, character_state.unit.current_hp, character_state.unit.max_hp.get_int(), character_state.unit.attack_power.get_int(), character_state.unit.max_ap.get_int(), character_state.unit.max_mp.get_int()]
	_points.text = "%d PMa disponibles  ·  %d caractéristiques" % [champion.unspent_mastery_points, champion.unspent_attribute_points]
	var threshold := profile.xp_for_level(champion.current_level)
	var next_threshold := profile.xp_for_level(mini(champion.current_level + 1, profile.level_cap))
	_xp.max_value = maxi(1, next_threshold - threshold)
	_xp.value = champion.current_xp - threshold if champion.current_level < profile.level_cap else _xp.max_value
	_xp.tooltip_text = "%d XP / %d · XP accordée à la victoire" % [champion.current_xp, next_threshold]
	_xp_text.text = "Niveau maximum atteint" if champion.current_level >= profile.level_cap else "%d / %d XP  ·  Prochain niveau %d" % [champion.current_xp - threshold, next_threshold - threshold, champion.current_level + 1]
	_notice.text = "CONSULTATION · Explorez les effets et les prérequis" if read_only else "Choisissez une maîtrise, comparez ses effets, puis investissez vos points. Les choix sont définitifs pour cette run."
	_build_navigation()
	_build_spell_strip()
	_build_content()
	_refresh_detail()


func get_node_buttons() -> Dictionary:
	return _node_buttons.duplicate()


func get_graph() -> ChampionMasteryGraph:
	return _graph


func get_action_button() -> Button:
	return _action


func get_close_button() -> Button:
	return _close_button


func select_section(section_id: StringName) -> void:
	if section_id != _section_id:
		AudioManager.play_feedback(&"select")
	if character_state != null and section_id not in [&"advanced", &"attributes"]:
		var catalog := character_state.progression_profile.mastery_catalog
		if SkillTreeResolver.champion_doctrine_by_id(catalog.doctrines, section_id) == null:
			section_id = catalog.doctrines[0].discipline_id
	if _selected_node_id != &"":
		_last_node_by_section[_section_id] = _selected_node_id
	_section_id = section_id
	_selected_node_id = _last_node_by_section.get(section_id, &"")
	_selected_spell = null
	_search.text = ""
	_detail_scroll.scroll_vertical = 0
	refresh()
	if _selected_node_id != &"" and _graph.visible:
		_graph.center_on_node(_selected_node_id)
	_focus_navigation.call_deferred()


func inspect_node(node_id: StringName) -> void:
	if node_id != _selected_node_id:
		AudioManager.play_feedback(&"select")
	_selected_node_id = node_id
	_last_node_by_section[_section_id] = node_id
	_selected_spell = null
	_detail_scroll.scroll_vertical = 0
	_refresh_node_styles()
	_refresh_detail()


func set_search_query(query: String) -> void:
	_search.text = query
	_on_search_changed(query)


func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var background := Panel.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	STYLE.panel(background, STYLE.INK, STYLE.BORDER, 9)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	_main = VBoxContainer.new()
	_main.add_theme_constant_override("separation", 10)
	margin.add_child(_main)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	_main.add_child(header)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(identity)
	identity.add_child(_label("LES VOIES DU CHAMPION", 12, GOLD))
	_title = _label("Atlas des maîtrises", 28, TEXT, true)
	identity.add_child(_title)
	_summary = _label("", 13, MUTED)
	identity.add_child(_summary)
	var status := VBoxContainer.new()
	status.custom_minimum_size.x = 320
	header.add_child(status)
	_points = _label("", 16, GOLD)
	_points.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.add_child(_points)
	_xp = ProgressBar.new()
	_xp.custom_minimum_size.y = 7
	_xp.show_percentage = false
	_xp.add_theme_stylebox_override("background", STYLE.box(Color("29231e"), Color("4c4034"), 3))
	_xp.add_theme_stylebox_override("fill", STYLE.box(Color("b7a076"), GOLD, 3))
	status.add_child(_xp)
	_xp_text = _label("", 12, MUTED)
	_xp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.add_child(_xp_text)
	_close_button = _button("Fermer  ×", 14)
	_close_button.custom_minimum_size = Vector2(110, 42)
	_close_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_close_button.pressed.connect(func() -> void:
		AudioManager.play_feedback(&"close")
		close_requested.emit())
	header.add_child(_close_button)
	_spells = HBoxContainer.new()
	_spells.add_theme_constant_override("separation", 8)
	_main.add_child(_spells)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	_main.add_child(body)
	_nav_panel = _panel(Color("1c1713"), 12)
	_nav_panel.custom_minimum_size.x = 212
	body.add_child(_nav_panel)
	var nav_scroll := ScrollContainer.new()
	nav_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_nav_panel.add_child(nav_scroll)
	STYLE.scroll(nav_scroll)
	_navigation = VBoxContainer.new()
	_navigation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_navigation.add_theme_constant_override("separation", 8)
	nav_scroll.add_child(_navigation)
	var canvas := _panel(Color("181511"), 10)
	canvas.name = "MasteryCanvas"
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(canvas)
	var canvas_box := VBoxContainer.new()
	canvas_box.add_theme_constant_override("separation", 8)
	canvas.add_child(canvas_box)
	_graph_title = _label("", 22, TEXT, true)
	canvas_box.add_child(_graph_title)
	_graph_subtitle = _wrapped("", 13, MUTED)
	canvas_box.add_child(_graph_subtitle)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 6)
	canvas_box.add_child(tools)
	_search = LineEdit.new()
	_search.name = "MasterySearch"
	_search.placeholder_text = "Rechercher une maîtrise…"
	_search.custom_minimum_size.y = 38
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.clear_button_enabled = true
	_search.add_theme_font_override("font", STYLE.BODY)
	_search.add_theme_font_size_override("font_size", 15)
	_search.add_theme_stylebox_override("normal", STYLE.box(Color("100e0c"), Color("615247"), 5, 9))
	_search.add_theme_stylebox_override("focus", STYLE.box(Color("102d34"), STYLE.TEAL, 5, 9))
	_search.add_theme_color_override("font_color", TEXT)
	_search.add_theme_color_override("font_placeholder_color", MUTED)
	_search.text_changed.connect(_on_search_changed)
	tools.add_child(_search)
	_next_available_button = _button("Accessible  ›", 14)
	_next_available_button.name = "NextAvailable"
	_next_available_button.tooltip_text = "Centrer la prochaine maîtrise que vos points et prérequis permettent d’acquérir"
	_next_available_button.pressed.connect(_select_next_available)
	tools.add_child(_next_available_button)
	_graph = GRAPH.new() as ChampionMasteryGraph
	_graph.name = "MasteryGraph"
	_graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_graph.custom_minimum_size = Vector2(280, 200)
	_graph.node_inspected.connect(inspect_node)
	_graph.navigation_changed.connect(_on_graph_navigation_changed)
	canvas_box.add_child(_graph)
	_attribute_scroll = ScrollContainer.new()
	_attribute_scroll.name = "AttributesScroll"
	_attribute_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_attribute_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	canvas_box.add_child(_attribute_scroll)
	STYLE.scroll(_attribute_scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 10)
	_attribute_scroll.add_child(_content)
	_graph_controls = HBoxContainer.new()
	_graph_controls.add_theme_constant_override("separation", 6)
	canvas_box.add_child(_graph_controls)
	_graph_status = _label("", 12, MUTED)
	_graph_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_graph_controls.add_child(_graph_status)
	for entry in [["ZoomOut", "−", "Réduire"], ["ZoomIn", "+", "Agrandir"], ["FitGraph", "Recentrer", "Retrouver un cadrage lisible de l’arbre"]]:
		var button := _button(entry[1], 14)
		button.name = entry[0]
		button.custom_minimum_size = Vector2(33, 32)
		button.tooltip_text = entry[2]
		if entry[0] == "FitGraph":
			button.pressed.connect(func() -> void: _graph.fit_graph())
		else:
			button.pressed.connect(func() -> void: _graph.zoom_by(1.15 if entry[0] == "ZoomIn" else 1.0 / 1.15))
		_graph_controls.add_child(button)
	_zoom_label = _label("100 %", 12, GOLD)
	_zoom_label.custom_minimum_size.x = 45
	_graph_controls.add_child(_zoom_label)
	_build_state_legend(canvas_box)
	_detail_panel = _panel(Color("201913"), 14)
	_detail_panel.name = "MasteryInspector"
	_detail_panel.custom_minimum_size.x = 336
	body.add_child(_detail_panel)
	var detail_box := VBoxContainer.new()
	detail_box.add_theme_constant_override("separation", 10)
	_detail_panel.add_child(detail_box)
	_detail_scroll = ScrollContainer.new()
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_box.add_child(_detail_scroll)
	STYLE.scroll(_detail_scroll)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 11)
	_detail_scroll.add_child(_detail)
	_action = _button("Sélectionnez une maîtrise", 16)
	_action.name = "AcquireMastery"
	(_action.get_node("AshenButtonMaterial") as SelectionAshenSurface).configure(&"primary", STYLE.SURFACE, STYLE.GOLD)
	_action.custom_minimum_size.y = 48
	_action.pressed.connect(_purchase_selected)
	detail_box.add_child(_action)
	_feedback_panel = _panel(Color("221e17"), 10)
	_feedback_panel.name = "MasteryFeedbackPanel"
	_feedback_panel.visible = false
	detail_box.add_child(_feedback_panel)
	_feedback = _wrapped("", 13, GREEN)
	_feedback.name = "MasteryFeedback"
	_feedback.visible = false
	_feedback_panel.add_child(_feedback)
	_notice = _label("", 12, MUTED)
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_main.add_child(_notice)


func _build_navigation() -> void:
	_clear(_navigation)
	_nav_buttons.clear()
	_navigation.add_child(_label("DOCTRINES", 12, GOLD))
	var catalog := character_state.progression_profile.mastery_catalog
	if _section_id == &"":
		_section_id = catalog.doctrines[0].discipline_id
	for index in range(catalog.doctrines.size()):
		var doctrine := catalog.doctrines[index]
		var nodes := SkillTreeResolver.champion_doctrine_nodes(doctrine)
		var points := SkillTreeResolver.champion_doctrine_selected_cost(doctrine, character_state.champion_progression.selected_node_ids)
		var acquired := 0
		var available := 0
		for node in nodes:
			if character_state.champion_progression.selected_node_ids.has(node.upgrade_id):
				acquired += 1
			elif bool(character_state.evaluate_mastery_node(node.upgrade_id).get("allowed", false)):
				available += 1
		var accent := _doctrine_accent(doctrine.discipline_id)
		var button := _button("", 14)
		button.name = "Doctrine_%s" % doctrine.discipline_id
		button.custom_minimum_size = Vector2(180, 83)
		button.tooltip_text = doctrine.description
		button.pressed.connect(select_section.bind(doctrine.discipline_id))
		_navigation.add_child(button)
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 8
		row.offset_right = -8
		row.offset_top = 7
		row.offset_bottom = -7
		row.add_theme_constant_override("separation", 8)
		button.add_child(row)
		row.add_child(_icon(DOCTRINE_ART[index % DOCTRINE_ART.size()], 38))
		var lines := VBoxContainer.new()
		lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lines.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(lines)
		var title := _wrapped(doctrine.display_name, 14, TEXT)
		lines.add_child(title)
		lines.add_theme_constant_override("separation", 1)
		var progress_text := _label("%d/%d acquises · %d PMa" % [acquired, nodes.size(), points], 11, accent)
		progress_text.name = "DoctrineProgressText_%s" % doctrine.discipline_id
		lines.add_child(progress_text)
		lines.add_child(_label("%d accessible%s" % [available, "s" if available != 1 else ""], 11, GREEN if available > 0 else MUTED))
		var progress := ProgressBar.new()
		progress.name = "DoctrineProgress_%s" % doctrine.discipline_id
		progress.custom_minimum_size.y = 3
		progress.show_percentage = false
		progress.max_value = maxi(nodes.size(), 1)
		progress.value = acquired
		progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
		progress.add_theme_stylebox_override("background", STYLE.box(Color("100e0c"), Color.TRANSPARENT, 1))
		progress.add_theme_stylebox_override("fill", STYLE.box(accent, Color.TRANSPARENT, 1))
		lines.add_child(progress)
		button.tooltip_text = "%s\n%d / %d maîtrises acquises · %d PMa investis\n%d maîtrises accessibles avec vos points et prérequis actuels." % [doctrine.description, acquired, nodes.size(), points, available]
		_nav_buttons[doctrine.discipline_id] = button
		STYLE.selected(button, _section_id == doctrine.discipline_id)
	_navigation.add_child(HSeparator.new())
	for entry in [[&"advanced", "Destin héroïque", "Sommets · Jonctions · Apothéoses"], [&"attributes", "Caractéristiques", "Vitalité · Puissance · Résolution · Sagesse"]]:
		var button := _button(str(entry[1]), 14)
		button.custom_minimum_size.y = 40
		button.tooltip_text = str(entry[2])
		button.pressed.connect(select_section.bind(StringName(entry[0])))
		_navigation.add_child(button)
		_nav_buttons[entry[0]] = button
		STYLE.selected(button, _section_id == StringName(entry[0]))
	_navigation.add_child(_wrapped("Maîtrises : niveaux 2 à 14\nUltimes : niveaux 10 puis 13\n3 leçons achetables maximum", 12, MUTED))


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
		row.add_child(_icon(_spell_icon(spell), 38))
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
	var attributes := _section_id == &"attributes"
	_search.visible = not attributes
	_next_available_button.visible = not attributes
	_graph.visible = not attributes
	_graph_controls.visible = not attributes
	_legend.visible = not attributes
	_attribute_scroll.visible = attributes
	_clear(_content)
	_node_buttons.clear()
	if attributes:
		_graph_title.text = "Caractéristiques"
		_graph_subtitle.text = "Comparez l’impact d’un point avant de l’investir."
		_build_attributes()
		return
	var catalog := character_state.progression_profile.mastery_catalog
	var doctrine := SkillTreeResolver.champion_doctrine_by_id(catalog.doctrines, _section_id)
	_graph_title.text = doctrine.display_name if doctrine != null else "Destin héroïque"
	_graph_title.add_theme_color_override("font_color", _doctrine_accent(_section_id).lightened(0.18))
	_graph_subtitle.text = doctrine.description if doctrine != null else "Sommets, jonctions et apothéoses : les liens entre vos doctrines."
	_graph.set_reduced_motion(GameManager.is_reduced_motion_enabled())
	_graph.configure(character_state, _section_id)
	_graph.set_search_query(_search.text)
	_node_buttons = _graph.get_node_buttons()
	_refresh_node_styles()
	_update_available_count()


func _refresh_node_styles() -> void:
	if is_instance_valid(_graph):
		_graph.inspect_node(_selected_node_id)


func _on_search_changed(_query: String) -> void:
	if not _built or _graph == null:
		return
	_graph.set_search_query(_search.text)
	_node_buttons = _graph.get_node_buttons()
	_update_available_count()


func _update_available_count() -> void:
	var available := 0
	var acquired := 0
	for node_id in _node_buttons:
		if character_state.champion_progression.selected_node_ids.has(node_id):
			acquired += 1
		elif bool(character_state.evaluate_mastery_node(node_id).get("allowed", false)):
			available += 1
	_next_available_button.disabled = available == 0
	_next_available_button.text = "Accessible%s  %d ›" % ["s" if available != 1 else "", available]
	_graph_status.text = "%d / %d acquises · Glisser / molette" % [acquired, _node_buttons.size()]


func _select_next_available() -> void:
	var available: Array[StringName] = []
	for node_id in _node_buttons:
		if bool(character_state.evaluate_mastery_node(node_id).get("allowed", false)):
			available.append(StringName(node_id))
	if available.is_empty():
		return
	var index := (available.find(_selected_node_id) + 1) % available.size()
	inspect_node(available[index])
	_graph.center_on_node(available[index])
	_focus_inspected.call_deferred()


func _on_graph_navigation_changed(snapshot: Dictionary) -> void:
	if is_instance_valid(_zoom_label):
		_zoom_label.text = "%d %%" % roundi(float(snapshot.get("zoom", 1.0)) * 100.0)


func _refresh_detail() -> void:
	_clear(_detail)
	_action.disabled = true
	_action.text = "Sélectionnez une maîtrise"
	if character_state == null:
		return
	if _selected_spell != null:
		_show_spell_detail(_selected_spell)
		return
	if _section_id == &"attributes":
		_detail.add_child(_label("DÉVELOPPER SON CHAMPION", 11, GOLD))
		_detail.add_child(_wrapped("Chaque point compte", 24, TEXT, true))
		var attribute_points := character_state.champion_progression.unspent_attribute_points
		var plural := "s" if attribute_points > 1 else ""
		_detail.add_child(_wrapped("%d point%s de caractéristique disponible%s." % [attribute_points, plural, plural], 16, GREEN))
		_detail.add_child(_wrapped("Chaque carte compare vos statistiques actuelles avec celles obtenues en investissant un point. Les effets sur vos techniques sont calculés avec votre équipement et vos maîtrises.", 15, MUTED))
		_detail.add_child(_wrapped("Sélectionnez une technique dans le bandeau pour consulter ses valeurs détaillées.", 14, GOLD))
		_detail.add_child(_wrapped("Les investissements sont désactivés dans cet aperçu." if read_only else "Le bouton + de chaque carte investit un point. Ce choix est définitif pour cette run.", 14, MUTED))
		_action.text = "Consultation" if read_only else "Investissez depuis une carte"
		return
	var node := character_state.progression_profile.mastery_catalog.node_catalog().get(_selected_node_id) as SkillTreeNodeData
	if node == null:
		_detail.add_child(_label("TRACER SA VOIE", 11, GOLD))
		_detail.add_child(_label("Votre prochain choix", 24, TEXT, true))
		var intro := _label("Parcourez les nœuds reliés, puis sélectionnez une maîtrise. Ses conditions et son effet sur vos techniques apparaissent ici.", 16, MUTED)
		intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail.add_child(intro)
		_detail.add_child(_wrapped("Molette : zoom · Glisser : déplacer\nRecentrer : retrouver les maîtrises\nAccessible : trouver votre prochain choix", 14, GOLD))
		_detail.add_child(_label("Les quatre techniques ci-dessus affichent leurs valeurs calculées avec vos statistiques actuelles.", 14, MUTED))
		(_detail.get_child(_detail.get_child_count() - 1) as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_action.text = "Consultation" if read_only else "Choisissez une maîtrise"
		return
	var chosen := character_state.champion_progression.selected_node_ids.has(node.upgrade_id)
	var decision := character_state.evaluate_mastery_node(node.upgrade_id)
	_build_mastery_identity(node, chosen, decision)
	_detail.add_child(_wrapped(node.display_name, 23, TEXT, true))
	_detail.add_child(_wrapped(node.description, 16, TEXT))
	_detail.add_child(HSeparator.new())
	_detail.add_child(_label("CONDITIONS D’ACCÈS", 11, GOLD))
	_append_requirements(node, chosen)
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
	_detail_scroll.scroll_vertical = 0
	_selected_spell = spell
	_selected_node_id = &""
	_refresh_node_styles()
	_refresh_detail()


func _show_spell_detail(spell: Spell) -> void:
	var profile := MasteryStaticModifierResolver.resolve_spell_profile(spell, character_state.get_selected_mastery_nodes())
	_detail.add_child(_icon(_spell_icon(spell), 64))
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
		var panel := _panel(Color("241c17"), 13)
		panel.name = "AttributeCard_%s" % row.id
		_content.add_child(panel)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 11)
		panel.add_child(line)
		var art := _icon(ART.attribute_icon(StringName(row.id)), 48)
		art.name = "AttributeIcon_%s" % row.id
		art.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		line.add_child(art)
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
	var acquired := character_state.progression_profile.mastery_catalog.node_catalog().get(_selected_node_id) as SkillTreeNodeData
	var result := character_state.purchase_mastery_node(_selected_node_id)
	if bool(result.get("purchased", false)):
		AudioManager.play_feedback(&"reward")
		build_changed.emit()
		refresh()
		_show_feedback("Maîtrise acquise : %s\n−%d PMa · %d PMa restants" % [acquired.display_name, acquired.mastery_cost, character_state.champion_progression.unspent_mastery_points])
		_focus_inspected.call_deferred()


func _spend_attribute(attribute_id: StringName) -> void:
	if read_only or character_state == null:
		return
	var preview := {}
	for row in character_state.get_champion_attribute_rows():
		if StringName(row.id) == attribute_id:
			preview = row
			break
	if character_state.spend_champion_attribute(attribute_id):
		build_changed.emit()
		refresh()
		var remaining := character_state.champion_progression.unspent_attribute_points
		var suffix := "s" if remaining > 1 else ""
		_show_feedback("%s augmentée\n%s → %s %s · %d point%s restant%s" % [str(preview.get("name", "Caractéristique")), str(preview.get("current", "")), str(preview.get("next", "")), str(preview.get("unit", "")), remaining, suffix, suffix])


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
	STYLE.panel(panel, fill, STYLE.BORDER, 7, padding)
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
	if display:
		label.add_theme_color_override("font_shadow_color", Color("0b0806"))
		label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _wrapped(text: String, font_size: int, color: Color, display: bool = false) -> Label:
	var label := _label(text, font_size, color, display)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _spell_icon(spell: Spell) -> Texture2D:
	if spell == null:
		return null
	var unit := character_state.unit if character_state != null else null
	var hud_theme := CharacterHUDThemeCatalog.resolve_refined(unit)
	return hud_theme.get_spell_icon_for(spell) if hud_theme != null else spell.icon


func _icon(texture: Texture2D, extent: float) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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


func _apply_responsive_layout() -> void:
	if not _built:
		return
	var compact := size.x < 1400
	_nav_panel.custom_minimum_size.x = 202 if compact else 230
	_detail_panel.custom_minimum_size.x = 310 if compact else 365
	_title.add_theme_font_size_override("font_size", 24 if compact else 30)
	_summary.add_theme_font_size_override("font_size", 12 if compact else 14)


func _animate_entry() -> void:
	if is_instance_valid(_entry_tween):
		_entry_tween.kill()
	modulate = Color.WHITE
	if GameManager.is_reduced_motion_enabled():
		return
	modulate.a = 0.0
	_entry_tween = create_tween()
	_entry_tween.tween_property(self, "modulate:a", 1.0, 0.18)


func _show_feedback(text: String) -> void:
	if is_instance_valid(_feedback_tween):
		_feedback_tween.kill()
	_feedback.text = text
	_feedback_panel.visible = true
	_feedback.visible = true
	_feedback.modulate = Color.WHITE
	if GameManager.is_reduced_motion_enabled():
		return
	_feedback_tween = create_tween()
	_feedback_tween.tween_interval(4.5)
	_feedback_tween.tween_property(_feedback, "modulate:a", 0.0, 0.25)
	_feedback_tween.tween_callback(func() -> void:
		_feedback.hide()
		_feedback_panel.hide()
	)


func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.ctrl_pressed and event.keycode == KEY_F:
		_search.grab_focus()
		_search.select_all()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_HOME and not _search.has_focus() and _section_id != &"attributes":
		_graph.fit_graph()
		get_viewport().set_input_as_handled()


func _append_requirements(node: SkillTreeNodeData, chosen: bool) -> void:
	var progress := character_state.champion_progression
	var selected := progress.selected_node_ids
	var catalog := character_state.progression_profile.mastery_catalog
	var level := node.required_champion_level
	if node.node_type == SkillTreeNodeData.NodeType.CAPSTONE and not progress.selected_capstone_ids.is_empty() and not chosen:
		level = maxi(level, progress.profile.second_capstone_level)
	_requirement_row("Niveau %d · vous : %d" % [level, progress.current_level], progress.current_level >= level)
	_requirement_row("%d PMa investis" % node.mastery_cost if chosen else "%d PMa nécessaires · disponibles : %d" % [node.mastery_cost, progress.unspent_mastery_points], chosen or progress.unspent_mastery_points >= node.mastery_cost)
	for prerequisite in node.prerequisite_node_ids:
		_requirement_row("Requiert : " + _node_names([prerequisite]), selected.has(prerequisite))
		_requirement_link(prerequisite)
	if not node.requires_any_node_ids.is_empty():
		var satisfied := false
		for prerequisite in node.requires_any_node_ids:
			satisfied = satisfied or selected.has(prerequisite)
		_requirement_row("Au moins une : " + _node_names(node.requires_any_node_ids), satisfied)
		for prerequisite in node.requires_any_node_ids:
			if not selected.has(prerequisite):
				_requirement_link(prerequisite)
	for doctrine_id in node.requires_completed_tree_ids:
		var doctrine := SkillTreeResolver.champion_doctrine_by_id(catalog.doctrines, doctrine_id)
		if doctrine != null:
			_requirement_row("Doctrine complète : " + doctrine.display_name, SkillTreeResolver.champion_doctrine_is_complete(doctrine, selected))
	for requirement in node.doctrine_point_requirements:
		var doctrine := SkillTreeResolver.champion_doctrine_by_id(catalog.doctrines, requirement.tree_id)
		if doctrine != null:
			var points := SkillTreeResolver.champion_doctrine_selected_cost(doctrine, selected)
			_requirement_row("%s : %d / %d PMa" % [doctrine.display_name, points, requirement.minimum_points], points >= requirement.minimum_points)
	if not node.excluded_node_ids.is_empty():
		var compatible := true
		for excluded in node.excluded_node_ids:
			compatible = compatible and not selected.has(excluded)
		_requirement_row("Exclusif avec : " + _node_names(node.excluded_node_ids), compatible)


func _requirement_row(caption: String, met: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_detail.add_child(row)
	row.add_child(_label("✓" if met else "◇", 15, GREEN if met else GOLD))
	var text := _wrapped(caption, 13, TEXT if met else MUTED)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)


func _requirement_link(node_id: StringName) -> void:
	var button := _button("Voir : %s  ›" % _node_names([node_id]), 12)
	button.name = "Prerequisite_%s" % node_id
	button.custom_minimum_size.y = 30
	button.clip_text = true
	button.tooltip_text = "Afficher cette maîtrise dans l’arbre"
	button.pressed.connect(_go_to_mastery.bind(node_id))
	_detail.add_child(button)


func _go_to_mastery(node_id: StringName) -> void:
	var node := character_state.progression_profile.mastery_catalog.node_catalog().get(node_id) as SkillTreeNodeData
	if node == null:
		return
	var section: StringName = node.doctrine_id if node.doctrine_id != &"" else &"advanced"
	if section != _section_id:
		select_section(section)
	if not _search.text.is_empty():
		set_search_query("")
	inspect_node(node_id)
	_graph.center_on_node(node_id)
	_focus_inspected.call_deferred()


func _build_state_legend(parent: VBoxContainer) -> void:
	_legend = HBoxContainer.new()
	_legend.name = "MasteryStateLegend"
	_legend.add_theme_constant_override("separation", 10)
	parent.add_child(_legend)
	for entry in [
		["Acquired", "✓ Acquise", GREEN, "Déjà intégrée à votre champion. Ses effets sont pris en compte dans vos techniques."],
		["Available", "◇ Accessible", GOLD, "Niveau, points et prérequis remplis. Inspectez la maîtrise avant de l’acquérir."],
		["Locked", "○ Verrouillée", MUTED, "Une condition reste à remplir. La fiche précise laquelle et permet de consulter les prérequis."],
		["Excluded", "× Exclue", Color("c18f83"), "Un choix déjà acquis exclut cette maîtrise pour cette run."],
	]:
		var label := _label(str(entry[1]), 11, entry[2])
		label.name = "Legend%s" % entry[0]
		label.tooltip_text = str(entry[3])
		label.mouse_filter = Control.MOUSE_FILTER_PASS
		_legend.add_child(label)


func _build_mastery_identity(node: SkillTreeNodeData, chosen: bool, decision: Dictionary) -> void:
	var accent := ART.node_accent(node.upgrade_id)
	var row := HBoxContainer.new()
	row.name = "MasteryIdentity"
	row.add_theme_constant_override("separation", 12)
	_detail.add_child(row)
	var art_frame := PanelContainer.new()
	art_frame.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	art_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	STYLE.panel(art_frame, Color("191410"), accent.darkened(0.28), 7, 5)
	row.add_child(art_frame)
	var art := _icon(ART.node_icon(node.upgrade_id), 72)
	art.name = "MasteryDetailIcon"
	art_frame.add_child(art)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	identity.add_theme_constant_override("separation", 5)
	row.add_child(identity)
	identity.add_child(_wrapped(_node_kind_label(node).to_upper(), 11, accent))
	var graph_node := _graph.get_all_node_buttons().get(node.upgrade_id) as Button
	var excluded := str(decision.get("reason_id", "")) in ["EXCLUDED_BY_SELECTION", "EXCLUSIVE_GROUP"]
	if graph_node != null:
		excluded = str(graph_node.get_meta("mastery_state", "")) == "excluded"
	var status := "MAÎTRISE ACQUISE" if chosen else "ACCESSIBLE" if bool(decision.get("allowed", false)) else "EXCLUE" if excluded else "VERROUILLÉE"
	var status_color := GREEN if chosen else Color("c18f83") if excluded else GOLD if bool(decision.get("allowed", false)) else MUTED
	var status_label := _wrapped(status, 12, status_color)
	status_label.name = "MasteryIdentityState"
	identity.add_child(status_label)
	identity.add_child(_label("%d PMa investi%s" % [node.mastery_cost, "s" if node.mastery_cost > 1 else ""] if chosen else "Coût : %d PMa" % node.mastery_cost, 12, MUTED))


func _node_kind_label(node: SkillTreeNodeData) -> String:
	match node.node_type:
		SkillTreeNodeData.NodeType.ROOT:
			return "Fondation · palier %d" % node.tier
		SkillTreeNodeData.NodeType.CAPSTONE:
			return "Maîtrise ultime"
		SkillTreeNodeData.NodeType.SPECIALIST_SUMMIT:
			return "Sommet de doctrine"
		SkillTreeNodeData.NodeType.MYTHIC_JUNCTION:
			return "Jonction mythique"
		SkillTreeNodeData.NodeType.APOTHEOSIS:
			return "Apothéose"
	return "Maîtrise · palier %d" % node.tier


func _doctrine_accent(doctrine_id: StringName) -> Color:
	match doctrine_id:
		&"achilles_wrath_of_peleus":
			return Color("c99b7b")
		&"achilles_lesson_of_chiron":
			return Color("abb79b")
		&"achilles_aegis_of_aeacus":
			return Color("a2b8c4")
	return GOLD
