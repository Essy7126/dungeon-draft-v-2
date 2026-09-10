class_name ExpeditionScreen
extends Control
## One decision at a time: progression, reward, preparation, then the full-page route.

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
const ROUTE_VIEW := preload("res://ui/expedition/expedition_route_view.gd")
const FLOW := preload("res://core/expedition/expedition_flow.gd")
const REWARD_CARD := preload("res://ui/expedition/expedition_reward_card.gd")
const ATTRIBUTES_VIEW := preload("res://ui/expedition/expedition_attributes_view.gd")
const TREE_CANVAS := preload("res://ui/expedition/expedition_tree_canvas.gd")
const HUB_CANVAS := preload("res://ui/expedition/catabase_hub_canvas.gd")

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
var _hero_banner: PanelContainer
var _navigation: HBoxContainer
var _flow_rail: HFlowContainer
var _flow_labels: Array[Label] = []
var _route_view: Control
var _selected_reward := ""
var _selected_reward_node := ""
var _confirm_reward: Button
var _reward_choices: Dictionary = {}
var _reward_summary: Label
var _reward_offers: Dictionary = {}
var _attributes_view: Control
var _progression_continue: Button
var _close_button: Button
var _return_page := ""
var _skills_tab := "equipped"
var _last_reward: Dictionary = {}


func _ready() -> void:
	_page = initial_page
	if not inspection_only and GameManager.expedition != null:
		_page = FLOW.required_step(GameManager.expedition)
	_build_theme()
	resized.connect(_on_screen_resized)
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
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)
	_root = VBoxContainer.new()
	_root.add_theme_constant_override("separation", 10)
	margin.add_child(_root)
	_hero_banner = PanelContainer.new()
	_hero_banner.name = "CatabaseHeroBanner"
	var banner_style := ART_THEME.style("banner")
	banner_style.content_margin_left = 18
	banner_style.content_margin_right = 18
	banner_style.content_margin_top = 8
	banner_style.content_margin_bottom = 8
	_hero_banner.add_theme_stylebox_override("panel", banner_style)
	_root.add_child(_hero_banner)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 10)
	_hero_banner.add_child(heading)
	_icon(heading, CatabasePaintedIconCatalog.emblem_icon("achilles"), 36)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	names.custom_minimum_size.x = 110
	heading.add_child(names)
	_label(names, "Catabase", 21, TEXT, true)
	_summary = _label(names, "", 13, MUTED)
	_navigation = HBoxContainer.new()
	_navigation.name = "CatabaseNavigation"
	_navigation.add_theme_constant_override("separation", 6)
	_navigation.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heading.add_child(_navigation)
	for entry in [["gear", "Inventaire", "equipment", "Vos objets, leur équipement et leurs effets."], ["build", "Compétences", "tree", "Vos actions en combat et les nouvelles techniques à apprendre."], ["attributes", "Caractéristiques", "", "Vos points de vie, vos dégâts et votre protection."]]:
		var tab := _button(_navigation, entry[1])
		tab.name = "CatabaseTab_" + entry[0]
		tab.set_meta("catabase_icon", entry[2])
		tab.tooltip_text = entry[3]
		if entry[0] == "attributes":
			tab.icon = ART_THEME.icon("resources", "level")
			tab.expand_icon = true
			tab.add_theme_constant_override("icon_max_width", 24)
		_navigation_buttons[entry[0]] = tab
		tab.pressed.connect(func(): _open_inventory() if entry[0] == "gear" else _navigate(entry[0]))
	_close_button = _button(heading, "Menu")
	_close_button.name = "CloseExpeditionScreen"
	_close_button.custom_minimum_size.x = 100
	_close_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_close_button.pressed.connect(_close_current_view)
	_resource_strip = HFlowContainer.new()
	_resource_strip.name = "CatabaseResources"
	_resource_strip.add_theme_constant_override("h_separation", 18)
	_resource_strip.add_theme_constant_override("v_separation", 4)
	_root.add_child(_resource_strip)
	for resource in [["health", "Vitalité", "PV : la vie restante. À zéro, la descente prend fin."], ["level", "Niveau", "L'expérience gagnée augmente votre niveau et donne des points de caractéristique."], ["destiny", "Points de destin", "À dépenser dans Compétences pour apprendre des techniques. Vous pouvez les conserver."], ["oboles", "Oboles", "La monnaie de la run : achats et soins chez les marchands."]]:
		var row := HBoxContainer.new()
		row.name = "Resource_" + resource[0]
		row.add_theme_constant_override("separation", 6)
		row.tooltip_text = resource[2]
		_resource_strip.add_child(row)
		_icon(row, ART_THEME.icon("resources", resource[0]), 26)
		var value := _label(row, resource[1], 16, GOLD if resource[0] == "oboles" else TEXT)
		value.tooltip_text = resource[2]
		value.autowrap_mode = TextServer.AUTOWRAP_OFF
		_resource_values[resource[0]] = value
	_flow_rail = HFlowContainer.new()
	_flow_rail.name = "ExpeditionFlowSteps"
	_flow_rail.add_theme_constant_override("h_separation", 20)
	_root.add_child(_flow_rail)
	for title in ["01  Renforcer", "02  Récompense", "03  Préparer", "04  Explorer"]:
		var step := _label(_flow_rail, title, 14, MUTED)
		step.autowrap_mode = TextServer.AUTOWRAP_OFF
		_flow_labels.append(step)
	_body = VBoxContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root.add_child(_body)
	_status = _label(_root, "", 15, GOLD)
	_render()
	ART_THEME.reveal(_root)
	if GameManager.expedition != null and not inspection_only:
		GameManager.set_run_ui_mode(PersistentRunUI.RunUIMode.NON_COMBAT)
		var persistent := GameManager.get_persistent_run_ui()
		if persistent != null:
			persistent.inventory_screen.screen_closed.connect(_on_inventory_closed)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		var persistent := GameManager.get_persistent_run_ui()
		if persistent != null and persistent.has_active_modal() and not inspection_only:
			return
		get_viewport().set_input_as_handled()
		_close_current_view()


