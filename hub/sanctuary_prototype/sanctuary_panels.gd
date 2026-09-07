class_name SanctuaryPanels
extends Control

## Interactions du sanctuaire, sur un état local fourni par la scène appelante.
signal closed
signal session_changed

const PREMIUM_UI := preload("res://ui/theme/premium_ui.gd")
const SESSION := preload("res://hub/sanctuary_prototype/sanctuary_session.gd")
const BODY_FONT := preload("res://asset/ui/recraft_hud_v1/fonts/atkinson_hyperlegible/AtkinsonHyperlegible-Regular.otf")
const BOLD_FONT := preload("res://asset/ui/recraft_hud_v1/fonts/atkinson_hyperlegible/AtkinsonHyperlegible-Bold.otf")
const TITLE_FONT := preload("res://asset/ui/recraft_hud_v1/fonts/cinzel/Cinzel-Variable.ttf")
const INK := Color("efe5d2")
const MUTED := Color("bdb09b")
const BRONZE := Color("c39458")
const DARK := Color("211f1bea")
const CARD := Color("302b23")
const SUCCESS := Color("b5d4a7")

var _session: SESSION
var _mode: StringName = &""
var _draft_blessing: StringName = &""
var _panel: PanelContainer
var _title: Label
var _intro: Label
var _balance: Label
var _content: VBoxContainer
var _feedback: Label
var _confirmation: VBoxContainer
var _close_button: Button
var _previous_focus: Control
var _feedback_text := ""
var _feedback_success := true


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = PREMIUM_UI.get_theme()
	add_theme_font_override("font", BODY_FONT)
	_build_interface()
	resized.connect(_resize_panel)
	_resize_panel()
	hide()
	if _mode != &"":
		_show_panel(_mode)


func setup(session: SESSION) -> void:
	_session = session
	_draft_blessing = &""
	_feedback_text = ""
	if is_node_ready() and is_open():
		_refresh()


func open_shop() -> void:
	_show_panel(&"shop")


func open_oracle() -> void:
	_draft_blessing = &""
	_show_panel(&"oracle")


func open_inventory() -> void:
	_show_panel(&"inventory")


func open_departure() -> void:
	_show_panel(&"departure")


func close_panel() -> void:
	if _mode == &"":
		return
	_mode = &""
	hide()
	if is_instance_valid(_previous_focus) and _previous_focus.is_visible_in_tree():
		_previous_focus.grab_focus()
	_previous_focus = null
	closed.emit()


func is_open() -> bool:
	return _mode != &""


func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close_panel()


func _build_interface() -> void:
	var shade := ColorRect.new()
	shade.name = "ModalBackdrop"
	shade.color = Color(0.05, 0.055, 0.05, 0.36)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	_panel = PanelContainer.new()
	_panel.name = "SanctuaryPanel"
	_panel.minimum_size_changed.connect(_resize_panel.call_deferred)
	_panel.add_theme_stylebox_override("panel", _style(DARK, BRONZE, 2))
	add_child(_panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	_panel.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 13)
	margin.add_child(layout)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	layout.add_child(top)
	var eyebrow := _label("LE SANCTUAIRE", 13, BRONZE)
	eyebrow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	eyebrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(eyebrow)
	_close_button = _button("Fermer  ×")
	_close_button.name = "ClosePanel"
	_close_button.custom_minimum_size = Vector2(110, 38)
	_close_button.tooltip_text = "Fermer le panneau (Échap)"
	_close_button.pressed.connect(close_panel)
	top.add_child(_close_button)

	_title = _label("", 27, INK)
	_title.add_theme_font_override("font", TITLE_FONT)
	layout.add_child(_title)
	_intro = _label("", 17, MUTED)
	layout.add_child(_intro)
	var rule := HSeparator.new()
	layout.add_child(rule)
	_balance = _label("", 19, BRONZE)
	_balance.name = "DrachmesBalance"
	_balance.add_theme_font_override("font", BOLD_FONT)
	layout.add_child(_balance)

	var scroll := ScrollContainer.new()
	scroll.name = "ContentScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	layout.add_child(scroll)
	_content = VBoxContainer.new()
	_content.name = "PanelContent"
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 12)
	scroll.add_child(_content)

	_confirmation = VBoxContainer.new()
	_confirmation.add_theme_constant_override("separation", 8)
	layout.add_child(_confirmation)
	_feedback = _label("", 17, SUCCESS)
	_feedback.name = "ActionFeedback"
	_feedback.custom_minimum_size.y = 44
	layout.add_child(_feedback)
	layout.add_child(_label("Échap pour revenir au sanctuaire", 14, MUTED))


