class_name SanctuaryPanels
extends Control

## Présentation des services et de l'inventaire réels fournis par Catabase.
signal closed
signal session_changed

const PREMIUM_UI := preload("res://ui/theme/premium_ui.gd")
const SESSION := preload("res://hub/sanctuary_prototype/sanctuary_session.gd")
const BODY_FONT := preload("res://asset/ui/recraft_hud_v1/fonts/atkinson_hyperlegible/AtkinsonHyperlegible-Regular.otf")
const BOLD_FONT := preload("res://asset/ui/recraft_hud_v1/fonts/atkinson_hyperlegible/AtkinsonHyperlegible-Bold.otf")
const TITLE_FONT := preload("res://asset/ui/recraft_hud_v1/fonts/cinzel/Cinzel-Variable.ttf")
const INK := Color("efe5d2")
const MUTED := Color("bdb09b")
const BRONZE := Color("8b714c")
const DARK := Color("211c18fa")
const CARD := Color("211c18")
const SUCCESS := Color("b5d4a7")

var _session: SESSION
var _mode: StringName = &""
var _draft_service := ""
var _context: Dictionary = {}
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
	_draft_service = ""
	_feedback_text = ""
	if is_node_ready() and is_open():
		_refresh()


func open_shop() -> void:
	_show_panel(&"shop")


func open_oracle() -> void:
	_draft_service = ""
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
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		var controls := _focusable_buttons()
		if controls.is_empty():
			return
		var index := controls.find(get_viewport().gui_get_focus_owner())
		controls[posmod(index + (-1 if event.shift_pressed else 1), controls.size())].grab_focus()
		get_viewport().set_input_as_handled()


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
	_balance.name = "SanctuaryBalance"
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
	_confirmation.name = "FixedActions"
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
	(_panel.find_child("ContentScroll", true, false) as ScrollContainer).set_deferred("scroll_vertical", 0)
	_close_button.grab_focus()


func _refresh() -> void:
	_clear(_content)
	_clear(_confirmation)
	_context = _session.get_context()
	_balance.text = "%d %s" % [int(_context.get("balance", 0)), str(_context.get("currency_label", "oboles"))] if str(_context.get("mode", "")) == "halt" else "Les préparatifs suivent votre aventure"
	_balance.name = "SanctuaryBalance"
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
	_wire_modal_focus.call_deferred()


func _focusable_buttons() -> Array[Button]:
	var controls: Array[Button] = []
	for node in _panel.find_children("*", "Button", true, false):
		if node.is_visible_in_tree() and not node.disabled:
			controls.append(node)
	return controls


func _wire_modal_focus() -> void:
	var controls := _focusable_buttons()
	for index in controls.size():
		var current := controls[index]
		var next := controls[(index + 1) % controls.size()]
		var previous := controls[posmod(index - 1, controls.size())]
		current.focus_next = current.get_path_to(next)
		current.focus_previous = current.get_path_to(previous)
		current.focus_neighbor_bottom = current.focus_next
		current.focus_neighbor_top = current.focus_previous


func _build_shop() -> void:
	_title.text = "Le comptoir des voyageurs"
	_intro.text = "Équipements de cette halte. Les achats rejoignent votre inventaire de Catabase."
	var services := _services(true)
	if services.is_empty():
		_empty_preparations("Les offres du marchand seront disponibles pendant une halte. Les oboles et les objets suivent votre expédition.")
		return
	for item: Dictionary in services:
		var card := _card()
		_content.add_child(card.panel)
		var body: VBoxContainer = card.body
		_service_description(body, item)
		var caption := "Déjà acheté" if bool(item.get("used", false)) else "Acheter · %d oboles" % int(item.get("cost", 0))
		var buy := _button(caption)
		buy.name = "Buy_" + str(item.id).replace(":", "_")
		buy.disabled = not bool(item.get("available", false))
		buy.tooltip_text = _unavailable_reason(item)
		buy.pressed.connect(_use_service.bind(str(item.id)))
		body.add_child(buy)
		if buy.disabled:
			body.add_child(_label(buy.tooltip_text, 15, MUTED))


func _build_oracle() -> void:
	_title.text = "Auprès de l'oracle"
	_intro.text = "Écoutez les mémoires du lieu, découvrez une voie ou retrouvez vos forces."
	var services := _services(false)
	if services.is_empty():
		_empty_preparations("Les conseils et les soins dépendent de la halte rencontrée. Aucune faveur ne modifie Achille avant son premier combat.")
		return
	var selected: Dictionary = {}
	for service: Dictionary in services:
		var id := str(service.id)
		var card := _card(id == _draft_service)
		_content.add_child(card.panel)
		var body: VBoxContainer = card.body
		_service_description(body, service)
		var used := bool(service.get("used", false))
		var select := _button("Accompli" if used else ("Sélectionné" if id == _draft_service else "Choisir"))
		select.name = "Select_" + id.replace(":", "_")
		select.toggle_mode = true
		select.button_pressed = id == _draft_service
		select.disabled = not bool(service.get("available", false))
		select.tooltip_text = _unavailable_reason(service)
		select.pressed.connect(_select_service.bind(id))
		body.add_child(select)
		if id == _draft_service and not select.disabled:
			selected = service
		elif select.disabled:
			body.add_child(_label(select.tooltip_text, 15, MUTED))
	var confirm := _button("Confirmer le choix" if selected.is_empty() else "Confirmer · %s" % str(selected.title))
	confirm.name = "ConfirmService"
	confirm.disabled = selected.is_empty()
	confirm.pressed.connect(_confirm_service)
	_confirmation.add_child(confirm)