func _render() -> void:
	if not inspection_only and GameManager.expedition != null:
		var required := FLOW.required_step(GameManager.expedition)
		if _page in ["map", "preparation"] and required != "map":
			_page = required
		elif _page in ["rewards", "capacity"] and _page != required:
			_page = "preparation" if required == "map" else required
	var previous_focus := get_viewport().gui_get_focus_owner()
	var focus_name := ""
	if previous_focus != null and _body.is_ancestor_of(previous_focus) and not str(previous_focus.name).begins_with("@"):
		focus_name = str(previous_focus.name)
	if is_instance_valid(_map_scroll) and _map_scroll.is_inside_tree():
		_map_scroll_position = _map_scroll.scroll_vertical
	if is_instance_valid(_route_view) and _route_view.is_inside_tree():
		_map_scroll_position = _route_view.get_scroll_position()
	if is_instance_valid(_tree_scroll) and _tree_scroll.is_inside_tree():
		_tree_scroll_position = _tree_scroll.scroll_vertical
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	var session := GameManager.expedition
	_resource_strip.visible = session != null
	_hero_banner.show()
	_status.visible = false
	_navigation.visible = session != null
	var auxiliary := _page in ["build", "gear", "attributes", "journal"]
	_close_button.text = "Fermer  ×" if inspection_only or auxiliary else "Retour" if _page == "map" else "Menu"
	_close_button.tooltip_text = "Fermer cet écran et retrouver la run · Échap" if inspection_only else "Revenir à votre écran précédent · Échap" if auxiliary else "Revenir à la préparation · Échap" if _page == "map" else "Pause et options de la run · Échap"
	if is_instance_valid(_flow_rail):
		_flow_rail.visible = session != null and not inspection_only and not auxiliary and _page != "map"
		var step_index := 0 if _page == "progression" else 1 if _page in ["rewards", "capacity", "hub"] else 3 if _page == "map" else 2
		for index in _flow_labels.size():
			_flow_labels[index].add_theme_color_override("font_color", GOLD if index == step_index else TEAL if index < step_index else MUTED)
	for page_id in _navigation_buttons:
		var tab: Button = _navigation_buttons[page_id]
		ART_THEME.apply_tab(tab, page_id == _page or (page_id == "attributes" and _page == "progression"), str(tab.get_meta("catabase_icon")))
	if session == null:
		_render_landing()
		return
	_refresh_resources()
	match _page:
		"progression", "attributes": _render_progression()
		"capacity": _render_choice_screen(true)
		"rewards": _render_choice_screen()
		"preparation": _render_preparation()
		"build": _render_build()
		"gear": _render_gear()
		"journal": _render_journal()
		"hub": _render_hub()
		_: _render_map()
	var page_changed := _rendered_page != _page
	if not _rendered_page.is_empty() and page_changed:
		ART_THEME.reveal(_body)
	_rendered_page = _page
	if page_changed:
		_focus_page_action.call_deferred()
	elif not focus_name.is_empty():
		_restore_body_focus.call_deferred(focus_name)