func _resize_panel() -> void:
	if _panel == null:
		return
	var inset := 20.0 if size.x >= 700.0 else 12.0
	var panel_width: float = minf(clampf(size.x * 0.36, 430.0, 520.0), maxf(0.0, size.x - inset * 2.0))
	_panel.position = Vector2(size.x - panel_width - inset, inset)
	_panel.size = Vector2(panel_width, maxf(0.0, size.y - inset * 2.0))


func _show_panel(mode: StringName) -> void:
	if _session == null:
		push_warning("SanctuaryPanels.setup(session) doit précéder l'ouverture d'un panneau.")
		return
	var was_open := is_open()
	_mode = mode
	_feedback_text = ""
	if not is_node_ready():
		return
	if not was_open:
		_previous_focus = get_viewport().gui_get_focus_owner()
	_refresh()
	show()
	_resize_panel()
	_close_button.grab_focus()


func _refresh() -> void:
	_clear(_content)
	_clear(_confirmation)
	_balance.text = "%d drachmes" % _session.get_drachmes()
	_feedback.text = _feedback_text
	_feedback.add_theme_color_override("font_color", SUCCESS if _feedback_success else Color("e4ac91"))
	match _mode:
		&"shop":
			_build_shop()
		&"oracle":
			_build_oracle()
		&"inventory":
			_build_inventory()
		&"departure":
			_build_departure()


func _build_shop() -> void:
	_title.text = "Le comptoir des voyageurs"
	_intro.text = "Quelques biens précieux attendent Achille. Chaque achat rejoint sa besace."
	for item: Dictionary in _session.get_shop_items():
		var card := _card()
		_content.add_child(card.panel)
		var body: VBoxContainer = card.body
		body.add_child(_label(String(item.name), 21, INK, true))
		body.add_child(_label(String(item.description), 17, MUTED))
		body.add_child(_label("%d drachmes  ·  Stock : %d" % [int(item.price), int(item.stock)], 17, BRONZE))
		var reason := ""
		if int(item.stock) <= 0:
			reason = "Épuisé — le marchand n'en a plus."
		elif int(item.price) > _session.get_drachmes():
			reason = "Il manque %d drachmes pour cet achat." % (int(item.price) - _session.get_drachmes())
		var buy := _button("Acheter · %d drachmes" % int(item.price))
		buy.name = "Buy_" + String(item.id)
		buy.disabled = not reason.is_empty()
		buy.tooltip_text = reason
		buy.pressed.connect(_buy.bind(StringName(item.id)))
		body.add_child(buy)
		if not reason.is_empty():
			body.add_child(_label(reason, 16, MUTED))


func _buy(item_id: StringName) -> void:
	var result: Dictionary = _session.buy_item(item_id)
	_feedback_text = String(result.message)
	_feedback_success = bool(result.ok)
	_refresh()
	if bool(result.ok):
		session_changed.emit()
	var next_button := _content.find_child("Buy_" + String(item_id), true, false) as Button
	if next_button != null and not next_button.disabled:
		next_button.grab_focus()
	else:
		_close_button.grab_focus()


func _build_oracle() -> void:
	_title.text = "La parole de l'oracle"
	_intro.text = "Trois divinités tendent la main à Achille. Une seule bénédiction peut l'accompagner."
	var chosen: Dictionary = _session.get_selected_blessing()
	var chosen_id := StringName(chosen.get("id", &""))
	if not chosen.is_empty():
		_content.add_child(_label("Bénédiction reçue : %s" % String(chosen.name), 18, SUCCESS, true))
	for blessing: Dictionary in _session.get_blessings():
		var id := StringName(blessing.id)
		var selected := id == chosen_id or (chosen.is_empty() and id == _draft_blessing)
		var card := _card(selected)
		_content.add_child(card.panel)
		var body: VBoxContainer = card.body
		body.add_child(_label(String(blessing.name), 21, INK, true))
		body.add_child(_label(String(blessing.description), 17, MUTED))
		body.add_child(_label(String(blessing.effect), 17, INK))
		var caption := "Sélectionner"
		if id == chosen_id:
			caption = "Bénédiction reçue"
		elif not chosen.is_empty():
			caption = "Un choix a déjà été scellé"
		elif selected:
			caption = "Sélectionnée · à confirmer"
		var select := _button(caption)
		select.name = "Select_" + String(id)
		select.toggle_mode = true
		select.button_pressed = selected
		select.disabled = not chosen.is_empty()
		select.pressed.connect(_select_blessing.bind(id))
		body.add_child(select)
	if chosen.is_empty():
		_confirmation.add_child(_label("Ce choix est définitif pendant cette visite.", 16, MUTED))
		var confirm := _button("Confirmer la bénédiction")
		confirm.name = "ConfirmBlessing"
		confirm.disabled = _draft_blessing == &""
		confirm.pressed.connect(_confirm_blessing)
		_confirmation.add_child(confirm)
	else:
		_confirmation.add_child(_label("Le choix d'Achille est scellé.", 17, BRONZE))


