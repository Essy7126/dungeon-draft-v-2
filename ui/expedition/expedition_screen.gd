class_name ExpeditionScreen
extends Control
## One readable workshop for route commitments, techniques and their opportunity cost.

signal inspection_closed

const ART_THEME := preload("res://ui/expedition/catabase_ui_theme.gd")
const INK := ART_THEME.INK
const PANEL := ART_THEME.PANEL
const LINE := ART_THEME.BRONZE
const GOLD := ART_THEME.GOLD
const TEXT := ART_THEME.TEXT
const MUTED := ART_THEME.MUTED
const TEAL := ART_THEME.TEAL
const RED := ART_THEME.DANGER
const BODY_FONT := preload("res://asset/ui/recraft_hud_v1/fonts/atkinson_hyperlegible/AtkinsonHyperlegible-Regular.otf")
const TITLE_FONT := preload("res://asset/ui/character_selection/selection_title_font.tres")
const MAP_CANVAS := preload("res://ui/expedition/expedition_map_canvas.gd")
const TREE_CANVAS := preload("res://ui/expedition/expedition_tree_canvas.gd")
const HUB_CANVAS := preload("res://ui/expedition/catabase_hub_canvas.gd")
const TYPE_NAMES := {"normal": "Combat", "elite": "Épreuve élite", "hub": "Refuge", "merchant": "Marchand", "sanctuary": "Sanctuaire", "lore": "Mémoire", "event": "Rencontre", "cache": "Cache", "hidden": "Passage secret", "unknown": "Destination inconnue", "boss": "Gardien final"}
const REWARD_NAMES := {"melee": "Contact et contrôle", "ranged": "Tir et préparation", "armor": "Armure et garde", "mobility": "Mouvement et esquive", "control": "Contrôle", "healing": "Soin et endurance", "elemental": "Feu, givre ou foudre", "discovery": "Découverte", "vitality": "PV et sacrifice", "signature": "Transformation", "victory": "Fin de la traversée"}

var inspection_only := false
var initial_page := "map"
var _page := "map"
var _axis := "briseur"
var _doctrine := "colere"
var _selected_technique := ""
var _selected_service := ""
var _show_loadout := false
var _selected_node := ""
var _root: VBoxContainer
var _body: Control
var _summary: Label
var _status: Label
var _seed: LineEdit
var _map_scroll: ScrollContainer
var _map_scroll_position: int = 0
var _map_scroll_depth: int = -1
var _tree_scroll: ScrollContainer
var _tree_scroll_position := 0
var _navigation_buttons: Dictionary = {}
var _resource_values: Dictionary = {}
var _resource_strip: HFlowContainer
var _rendered_page := ""