func _restore_body_focus(control_name: String) -> void:
	var control := _body.find_child(control_name, true, false) as Control
	if control is BaseButton and control.disabled:
		return
	if control != null and control.is_visible_in_tree() and control.focus_mode != Control.FOCUS_NONE:
		control.grab_focus()


func _focus_page_action() -> void:
	var target := str({"progression": "Attribute_vitality", "rewards": "RewardOption_0", "capacity": "Capacity_slot", "attributes": "Attribute_vitality", "preparation": "OpenRouteMap", "map": "RecenterRoute"}.get(_page, ""))
	if _page == "progression" and GameManager.expedition.character.champion_progression.unspent_attribute_points == 0:
		target = "ContinueExpeditionFlow"
	if _page == "progression" and GameManager.expedition.character.champion_progression.unspent_attribute_points > 0:
		_attributes_view.grab_focus()
	elif _page == "attributes" and (inspection_only or GameManager.expedition.character.champion_progression.unspent_attribute_points == 0):
		_close_button.grab_focus()
	elif not target.is_empty():
		_restore_body_focus(target)


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
				_status.show()
		)
	_status.text = "Vingt seuils · des voies à choisir, des haltes à préparer."


func _render_map() -> void:
	var session := GameManager.expedition
	_route_view = ROUTE_VIEW.new()
	_route_view.name = "ExpeditionRouteView"
	_route_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(_route_view)
	var depth := session.route.completed_node_ids.size()
	if depth != _map_scroll_depth:
		_map_scroll_position = -1
		_map_scroll_depth = depth
		_selected_node = ""
	_route_view.configure(session, _selected_node, inspection_only, _map_scroll_position)
	_map_scroll = _route_view.find_child("RouteMapScroll", true, false) as ScrollContainer
	_route_view.destination_selected.connect(func(id: String): _selected_node = id)
	_route_view.destination_committed.connect(_commit_destination)
	_route_view.preparation_requested.connect(func(): _navigate("preparation"))


func _commit_destination(node_id: String) -> void:
	if inspection_only or GameManager.expedition == null:
		return
	if FLOW.required_step(GameManager.expedition) != "map":
		_continue_flow()
		return
	if GameManager.choose_expedition_node(node_id):
		if GameManager.is_merchant_hall_active():
			return
		if GameManager.expedition.route.phase != "combat":
			_page = FLOW.required_step(GameManager.expedition)
			_selected_reward = ""
			_render()
	else:
		_render()
		var save_status: Dictionary = GameManager.get_expedition_save_status()
		_status.text = str(save_status.get("message", "")) if bool(save_status.get("pending", false)) else "Ce chemin n'est plus accessible."
		_status.add_theme_color_override("font_color", RED)
		_status.show()


func _on_screen_resized() -> void:
	if not is_instance_valid(_body): return
	for card in _reward_choices.values():
		if is_instance_valid(card) and card.is_inside_tree():
			card.set_card_extent(_reward_extent())


func _reward_extent() -> Vector2:
	return Vector2(260 if size.x < 1100 else 290, 360 if size.y < 850 else 410)