func _select_blessing(id: StringName) -> void:
	if not _session.get_selected_blessing().is_empty():
		return
	_draft_blessing = id
	_feedback_text = ""
	_refresh()
	var confirm := _confirmation.find_child("ConfirmBlessing", true, false) as Button
	if confirm != null:
		confirm.grab_focus()


func _confirm_blessing() -> void:
	if _draft_blessing == &"":
		return
	var result: Dictionary = _session.choose_blessing(_draft_blessing)
	_feedback_text = String(result.message)
	_feedback_success = bool(result.ok)
	_refresh()
	_close_button.grab_focus()
	if bool(result.ok):
		session_changed.emit()


func _build_inventory() -> void:
	_title.text = "La besace d'Achille"
	_intro.text = "Les biens acquis et la faveur reçue au fil de cette visite."
	var inventory: Dictionary = _session.get_inventory()
	_content.add_child(_label("BIENS EMPORTÉS", 14, BRONZE, true))
	if inventory.is_empty():
		_content.add_child(_label("La besace est encore vide. Le marchand peut préparer quelques provisions.", 18, MUTED))
	for item: Dictionary in _session.get_shop_items():
		var quantity := int(inventory.get(item.id, 0))
		if quantity == 0:
			continue
		var card := _card()
		_content.add_child(card.panel)
		var body: VBoxContainer = card.body
		body.add_child(_label("%s  × %d" % [String(item.name), quantity], 21, INK, true))
		body.add_child(_label(String(item.description), 17, MUTED))
	_content.add_child(_label("FAVEUR DIVINE", 14, BRONZE, true))
	var chosen: Dictionary = _session.get_selected_blessing()
	if chosen.is_empty():
		_content.add_child(_label("Aucune bénédiction reçue. L'oracle attend le choix d'Achille.", 18, MUTED))
	else:
		var card := _card(true)
		_content.add_child(card.panel)
		var body: VBoxContainer = card.body
		body.add_child(_label(String(chosen.name), 21, INK, true))
		body.add_child(_label(String(chosen.description), 17, MUTED))
		body.add_child(_label(String(chosen.effect), 17, INK))


func _build_departure() -> void:
	_build_inventory()
	_title.text = "Derniers préparatifs"
	_intro.text = "Avant le départ, retrouvez les provisions et la faveur qui accompagnent Achille."
	_confirmation.add_child(_label("La traversée n'est pas encore ouverte. Vous pouvez poursuivre vos préparatifs.", 17, MUTED))
	var return_button := _button("Revenir au sanctuaire")
	return_button.name = "ReturnToSanctuary"
	return_button.pressed.connect(close_panel)
	_confirmation.add_child(return_button)

func _label(value: String, font_size: int, color: Color, bold := false) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_override("font", BOLD_FONT if bold else BODY_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button(caption: String) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size.y = 44
	button.add_theme_font_override("font", BOLD_FONT)
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", Color("fff5df"))
	button.add_theme_color_override("font_pressed_color", Color("fff5df"))
	button.add_theme_color_override("font_disabled_color", Color("aaa08e"))
	button.add_theme_stylebox_override("normal", _style(Color("40362a"), Color("796246")))
	button.add_theme_stylebox_override("hover", _style(Color("594731"), BRONZE))
	button.add_theme_stylebox_override("pressed", _style(Color("614a2e"), BRONZE, 2))
	button.add_theme_stylebox_override("disabled", _style(Color("2b2924"), Color("514a3f")))
	button.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), Color("eed1a1"), 2))
	return button


func _card(selected := false) -> Dictionary:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _style(CARD, BRONZE if selected else Color("574937"), 2 if selected else 1))
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 15)
	panel.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	margin.add_child(body)
	return {"panel": panel, "body": body}


func _style(fill: Color, border: Color, border_width := 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(7)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _clear(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()