func _ready() -> void:
	_page = initial_page
	if not inspection_only and _is_hub():
		_page = "hub"
	_build_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = INK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var backdrop := ART_THEME.texture("background")
	if backdrop != null:
		var painted_background := TextureRect.new()
		painted_background.name = "CatabasePaintedBackdrop"
		painted_background.texture = backdrop
		painted_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		painted_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		painted_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		painted_background.modulate = Color(0.58, 0.68, 0.71)
		painted_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(painted_background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	_root = VBoxContainer.new()
	_root.add_theme_constant_override("separation", 14)
	margin.add_child(_root)
	var hero_banner := PanelContainer.new()
	hero_banner.name = "CatabaseHeroBanner"
	hero_banner.add_theme_stylebox_override("panel", ART_THEME.style("banner"))
	_root.add_child(hero_banner)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 16)
	hero_banner.add_child(heading)
	var hero_frame := PanelContainer.new()
	hero_frame.name = "CatabaseHeroPortraitFrame"
	var portrait_style := ART_THEME.style("portrait_frame")
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		portrait_style.set_content_margin(side, 8)
	hero_frame.add_theme_stylebox_override("panel", portrait_style)
	heading.add_child(hero_frame)
	_icon(hero_frame, CatabasePaintedIconCatalog.emblem_icon("achilles"), 64)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(names)
	_label(names, "LA DESCENTE D'ACHILLE", 13, GOLD)
	_label(names, "Catabase", 32, TEXT, true)
	var close := _button(heading, "Fermer" if inspection_only else "Accueil")
	ART_THEME.apply_button(close, false, false, "close" if inspection_only else "home")
	close.pressed.connect(_close)
	_summary = _label(names, "", 14, MUTED)
	_resource_strip = HFlowContainer.new()
	_resource_strip.name = "CatabaseResources"
	_resource_strip.add_theme_constant_override("h_separation", 12)
	_resource_strip.add_theme_constant_override("v_separation", 6)
	_root.add_child(_resource_strip)
	for resource in [["health", "Vitalité"], ["level", "Niveau"], ["destiny", "Points de destin"], ["oboles", "Oboles"]]:
		var row := HBoxContainer.new()
		row.name = "Resource_" + resource[0]
		row.add_theme_constant_override("separation", 7)
		row.custom_minimum_size.x = 145
		_resource_strip.add_child(row)
		_icon(row, ART_THEME.icon("resources", resource[0]), 28)
		var value := _label(row, resource[1], 17, GOLD if resource[0] == "oboles" else TEXT)
		value.autowrap_mode = TextServer.AUTOWRAP_OFF
		_resource_values[resource[0]] = value
	if GameManager.expedition != null:
		var navigation := HFlowContainer.new()
		navigation.name = "CatabaseNavigation"
		navigation.add_theme_constant_override("h_separation", 8)
		navigation.add_theme_constant_override("v_separation", 6)
		_root.add_child(navigation)
		for entry in [["map", "Carte", "map"], ["build", "Arbre & techniques", "tree"], ["gear", "Équipement & stats", "equipment"], ["hub", "La halte", "halt"], ["journal", "Carnet", "journal"]]:
			var tab := _button(navigation, entry[1])
			tab.name = "CatabaseTab_" + entry[0]
			tab.set_meta("catabase_icon", entry[2])
			_navigation_buttons[entry[0]] = tab
			tab.pressed.connect(func(): _page = entry[0]; _render())
	_body = VBoxContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root.add_child(_body)
	_status = _label(_root, "", 15, GOLD)
	_render()
	ART_THEME.reveal(_root)
	if _navigation_buttons.has(_page):
		(_navigation_buttons[_page] as Button).grab_focus.call_deferred()
	if GameManager.expedition != null and not inspection_only:
		GameManager.set_run_ui_mode(PersistentRunUI.RunUIMode.NON_COMBAT)
		var persistent := GameManager.get_persistent_run_ui()
		if persistent != null:
			persistent.inventory_screen.screen_closed.connect(func():
				GameManager.save_expedition()
				_render.call_deferred()
			)


func _unhandled_key_input(event: InputEvent) -> void:
	if inspection_only and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _render() -> void:
	var previous_focus := get_viewport().gui_get_focus_owner()
	var focus_name := ""
	if previous_focus != null and _body.is_ancestor_of(previous_focus) and not str(previous_focus.name).begins_with("@"):
		focus_name = str(previous_focus.name)
	if is_instance_valid(_map_scroll) and _map_scroll.is_inside_tree():
		_map_scroll_position = _map_scroll.scroll_vertical
	if is_instance_valid(_tree_scroll) and _tree_scroll.is_inside_tree():
		_tree_scroll_position = _tree_scroll.scroll_vertical
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	var session := GameManager.expedition
	_resource_strip.visible = session != null
	for page_id in _navigation_buttons:
		var tab: Button = _navigation_buttons[page_id]
		ART_THEME.apply_tab(tab, page_id == _page, str(tab.get_meta("catabase_icon")))
	if session == null:
		_render_landing()
		return
	var hero := session.character.unit
	var champion := session.character.champion_progression
	_summary.text = "ACHILLE  ·  Étapes %d / 20" % session.route.completed_node_ids.size()
	_resource_values.health.text = "%d / %d PV" % [hero.current_hp, hero.max_hp.get_int()]
	_resource_values.level.text = "Niveau %d" % champion.current_level
	_resource_values.destiny.text = "%d %s de destin" % [session.build.points, "point" if session.build.points == 1 else "points"]
	_resource_values.oboles.text = "%d oboles" % session.gold
	_status.text = "Consultation en combat · le chemin et le kit se choisissent entre les rencontres." if inspection_only else session.last_message
	_status.add_theme_color_override("font_color", GOLD)
	match _page:
		"build": _render_build()
		"gear": _render_gear()
		"journal": _render_journal()
		"hub": _render_hub()
		_: _render_map()
	if not _rendered_page.is_empty() and _rendered_page != _page:
		ART_THEME.reveal(_body)
	_rendered_page = _page
	if not focus_name.is_empty():
		_restore_body_focus.call_deferred(focus_name)