func _refresh_resources() -> void:
	var session := GameManager.expedition
	if session == null: return
	var hero := session.character.unit
	var champion := session.character.champion_progression
	_summary.text = "Achille · étape %d / 20" % session.route.completed_node_ids.size()
	var values := {"health": "%d / %d PV" % [hero.current_hp, hero.max_hp.get_int()], "level": "Niveau %d" % champion.current_level, "destiny": "%d points de destin" % session.build.points, "oboles": "%d oboles" % session.gold}
	for key in values:
		var label: Label = _resource_values[key]
		var changed := label.text != str(values[key])
		label.text = str(values[key])
		if changed and not _rendered_page.is_empty():
			ART_THEME.reveal(label)
	var points := champion.unspent_attribute_points
	var attributes: Button = _navigation_buttons.attributes
	attributes.text = "Caractéristiques" + (" · %d" % points if points > 0 else "")
	attributes.tooltip_text = "%d point(s) à répartir. Consultez vos PV, vos dégâts et votre protection." % points if points > 0 else "Consultez vos PV, vos dégâts et votre protection."


func _navigate(page: String) -> void:
	if page in ["build", "gear", "attributes", "journal"] and _page not in ["build", "gear", "attributes", "journal"]:
		_return_page = _page
	_page = page
	_render()


func _close_current_view() -> void:
	if inspection_only:
		_close()
	elif _page in ["build", "gear", "attributes", "journal"]:
		if _return_page.is_empty():
			_continue_flow()
		else:
			_page = _return_page
			_return_page = ""
			_render()
	elif _page == "map":
		_navigate("preparation")
	else:
		var persistent := GameManager.get_persistent_run_ui()
		if persistent != null: persistent.open_pause_menu()


func _open_inventory() -> void:
	var persistent := GameManager.get_persistent_run_ui()
	if persistent == null: return
	if inspection_only:
		_close()
	if persistent.open_inventory_screen(&"achilles"):
		ART_THEME.apply_tab(_navigation_buttons.gear, true, "equipment")
	else:
		_status.text = "L'inventaire sera disponible dès que l'action en cours sera terminée."
		_status.show()


func _on_inventory_closed() -> void:
	if not is_inside_tree(): return
	_refresh_resources()
	ART_THEME.apply_tab(_navigation_buttons.gear, false, "equipment")
	if is_instance_valid(_attributes_view) and _attributes_view.is_inside_tree():
		_attributes_view.refresh()
	_navigation_buttons.gear.grab_focus.call_deferred()


func _continue_flow() -> void:
	var required := FLOW.required_step(GameManager.expedition)
	_page = "preparation" if required == "map" else required
	_return_page = ""
	_render()


func _render_progression() -> void:
	_label(_body, "Caractéristiques", 28, TEXT, true)
	_attributes_view = ATTRIBUTES_VIEW.new()
	_attributes_view.name = "ExpeditionAttributesView"
	_attributes_view.focus_mode = Control.FOCUS_ALL
	_attributes_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(_attributes_view)
	_attributes_view.configure(GameManager.expedition, inspection_only)
	_attributes_view.attribute_requested.connect(_spend_attribute)
	if _page == "progression":
		_progression_continue = _button(_body, "Continuer  →", true)
		_progression_continue.name = "ContinueExpeditionFlow"
		_progression_continue.pressed.connect(_continue_flow)
		_refresh_progression_action()


func _refresh_progression_action() -> void:
	if not is_instance_valid(_progression_continue) or not _progression_continue.is_inside_tree(): return
	var remaining := GameManager.expedition.character.champion_progression.unspent_attribute_points
	_progression_continue.text = "Continuer vers la récompense  →" if remaining == 0 else "Encore %d point%s à répartir" % [remaining, "s" if remaining > 1 else ""]
	_progression_continue.disabled = remaining > 0 or inspection_only
	if remaining == 0: _progression_continue.grab_focus.call_deferred()


func _spend_attribute(attribute_id: StringName) -> void:
	if inspection_only: return
	var success := GameManager.spend_champion_attribute(&"achilles", attribute_id)
	if success:
		_attributes_view.refresh()
		_refresh_resources()
		_refresh_progression_action()
	else:
		_status.text = "Ce point n'a pas pu être attribué. Consultez les points disponibles."
		_status.add_theme_color_override("font_color", RED)
		_status.show()