func _select_service(id: String) -> void:
	_draft_service = id
	_refresh()
	var confirm := _confirmation.find_child("ConfirmService", true, false) as Button
	if confirm != null and not confirm.disabled:
		confirm.grab_focus()


func _confirm_service() -> void:
	if not _draft_service.is_empty():
		_use_service(_draft_service)


func _use_service(id: String) -> void:
	var result := _session.use_service(id)
	_feedback_text = str(result.get("message", result.get("error", result.get("reason", "Action indisponible."))))
	var applied := bool(result.get("success", false))
	_feedback_success = applied and bool(result.get("saved", true))
	if applied:
		_draft_service = ""
	_refresh()
	session_changed.emit()
	_close_button.grab_focus()


func _services(merchant: bool) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for service: Dictionary in _context.get("services", []):
		if (str(service.get("kind", "")) == "merchant") == merchant:
			result.append(service)
	return result


func _service_description(body: VBoxContainer, service: Dictionary) -> void:
	body.add_child(_label(str(service.get("title", "Service")), 21, INK, true))
	body.add_child(_label(str(service.get("description", "")), 17, MUTED))
	var cost := int(service.get("cost", 0))
	body.add_child(_label("%d oboles" % cost if cost > 0 else "Sans coût en oboles", 16, BRONZE))


func _unavailable_reason(service: Dictionary) -> String:
	if bool(service.get("used", false)):
		return "Ce service a déjà été utilisé dans cette halte."
	var cost := int(service.get("cost", 0))
	var balance := int(_context.get("balance", 0))
	if balance < cost:
		return "Il manque %d oboles." % (cost - balance)
	return str(service.get("unavailable_reason", "Ce service n'est pas disponible actuellement."))


func _empty_preparations(message: String) -> void:
	var card := _card()
	_content.add_child(card.panel)
	card.body.add_child(_label(message, 18, INK))
	var departure := _button(str(_context.get("departure_label", "Rejoindre le passage")))
	departure.name = "OpenDeparture"
	departure.pressed.connect(open_departure)
	_confirmation.add_child(departure)


func _build_inventory() -> void:
	_title.text = "La besace d'Achille"
	_intro.text = "Vos objets de Catabase vous accompagnent d'une rencontre à l'autre."
	var inventory: Array = _context.get("inventory", [])
	if inventory.is_empty():
		var message := "Votre inventaire est vide." if str(_context.get("mode", "")) == "halt" else "Vous retrouverez ici les objets de votre expédition pendant une halte."
		_content.add_child(_label(message, 18, MUTED))
	for entry: Dictionary in inventory:
		var card := _card()
		_content.add_child(card.panel)
		var body: VBoxContainer = card.body
		var icon_path := str(entry.get("icon_path", ""))
		if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
			var texture := load(icon_path) as Texture2D
			if texture != null:
				var icon := TextureRect.new()
				icon.name = "ItemIcon_" + str(entry.get("item_id", "item"))
				icon.texture = texture
				icon.custom_minimum_size = Vector2(52, 52)
				icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
				body.add_child(icon)
		body.add_child(_label("%s  × %d" % [str(entry.get("name", entry.get("item_id", "Objet"))), int(entry.get("quantity", 1))], 20, INK, true))
		var description := str(entry.get("description", ""))
		if not description.is_empty():
			body.add_child(_label(description, 16, MUTED))


func _build_departure() -> void:
	_build_inventory()
	_title.text = "Le passage"
	_intro.text = str(_context.get("departure_description", "Choisissez la suite de votre aventure."))
	var depart := _button(str(_context.get("departure_label", "Continuer")))
	depart.name = "ContinueJourney"
	depart.disabled = not bool(_context.get("departure_enabled", false))
	depart.pressed.connect(func() -> void:
		depart.disabled = true
		_continue_journey.call_deferred()
	)
	_confirmation.add_child(depart)
	var stay := _button("Poursuivre la visite")
	stay.name = "ReturnToSanctuary"
	stay.pressed.connect(close_panel)
	_confirmation.add_child(stay)


func _continue_journey() -> void:
	var result := _session.continue_journey()
	if not bool(result.get("success", false)):
		_feedback_text = str(result.get("message", "Le départ n'a pas pu être confirmé."))
		_feedback_success = false
		_refresh()


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
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_override("font", BOLD_FONT)
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", Color("fff5df"))
	button.add_theme_color_override("font_pressed_color", Color("fff5df"))
	button.add_theme_color_override("font_disabled_color", Color("aaa08e"))
	button.theme = PREMIUM_UI.get_theme()
	return button


func _card(selected := false) -> Dictionary:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _style(Color("102d34") if selected else CARD, Color("8fb9bf") if selected else BRONZE, 1))
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