func _restore_body_focus(control_name: String) -> void:
	var control := _body.find_child(control_name, true, false) as Control
	if control != null and control.is_visible_in_tree() and control.focus_mode != Control.FOCUS_NONE:
		control.grab_focus()


func _render_landing() -> void:
	_summary.text = "Le chemin se construit au fil de Catabase."
	var column := _scroll_column(_body)
	var intro := _card(column, GOLD)
	_label(intro, "Aucune descente en cours", 30, TEXT, true)
	_label(intro, "Lancez Catabase depuis la sélection habituelle. Achille entre dans le premier combat avec Frappe du Péléide, Ruée fulminante, Tir du Pélion et Garde de bronze. Ses choix viennent ensuite.", 20)
	var return_button := _button(intro, "Revenir à l'accueil", true)
	return_button.pressed.connect(func(): GameManager.return_to_title())
	if FileAccess.file_exists(ExpeditionSaveService.SAVE_PATH):
		var resume := _button(intro, "Reprendre Catabase")
		resume.name = "ResumeExpedition"
		ART_THEME.apply_button(resume, false, false, "save")
		resume.pressed.connect(func():
			if not GameManager.resume_expedition():
				_status.text = "Cette sauvegarde est incompatible ou endommagée. Elle a été conservée."
		)
	_status.text = "Quinze combats et cinq haltes · un départ commun, une légende à construire."


func _render_map() -> void:
	var session := GameManager.expedition
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(row)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.9
	row.add_child(left)
	_label(left, "LE PARCHEMIN DE LA DESCENTE", 14, GOLD)
	_label(left, "Traits pleins : parcouru · pointillés : chemins possibles · ? : inconnu", 14, MUTED)
	_map_scroll = ScrollContainer.new()
	_map_scroll.follow_focus = true
	_map_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(_map_scroll)
	var canvas := MAP_CANVAS.new()
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_scroll.add_child(canvas)
	canvas.set_route(session.route)
	canvas.node_selected.connect(func(id: String): _selected_node = id; _render())
	canvas.select_node(_selected_node)
	var completed_depth := session.route.completed_node_ids.size()
	if completed_depth != _map_scroll_depth:
		_map_scroll_position = canvas.get_depth_scroll_position(maxi(1, completed_depth))
		_map_scroll_depth = completed_depth
	_map_scroll.set_deferred("scroll_vertical", _map_scroll_position)
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 330
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	var details := _scroll_column(right)
	if session.route.phase == "reward" and not _is_hub():
		_render_rewards(details)
		return
	var selected: Dictionary = {}
	for node in session.route.get_visible_nodes():
		if node.id == _selected_node:
			selected = node
	if selected.is_empty():
		var available := session.route.get_available_nodes()
		if not available.is_empty():
			selected = available[0]
			_selected_node = str(selected.id)
			canvas.select_node(_selected_node)
	var card := _card(details, GOLD)
	if selected.is_empty():
		_label(card, "Votre prochain seuil", 24, TEXT, true)
		_label(card, "Sélectionnez une destination sur la carte.")
		return
	_label(card, "SEUIL %02d  /  %s" % [int(selected.depth), TYPE_NAMES.get(str(selected.kind), "Horizon incertain")], 14, GOLD)
	_label(card, str(selected.title), 25, TEXT, true)
	_label(card, str(selected.get("hint", "Une part du chemin reste à découvrir.")), 18)
	if str(selected.reward) != "":
		_label(card, "Promesse : " + str(REWARD_NAMES.get(str(selected.reward), "À découvrir")), 17, TEAL)
	var available := bool(selected.get("available", false)) and session.route.phase == "map"
	if str(selected.kind) == "elite":
		_label(card, "Élite : +20 % PV et puissance par rapport au même combat normal. Victoire : 65 oboles au lieu de 35.", 16, RED)
	if str(selected.kind) in ["normal", "elite", "boss"]:
		_label(card, "Le danger augmente avec la profondeur. Votre kit et votre équipement seront engagés jusqu'à la fin du combat.", 16, MUTED)
	# The commitment stays visible while the destination description scrolls.
	var engage := _button(right, "S'engager sur ce chemin  →" if available else "Repérer cette destination", true)
	engage.name = "CommitDestination"
	engage.disabled = not available or inspection_only
	engage.pressed.connect(func():
		engage.disabled = true
		if GameManager.choose_expedition_node(_selected_node):
			if GameManager.expedition.route.phase != "combat":
				if _is_hub(): _page = "hub"
				_render()
		else:
			var save_status: Dictionary = GameManager.get_expedition_save_status()
			var pending := bool(save_status.get("pending", false))
			engage.disabled = pending or session.route.phase != "map"
			_status.text = str(save_status.get("message", "")) if pending else "Ce chemin n'est plus accessible."
			_status.add_theme_color_override("font_color", RED)
	)
	var advice := _card(details)
	_label(advice, "AVANT DE PARTIR", 14, GOLD)
	_label(advice, "%d techniques actives, %d connues. Les sorts retirés restent disponibles dans votre réserve." % [session.character.loadout.get_equipped_spells().size(), session.character.loadout.get_known_spells().size()], 17)
	var workshop := _button(advice, "Composer le kit")
	workshop.name = "ComposeCatabaseKit"
	workshop.pressed.connect(func(): _page = "build"; _render())
	if _is_hub():
		var visit := _button(advice, "Revenir dans la halte", true)
		visit.pressed.connect(func(): _page = "hub"; _render())