func _render_choice_screen(capacity_only := false) -> void:
	if not capacity_only:
		var heading := _label(_body, "Choisissez une carte", 28, TEXT, true)
		heading.name = "RewardHeading"
		_label(_body, "Un seul choix. Sélectionnez une carte, puis confirmez en bas de l'écran.", 16, MUTED)
	var column := _scroll_column(_body)
	_render_rewards(column, capacity_only)
	if not capacity_only:
		_reward_summary = _label(_body, "", 15, TEAL)
		_reward_summary.name = "RewardSelectionSummary"
		_confirm_reward = _button(_body, "Confirmer cette carte  →", true)
		_confirm_reward.name = "ConfirmExpeditionReward"
		_confirm_reward.disabled = _selected_reward.is_empty() or inspection_only
		_confirm_reward.pressed.connect(_confirm_reward_selection)
		_update_reward_selection()


func _render_rewards(parent: Control, capacity_only := false) -> void:
	var session := GameManager.expedition
	var node := session.route.get_current_node()
	if capacity_only:
		_label(parent, "L'ampleur ou l'intensité", 30, TEXT, true)
		_label(parent, "Un choix exclusif : élargir votre kit ou transformer Frappe. La récompense de cette étape vient ensuite.", 18, MUTED)
		for choice in [["slot", "Un sixième emplacement", "Équipez une technique supplémentaire parmi celles que vous connaissez."], ["mutation", "Tempête du Péléide", session.build.catalog.get_spell("exp_tempest").description]]:
			var fork := _card(parent, GOLD)
			_label(fork, choice[1], 24, TEXT, true)
			_label(fork, choice[2], 17, MUTED)
			var button := _button(fork, "Choisir · " + choice[1], true)
			button.name = "Capacity_" + choice[0]
			button.disabled = inspection_only
			button.pressed.connect(func():
				var result: Dictionary = GameManager.choose_expedition_capacity(choice[0])
				if bool(result.get("success", false)): _page = FLOW.required_step(session)
				_action_result(result)
			)
		return
	if _selected_reward_node != session.route.current_node_id:
		_selected_reward_node = session.route.current_node_id
		_selected_reward = ""
	_reward_choices.clear()
	_reward_offers.clear()
	var offers: Array[Dictionary] = session.reward_options(GameManager.item_catalog)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 14)
	parent.add_child(margin)
	var center := CenterContainer.new()
	margin.add_child(center)
	var options := GridContainer.new()
	options.name = "ExpeditionRewardChoices"
	options.columns = mini(3, maxi(1, offers.size()))
	options.add_theme_constant_override("h_separation", 24)
	options.add_theme_constant_override("v_separation", 24)
	center.add_child(options)
	for index in offers.size():
		var offer := offers[index]
		var card := REWARD_CARD.new()
		card.name = "ExpeditionRewardCard_%d" % index
		options.add_child(card)
		card.configure(offer, index, GameManager.is_reduced_motion_enabled())
		card.set_card_extent(_reward_extent())
		card.set_locked(inspection_only)
		card.choice_requested.connect(_select_reward)
		_reward_choices[str(offer.id)] = card
		_reward_offers[str(offer.id)] = offer
	_update_reward_selection()


func _select_reward(reward_id: String) -> void:
	if inspection_only or not _reward_choices.has(reward_id):
		return
	_selected_reward = reward_id
	_update_reward_selection()


func _update_reward_selection() -> void:
	for id in _reward_choices:
		_reward_choices[id].set_selected(str(id) == _selected_reward)
	if is_instance_valid(_confirm_reward) and _confirm_reward.is_inside_tree():
		_confirm_reward.disabled = _selected_reward.is_empty() or inspection_only
	if is_instance_valid(_reward_summary) and _reward_summary.is_inside_tree():
		var offer: Dictionary = _reward_offers.get(_selected_reward, {})
		_reward_summary.text = "Aucune carte sélectionnée." if offer.is_empty() else "Votre choix : " + str(offer.title)
		if not offer.is_empty():
			_reward_summary.text += " · " + _reward_choices[_selected_reward].get_destination_summary()
			ART_THEME.reveal(_reward_summary)