func _render_rewards(parent: Control, capacity_only := false) -> void:
	var session := GameManager.expedition
	var node := session.route.get_current_node()
	if not capacity_only:
		var reward_heading := HBoxContainer.new()
		reward_heading.add_theme_constant_override("separation", 10)
		parent.add_child(reward_heading)
		_icon(reward_heading, ART_THEME.icon("resources", "victory"), 30)
		var caption := _label(reward_heading, "UNE ÉTAPE FRANCHIE", 14, TEAL)
		caption.name = "RewardHeading"
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_label(parent, str(node.title), 26, TEXT, true)
		_label(parent, "Choisissez une seule récompense. Les autres occasions restent sur ce seuil.", 17)
	if int(node.depth) == ExpeditionBuildState.CAPACITY_DEPTH and session.build.depth_eight_choice.is_empty():
		var fork := _card(parent, GOLD)
		_label(fork, "L'AMPLEUR OU L'INTENSITÉ", 15, GOLD)
		_label(fork, "Un choix exclusif pour la suite de votre kit.", 17)
		for choice in [["slot", "Un sixième emplacement", "Équipez une technique supplémentaire parmi celles que vous connaissez."], ["mutation", "Tempête du Péléide", session.build.catalog.get_spell("exp_tempest").description]]:
			_label(fork, choice[2], 16, MUTED)
			var button := _button(fork, choice[1], true)
			button.disabled = inspection_only
			button.pressed.connect(func(): _action_result(GameManager.choose_expedition_capacity(choice[0])))
		return
	for offer in session.reward_options(GameManager.item_catalog):
		var card := _card(parent, TEAL)
		_label(card, str(offer.title), 21, TEXT, true)
		_label(card, str(offer.description), 16)
		var button := _button(card, "Choisir cette récompense", true)
		button.disabled = inspection_only
		button.pressed.connect(func(): _action_result(GameManager.claim_expedition_reward(str(offer.id))))