func _confirm_reward_selection() -> void:
	if inspection_only or _selected_reward.is_empty():
		return
	_confirm_reward.disabled = true
	var chosen: Dictionary = _reward_offers.get(_selected_reward, {}).duplicate()
	var result: Dictionary = GameManager.claim_expedition_reward(_selected_reward)
	if bool(result.get("success", false)):
		_last_reward = chosen
		_selected_reward = ""
		if GameManager.expedition == null or not GameManager.run_active:
			return
		_page = "preparation"
		_render()
	else:
		_action_result(result)


func _render_preparation() -> void:
	var session := GameManager.expedition
	var column := _scroll_column(_body)
	_label(column, "Prêt pour la suite ?", 28, TEXT, true)
	_label(column, "Préparez votre héros à votre rythme. Vous pouvez conserver vos points de destin pour plus tard.", 17, MUTED)
	if not _last_reward.is_empty():
		var receipt := _label(column, "✓ " + str(_last_reward.get("title", "Récompense reçue")) + " · récompense reçue", 16, TEAL)
		receipt.name = "RewardReceipt"
	var options := GridContainer.new()
	options.columns = 3
	options.add_theme_constant_override("h_separation", 16)
	column.add_child(options)
	for entry in [["gear", "Inventaire", "equipment", "Quels objets porter ?", "Équipez vos trouvailles pour profiter de leurs effets.", "Ouvrir l'inventaire", "PrepareExpeditionEquipment"], ["build", "Compétences", "tree", "%d points de destin" % session.build.points, "Découvrez vos actions et apprenez de nouvelles techniques.", "Voir mes compétences", "ComposeCatabaseKit"], ["attributes", "Caractéristiques", "", "Niveau %d" % session.character.champion_progression.current_level, "Comprenez votre vie, vos dégâts et votre protection.", "Voir mes caractéristiques", "PrepareExpeditionAttributes"]]:
		var card := _card(options, TEAL if entry[0] == "gear" and _last_reward.has("item_id") else GOLD)
		_icon(card, ART_THEME.icon("resources", "level") if entry[0] == "attributes" else ART_THEME.icon("nav", entry[2]), 60)
		_label(card, entry[1], 22, TEXT, true)
		_label(card, entry[3], 16, GOLD)
		var hint := _label(card, entry[4], 17, MUTED)
		hint.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var button := _button(card, entry[5])
		button.name = entry[6]
		button.pressed.connect(func(): _open_inventory() if entry[0] == "gear" else _navigate(entry[0]))
	var journal := _button(column, "Carnet · revoir mes découvertes")
	journal.name = "OpenExpeditionJournal"
	journal.pressed.connect(func(): _navigate("journal"))
	var open_map := _button(_body, "Choisir mon prochain chemin  →", true)
	open_map.name = "OpenRouteMap"
	open_map.pressed.connect(func(): _navigate("map"))


func _render_build() -> void:
	var session := GameManager.expedition
	_label(_body, "Compétences", 28, TEXT, true)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	_body.add_child(tabs)
	for entry in [["equipped", "Mes actions en combat"], ["learn", "Apprendre · %d points de destin" % session.build.points]]:
		var tab := _button(tabs, entry[1])
		tab.name = "SkillsTab_" + entry[0]
		ART_THEME.apply_tab(tab, _skills_tab == entry[0])
		tab.pressed.connect(func(): _skills_tab = entry[0]; _show_loadout = false; _render())
	if _skills_tab == "equipped":
		_render_equipped_skills()
		return
	_render_learning_tree()


func _render_equipped_skills() -> void:
	_label(_body, "Les PA sont vos points d'action : chaque compétence en dépense. Les PM servent à vous déplacer.", 16, MUTED)
	var column := _scroll_column(_body)
	if _show_loadout:
		_render_loadout(column)
	else:
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 16)
		grid.add_theme_constant_override("v_separation", 14)
		column.add_child(grid)
		var index := 0
		for spell in GameManager.expedition.character.loadout.get_equipped_spells():
			var card := _card(grid, GOLD)
			card.name = "EquippedSkill_%d" % index
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 12)
			card.add_child(row)
			_icon(row, spell.icon, 56)
			var title := _label(row, spell.spell_name, 21, TEXT, true)
			title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_label(card, "%d PA · %s" % [spell.ap_cost, _skill_reach(spell)], 16, GOLD)
			# Keep targeting details authored in the description, but avoid repeating the cost.
			_label(card, spell.description.trim_prefix("%d PA · " % spell.ap_cost), 16, TEXT)
			if spell.cooldown_activations > 0:
				_label(card, "Recharge : %d tour(s) avant réutilisation." % spell.cooldown_activations, 14, MUTED)
			index += 1
	var edit := _button(_body, "Revenir à mes actions" if _show_loadout else "Modifier mes emplacements")
	edit.name = "ToggleCatabaseLoadout"
	edit.disabled = inspection_only or not GameManager.expedition.is_editable()
	edit.pressed.connect(func(): _show_loadout = not _show_loadout; _render())


func _skill_reach(spell: Spell) -> String:
	if spell.spell_range == 0:
		return "sur vous-même"
	if spell.minimum_range == spell.spell_range:
		return "portée %d %s" % [spell.spell_range, "case" if spell.spell_range == 1 else "cases"]
	return "portée %d–%d cases" % [spell.minimum_range, spell.spell_range]


func _render_learning_tree() -> void:
	var session := GameManager.expedition
	_label(_body, "Choisissez une voie, puis une technique. Les points de destin servent à apprendre ; vous pouvez les garder pour plus tard.", 16, MUTED)
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
	_label(tip, "COMMENT APPRENDRE ?", 13, GOLD)
	_label(tip, "Suivez les liens : une technique demande parfois un premier apprentissage. Vous pouvez mélanger les trois voies. Retrouvez vos techniques dans « Mes actions en combat ».", 16, MUTED)
	if not session.build.is_axis_discovered("elements") or not session.build.is_axis_discovered("serment"):
		_label(tip, "Certaines branches restent inconnues. Cherchez des sanctuaires et des mémoires sur la carte.", 16, TEAL)
	if not session.build.correction_used:
		var undo := _button(tip, "Annuler l’achat · 1 fois/run")
		undo.name = "UndoCatabaseTechnique"
		undo.tooltip_text = "Rembourse le dernier achat de l'arbre. Une seule correction pour toute la descente ; les cartes, caractéristiques et découvertes restent acquises."
		undo.disabled = inspection_only or not session.is_editable() or session.build.unlocked_node_ids.is_empty()
		undo.pressed.connect(func(): _action_result(GameManager.undo_expedition_technique()))


func _render_technique(parent: Control, offer: Dictionary, actions: Control) -> void:
	var session := GameManager.expedition
	var card := _card(parent, TEAL if bool(offer.owned) else GOLD)
	var cost := int(offer.cost)
	var point_label := "point" if cost == 1 else "points"
	var kind_label := str({"racine": "Entrée de voie", "apprentissage": "Nouvelle compétence", "liaison": "Bonus permanent", "mutation": "Évolution de compétence", "signature": "Technique signature", "légende": "Technique légendaire", "serment": "Serment"}.get(str(offer.kind), "Apprentissage"))
	_label(card, "%s · %d %s de destin" % [kind_label, cost, point_label], 13, GOLD)
	_illustrated_title(card, str(offer.title), CatabasePaintedIconCatalog.node_icon(offer) if bool(offer.get("discovered", true)) else ART_THEME.icon("nav", "lock"), 64)
	_label(card, str(offer.description), 17)
	var prereq: Array = offer.get("prerequisites", [])
	if not prereq.is_empty():
		var names := PackedStringArray()
		for id in prereq: names.append(str(session.build.catalog.get_node(str(id)).get("title", id)))
		_label(card, "Requiert : " + " + ".join(names), 14, MUTED)
	var buy := _button(actions, "Acquis" if bool(offer.owned) else "Apprendre · %d %s" % [cost, point_label], bool(offer.available))
	buy.name = "PurchaseTechnique"
	buy.disabled = inspection_only or not bool(offer.available)
	buy.tooltip_text = str(offer.get("reason", ""))
	buy.pressed.connect(func(): _action_result(GameManager.purchase_expedition_technique(str(offer.id))))
	if not bool(offer.available) and not bool(offer.owned):
		_label(card, str(offer.get("reason", "")), 14, MUTED)