func _render_build() -> void:
	var session := GameManager.expedition
	var kit_row := HBoxContainer.new()
	_body.add_child(kit_row)
	var names := PackedStringArray()
	for spell in session.character.loadout.get_equipped_spells(): names.append(spell.spell_name)
	var kit := _label(kit_row, "%d EMPLACEMENTS  ·  %s" % [session.character.loadout.get_active_slot_count(), " / ".join(names)], 15, GOLD)
	kit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var edit := _button(kit_row, "Voir l'arbre" if _show_loadout else "Modifier le kit")
	edit.name = "ToggleCatabaseLoadout"
	edit.pressed.connect(func(): _show_loadout = not _show_loadout; _render())
	if _show_loadout:
		var loadout_column := _scroll_column(_body)
		_render_loadout(loadout_column)
		return
	var doctrines: Dictionary = session.build.catalog.doctrines()
	var tabs := HFlowContainer.new()
	_body.add_child(tabs)
	for doctrine_id in doctrines:
		var button := _button(tabs, str(doctrines[doctrine_id].title))
		button.name = "Doctrine_" + str(doctrine_id)
		button.icon = CatabasePaintedIconCatalog.emblem_icon(str(doctrine_id))
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 28)
		ART_THEME.apply_tab(button, _doctrine == doctrine_id)
		button.pressed.connect(func(): _doctrine = doctrine_id; _selected_technique = ""; _render())
	for discovered_axis in ["elements", "serment"]:
		if session.build.is_axis_discovered(discovered_axis):
			var button := _button(tabs, "Affinités" if discovered_axis == "elements" else "Serment découvert")
			button.name = "Doctrine_" + discovered_axis
			button.icon = CatabasePaintedIconCatalog.emblem_icon(discovered_axis)
			button.expand_icon = true
			button.add_theme_constant_override("icon_max_width", 28)
			ART_THEME.apply_tab(button, _doctrine == discovered_axis)
			button.pressed.connect(func(): _doctrine = discovered_axis; _selected_technique = ""; _render())
	var selected_axes: Array = [str(_doctrine)]
	if doctrines.has(_doctrine):
		selected_axes = doctrines[_doctrine].axes
		_label(_body, str(doctrines[_doctrine].description), 16, MUTED)
	else:
		_label(_body, "Une branche découverte pendant la descente. Ses choix engagent le même budget que vos doctrines.", 16, MUTED)
	var offers: Array[Dictionary] = []
	for offer in session.build.get_offers():
		if str(offer.axis) in selected_axes or str(offer.id) == _doctrine + ".root":
			offers.append(offer)
	var selected: Dictionary = {}
	for offer in offers:
		if str(offer.id) == _selected_technique: selected = offer
	if selected.is_empty() and not offers.is_empty():
		selected = offers[0]
		for offer in offers:
			if str(offer.id) == _doctrine + ".root": selected = offer
		_selected_technique = str(selected.id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(row)
	var left := _scroll_column(row)
	_tree_scroll = left.get_parent() as ScrollContainer
	_tree_scroll.set_deferred("scroll_vertical", _tree_scroll_position)
	left.get_parent().size_flags_stretch_ratio = 1.9
	var canvas := TREE_CANVAS.new()
	left.add_child(canvas)
	canvas.configure(offers, _selected_technique)
	canvas.technique_selected.connect(func(id: String): _selected_technique = id; _render())
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 330
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	var details := _scroll_column(right)
	if not selected.is_empty(): _render_technique(details, selected, right)
	var tip := _card(details)
	_label(tip, "UNE LÉGENDE, PLUSIEURS CHEMINS", 13, GOLD)
	_label(tip, "Les liens indiquent les prérequis réels. Les trois doctrines peuvent se mêler. Les formes d'une même famille occupent un seul emplacement.", 16, MUTED)
	if not session.build.is_axis_discovered("elements") or not session.build.is_axis_discovered("serment"):
		_label(tip, "Certaines branches restent inconnues. Cherchez des sanctuaires et des mémoires sur la carte.", 16, TEAL)
	if not session.build.correction_used:
		var undo := _button(tip, "Corriger le dernier achat · 1/run")
		undo.name = "UndoCatabaseTechnique"
		undo.tooltip_text = "Rembourse le dernier achat de l'arbre. Une seule correction pour toute la descente ; les cartes, caractéristiques et découvertes restent acquises."
		undo.disabled = inspection_only or not session.is_editable() or session.build.unlocked_node_ids.is_empty()
		undo.pressed.connect(func(): _action_result(GameManager.undo_expedition_technique()))


func _render_technique(parent: Control, offer: Dictionary, actions: Control) -> void:
	var session := GameManager.expedition
	var card := _card(parent, TEAL if bool(offer.owned) else GOLD)
	var cost := int(offer.cost)
	var point_label := "point" if cost == 1 else "points"
	_label(card, str(offer.kind).to_upper() + "  /  %d %s" % [cost, point_label.to_upper()], 13, GOLD)
	_illustrated_title(card, str(offer.title), CatabasePaintedIconCatalog.node_icon(offer) if bool(offer.get("discovered", true)) else ART_THEME.icon("nav", "lock"), 64)
	_label(card, str(offer.description), 17)
	var prereq: Array = offer.get("prerequisites", [])
	if not prereq.is_empty():
		var names := PackedStringArray()
		for id in prereq: names.append(str(session.build.catalog.get_node(str(id)).get("title", id)))
		_label(card, "Requiert : " + " + ".join(names), 14, MUTED)
	var buy := _button(actions, "Acquis" if bool(offer.owned) else "Choisir · %d %s" % [cost, point_label], bool(offer.available))
	buy.name = "PurchaseTechnique"
	buy.disabled = inspection_only or not bool(offer.available)
	buy.tooltip_text = str(offer.get("reason", ""))
	buy.pressed.connect(func(): _action_result(GameManager.purchase_expedition_technique(str(offer.id))))
	if not bool(offer.available) and not bool(offer.owned):
		_label(card, str(offer.get("reason", "")), 14, MUTED)


func _is_hub() -> bool:
	return GameManager.expedition != null and GameManager.expedition.route.phase == "reward" \
		and str(GameManager.expedition.route.get_current_node().get("kind", "")) in ["hub", "merchant", "sanctuary", "lore"]


func _render_hub() -> void:
	if not _is_hub():
		var card := _card(_body, GOLD)
		_label(card, "La prochaine halte vous attend", 26, TEXT, true)
		_label(card, "La carte indique les refuges, marchands, sanctuaires et rencontres de mémoire visibles sur votre chemin.", 19)
		var map_button := _button(card, "Consulter le parchemin")
		map_button.pressed.connect(func(): _page = "map"; _render())
		return
	var session := GameManager.expedition
	var node := session.route.get_current_node()
	var services: Array[Dictionary] = session.hub_services(GameManager.item_catalog)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(row)
	var location := HUB_CANVAS.new()
	location.size_flags_stretch_ratio = 1.9
	row.add_child(location)
	location.configure(str(node.title), services, _selected_service, node)
	location.zone_selected.connect(func(id: String): _selected_service = id; _render())
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 330
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	var details := _scroll_column(right)
	_label(details, str(node.title), 26, TEXT, true)
	_label(details, "%d oboles · prenez le temps de préparer la suite." % session.gold, 16, GOLD)
	var sanctuary := _button(right, "Rejoindre le Sanctuaire")
	sanctuary.name = "EnterSanctuary"
	ART_THEME.apply_button(sanctuary, false, false, "halt")
	sanctuary.disabled = inspection_only
	sanctuary.tooltip_text = "Retrouvez les services de cette halte dans le refuge. Vous pourrez revenir ici sans reprendre la route."
	sanctuary.pressed.connect(func():
		var result: Dictionary = GameManager.open_sanctuary()
		if not bool(result.get("success", false)):
			_status.text = str(result.get("message", "Le Sanctuaire n'est pas accessible pour le moment."))
			_status.add_theme_color_override("font_color", RED)
	)
	if int(node.depth) == ExpeditionBuildState.CAPACITY_DEPTH and session.build.depth_eight_choice.is_empty():
		_render_rewards(details, true)
		return
	var selected: Dictionary = {}
	for service in services:
		if str(service.id) == _selected_service: selected = service
	if selected.is_empty() and not services.is_empty():
		selected = services[0]
		_selected_service = str(selected.id)
	if not selected.is_empty():
		var card := _card(details, GOLD)
		_label(card, str(selected.title), 23, TEXT, true)
		_label(card, str(selected.description), 17)
		var cost := int(selected.get("cost", 0))
		var used := bool(selected.get("used", false))
		var accept := _button(card, "Déjà accompli" if used else ("Payer %d oboles" % cost if cost > 0 else "Découvrir"), true)
		accept.name = "UseHubService"
		accept.disabled = inspection_only or used or session.gold < cost
		accept.pressed.connect(func(): _action_result(GameManager.use_catabase_hub_service(str(selected.id))))
		if session.gold < cost: _label(card, "Il vous manque %d oboles." % (cost - session.gold), 15, RED)
	var leave := _button(right, "Reprendre la route  →", true)
	leave.name = "LeaveHub"
	leave.disabled = inspection_only
	leave.pressed.connect(func():
		var result: Dictionary = GameManager.claim_expedition_reward("leave_hub")
		if bool(result.get("success", false)): _page = "map"
		_action_result(result)
	)


func _render_loadout(parent: Control) -> void:
	var session := GameManager.expedition
	var loadout := session.character.loadout
	var box := _card(parent, GOLD)
	_label(box, "VOTRE KIT  /  %d EMPLACEMENTS" % loadout.get_active_slot_count(), 15, GOLD)
	_label(box, "Remplacez même votre garde ou votre déplacement. Une seule forme d'une même famille peut être équipée.", 17)
	var slots := HFlowContainer.new()
	slots.add_theme_constant_override("h_separation", 12)
	slots.add_theme_constant_override("v_separation", 12)
	box.add_child(slots)
	var ids := loadout.get_spell_slot_ids()
	for slot in loadout.get_active_slot_count():
		var slot_box := VBoxContainer.new()
		slots.add_child(slot_box)
		_label(slot_box, "EMPLACEMENT %d" % (slot + 1), 12, MUTED)
		var dropdown := OptionButton.new()
		dropdown.name = "LoadoutSlot_%d" % slot
		dropdown.custom_minimum_size = Vector2(242, 44)
		dropdown.add_item("Emplacement libre")
		dropdown.set_item_metadata(0, "")
		var index := 1
		for spell in loadout.get_known_spells():
			var id := str(spell.get_effective_spell_id())
			dropdown.add_icon_item(spell.icon, spell.spell_name)
			dropdown.set_item_metadata(index, id)
			if str(ids[slot]) == id:
				dropdown.select(index)
				dropdown.tooltip_text = spell.description
			for other in ids.size():
				if other != slot and ids[other] != &"" and session.build.catalog.get_spell_family(str(ids[other])) == session.build.catalog.get_spell_family(id):
					dropdown.set_item_disabled(index, true)
			index += 1
		dropdown.disabled = inspection_only or not session.is_editable()
		dropdown.add_theme_constant_override("icon_max_width", 28)
		slot_box.add_child(dropdown)
		dropdown.item_selected.connect(func(selected: int):
			var success := GameManager.equip_expedition_spell(StringName(dropdown.get_item_metadata(selected)), slot)
			_render()
			if not success: _status.text = "Cette famille de technique occupe déjà un autre emplacement."
		)
	if loadout.get_active_slot_count() < 5:
		_label(box, "Prochain emplacement : niveau 5. Le départ conserve les quatre techniques d'Achille.", 14, TEAL)
	elif session.build.depth_eight_choice.is_empty():
		_label(box, "Étape XII : sixième emplacement ou Tempête du Péléide, une transformation exclusive de Frappe.", 14, TEAL)
	else:
		_label(box, "Sixième emplacement acquis." if session.build.depth_eight_choice == "slot" else "Tempête du Péléide acquise : sa forme remplace Frappe dans un emplacement.", 14, TEAL)
	var descriptions := HFlowContainer.new()
	descriptions.add_theme_constant_override("h_separation", 20)
	box.add_child(descriptions)
	for spell in loadout.get_equipped_spells():
		var label := _label(descriptions, "%s  ·  %d PA" % [spell.spell_name, spell.ap_cost], 15, MUTED)
		# Flow rows need the natural text width to wrap whole labels, not letters.
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.tooltip_text = spell.description


func _render_gear() -> void:
	var session := GameManager.expedition
	var state := session.character
	var column := _scroll_column(_body)
	var stats := _card(column, GOLD)
	var available_points := state.champion_progression.unspent_attribute_points
	_label(stats, "CARACTÉRISTIQUES  /  %d %s" % [available_points, "POINT DISPONIBLE" if available_points == 1 else "POINTS DISPONIBLES"], 15, GOLD)
	_label(stats, "Prouesse %d   ·   Armure %d   ·   Esquive %d %%   ·   %d PA / %d PM" % [state.unit.attack_power.get_int(), state.unit.armure.get_int(), roundi(state.unit.esquive.get_value() * 100), state.unit.max_ap.get_int(), state.unit.max_mp.get_int()], 21)
	for attr in [["vitality", "Vitalité", "+6 % des PV de base par point."], ["power", "Puissance", "+5 % de Prouesse par point."], ["resolve", "Résolution", "+4 armure et +5 % aux boucliers créés."], ["wisdom", "Sagesse", "+10 % XP aux prochaines étapes ; accélère les caractéristiques, sans donner de points de destin."]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		stats.add_child(row)
		var stat_id := str({"vitality": "max_hp", "power": "attack_power", "resolve": "armure"}.get(attr[0], ""))
		_icon(row, ART_THEME.icon("resources", "level") if attr[0] == "wisdom" else CatabasePaintedIconCatalog.stat_icon(stat_id), 36)
		var name_label := _label(row, "%s  ·  %s" % [attr[1], attr[2]], 18)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var button := _button(row, "+1 " + attr[1])
		button.name = "Attribute_" + str(attr[0])
		button.disabled = inspection_only or not session.is_editable() or state.champion_progression.unspent_attribute_points == 0 or (attr[0] == "wisdom" and state.champion_progression.wisdom_points >= 5)
		button.pressed.connect(func():
			GameManager.spend_champion_attribute(&"achilles", StringName(attr[0]))
			GameManager.save_expedition()
			_render()
		)
	var gear := _card(column, TEAL)
	_label(gear, "ARMES, ARMURES ET ACCESSOIRES", 15, TEAL)
	var equipment_cards := GridContainer.new()
	equipment_cards.name = "CatabaseEquipmentCards"
	equipment_cards.columns = 3
	equipment_cards.add_theme_constant_override("h_separation", 14)
	gear.add_child(equipment_cards)
	for slot in [ItemDefinition.EquipmentSlot.WEAPON, ItemDefinition.EquipmentSlot.ARMOR, ItemDefinition.EquipmentSlot.ACCESSORY]:
		var item: ItemInstance = state.equipment_loadout.get_item(slot)
		var title := "Aucun équipement"
		var description := ""
		var item_icon: Texture2D = ART_THEME.icon("nav", "equipment")
		if item != null:
			var definition := GameManager.item_catalog.get_definition(item.definition_id)
			title = definition.display_name
			description = definition.description
			item_icon = InventoryItemTile.presentation_icon(definition)
		var equipped := _card(equipment_cards)
		equipped.name = "EquipmentCard_%d" % slot
		_label(equipped, ["ARME", "ARMURE", "ACCESSOIRE"][slot], 13, GOLD)
		_icon(equipped, item_icon, 76)
		_label(equipped, title, 18, TEXT, true)
		if not description.is_empty():
			_label(equipped, description, 15, MUTED)
		else:
			_label(equipped, "Les trouvailles de la descente apparaîtront ici une fois équipées.", 15, MUTED)
	var inventory := _button(gear, "Ouvrir l'inventaire et équiper les trouvailles", true)
	inventory.name = "OpenCatabaseInventory"
	ART_THEME.apply_button(inventory, true, false, "equipment")
	inventory.disabled = inspection_only
	inventory.pressed.connect(func():
		var persistent := GameManager.get_persistent_run_ui()
		if persistent != null:
			persistent.open_inventory_screen(&"achilles")
	)
	_label(gear, "Les équipements peuvent être échangés entre les destinations. Les consommables restent utilisables pendant le combat selon leurs règles.", 16, MUTED)


func _render_journal() -> void:
	var session := GameManager.expedition
	var column := _scroll_column(_body)
	_label(column, "LA MÉMOIRE DU CHEMIN", 27, TEXT, true)
	_label(column, "Graine %d  ·  %d techniques connues  ·  %d choix d'arbre" % [session.route.seed, session.character.loadout.get_known_spells().size(), session.build.unlocked_node_ids.size()], 18, GOLD)
	if session.journal.is_empty():
		_label(column, "Le premier seuil vous attend.", 20, MUTED)
	for entry in session.journal:
		_label(column, "—  " + entry, 19)
	_label(column, "La carte vous révèle deux profondeurs de destinations. Les inconnues et les passages cachés gardent leur contenu jusqu'à leur découverte. Les récompenses proposées restent les mêmes à la reprise.", 17, MUTED)


func _action_result(result: Dictionary) -> void:
	_render()
	_status.text = str(result.get("message", result.get("reason", "Choix enregistré.")))
	if _status.text.is_empty(): _status.text = "Choix enregistré."
	_status.add_theme_color_override("font_color", TEAL if bool(result.get("success", false)) else RED)


func _close() -> void:
	if inspection_only:
		inspection_closed.emit()
		queue_free()
	else:
		if not GameManager.request_return_to_title():
			var status: Dictionary = GameManager.get_expedition_save_status()
			_status.text = str(status.get("message", "Sauvegarde impossible. Votre expédition reste ouverte."))
			_status.add_theme_color_override("font_color", RED)


func _scroll_column(parent: Control) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 14)
	scroll.add_child(column)
	return column


func _card(parent: Control, accent: Color = LINE) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", ART_THEME.style("card", "selected" if accent == TEAL else "normal"))
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	return box


func _label(parent: Control, value: String, font_size: int = 18, color: Color = TEXT, heading: bool = false) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if heading: label.add_theme_font_override("font", TITLE_FONT)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


func _button(parent: Control, value: String, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 44
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ART_THEME.apply_button(button, primary)
	parent.add_child(button)
	return button


func _icon(parent: Control, image: Texture2D, extent: int) -> TextureRect:
	if image == null:
		return null
	var view := TextureRect.new()
	view.name = "PaintedIcon"
	view.texture = image
	view.custom_minimum_size = Vector2(extent, extent)
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(view)
	return view


func _illustrated_title(parent: Control, title: String, image: Texture2D, extent: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	_icon(row, image, extent)
	var label := _label(row, title, 23, TEXT, true)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _build_theme() -> void:
	ART_THEME.apply(self)