func _is_hub() -> bool:
	return GameManager.expedition != null and GameManager.expedition.route.phase == "reward" \
		and ExpeditionRouteCatalog.is_halt(str(GameManager.expedition.route.get_current_node().get("kind", "")))


func _render_hub() -> void:
	if not _is_hub():
		var card := _card(_body, GOLD)
		_label(card, "La prochaine halte vous attend", 26, TEXT, true)
		_label(card, "La carte indique les refuges, marchands, sanctuaires et rencontres de mémoire visibles sur votre chemin.", 19)
		var map_button := _button(card, "Consulter le parchemin")
		map_button.pressed.connect(func(): _page = "map"; _render())
		return
	if GameManager.is_painted_halt_active():
		var column := _scroll_column(_body)
		var card := _card(column, GOLD)
		_label(card, str(GameManager.expedition.route.get_current_node().title), 26, TEXT, true)
		_label(card, "Explorez le lieu avec Achille. Les achats, faveurs et découvertes suivent votre expédition.", 18)
		var visit := _button(card, "Rejoindre la halte", true)
		visit.name = "EnterPaintedHalt"
		visit.disabled = inspection_only
		visit.pressed.connect(func(): GameManager.open_painted_halt())
		return
	if GameManager.is_merchant_hall_active():
		var column := _scroll_column(_body)
		var painting := TextureRect.new()
		painting.name = "MerchantHallPreview"
		painting.texture = load("res://asset/map/painted/merchant/hall_v1/hall.png")
		painting.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		painting.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		painting.custom_minimum_size.y = 220
		painting.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(painting)
		_render_merchant_hall_return(column, column)
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
			_status.show()
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


func _render_merchant_hall_return(parent: Control, actions: Control) -> void:
	var card := _card(parent, GOLD)
	_label(card, "LA HALTE EST OUVERTE", 13, GOLD)
	_label(card, "La Halle sous les racines", 25, TEXT, true)
	_label(card, "L'étal du passeur · étape IV", 16, TEAL)
	var hall_description := "Achille vous attend dans la Halle. Retrouvez les trois étals avant de reprendre la route."
	if str(GameManager.expedition.route.get_current_node().get("service_profile", "")).is_empty():
		hall_description = "Achille vous attend dans la Halle. Retrouvez les trois étals, le repos et les mémoires avant de reprendre la route."
	_label(card, hall_description, 17)
	var visit := _button(actions, "Revenir dans la Halle  →", true)
	visit.name = "EnterMerchantHall"
	visit.disabled = inspection_only
	visit.pressed.connect(func():
		if not GameManager.open_merchant_hall():
			_status.text = str(GameManager.get_expedition_save_status().get("message", "La Halle n'est plus accessible."))
			_status.add_theme_color_override("font_color", RED)
			_status.show()
	)
	if _page == "map":
		var workshop := _button(actions, "Choisir mes compétences")
		workshop.name = "ComposeCatabaseKit"
		workshop.pressed.connect(func(): _page = "build"; _render())


func _render_loadout(parent: Control) -> void:
	var session := GameManager.expedition
	var loadout := session.character.loadout
	var box := _card(parent, GOLD)
	_label(box, "MES ACTIONS ÉQUIPÉES  ·  %d EMPLACEMENTS" % loadout.get_active_slot_count(), 15, GOLD)
	_label(box, "Choisissez une technique connue pour chaque emplacement. Deux versions d’une même technique ne peuvent pas être équipées ensemble.", 17)
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
			if not success:
				_status.text = "Cette famille de technique occupe déjà un autre emplacement."
				_status.show()
		)
	if loadout.get_active_slot_count() < 5:
		_label(box, "Un cinquième emplacement se débloque au niveau 5.", 14, TEAL)
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
	var state := GameManager.expedition.character
	var column := _scroll_column(_body)
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
	_status.show()


func _close() -> void:
	if inspection_only:
		inspection_closed.emit()
		queue_free()
	else:
		if not GameManager.request_return_to_title():
			var status: Dictionary = GameManager.get_expedition_save_status()
			_status.text = str(status.get("message", "Sauvegarde impossible. Votre expédition reste ouverte."))
			_status.add_theme_color_override("font_color", RED)
			_status.show()


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
