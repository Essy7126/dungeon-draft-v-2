class_name CatabaseHubCanvas
extends Control
## A navigable place: each illuminated zone is a concrete service transaction.
signal zone_selected(service_id: String)

const ART := preload("res://ui/expedition/catabase_halt_art_catalog.gd")
const ART_THEME := preload("res://ui/expedition/catabase_ui_theme.gd")
var _services: Array[Dictionary] = []
var _buttons: Array[Button] = []
var _labels: Array[Button] = []
var _title := "Le refuge des ombres"
var _selected := ""
var _art_key := ""
var _art_texture: Texture2D = null
var _merchant := false
const GOLD := Color("d0b585")
const TEXT := Color("f0eadc")


func configure(title: String, services: Array[Dictionary], selected: String, destination: Dictionary = {}) -> void:
	_title = title
	_services = services.duplicate(true)
	_selected = selected
	var art_destination := destination.duplicate(true)
	if not art_destination.has("title"):
		art_destination["title"] = title
	_art_key = ART.resolve_key(art_destination)
	_art_texture = ART.load_texture(_art_key)
	_merchant = str(art_destination.get("kind", "")) == "merchant" \
		or (not _art_key.is_empty() and str(ART.DESTINATIONS[_art_key].kind) == "merchant")
	custom_minimum_size = Vector2(580, 420)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	# configure is also used during refresh: stale controls must not retain old services.
	for button in _buttons:
		button.free()
	_buttons.clear()
	for label in _labels:
		label.free()
	_labels.clear()
	var buy_index := 0
	for service in _services:
		var button := Button.new()
		var service_id := str(service.id)
		button.name = "HubZone_" + service_id.replace(":", "_")
		button.set_meta("service_id", service_id)
		button.set_meta("art_anchor", ART.service_anchor(service_id, _merchant, buy_index, _art_key))
		button.tooltip_text = str(service.title) + "\n" + str(service.description)
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_select_service.bind(service_id))
		var target_style := StyleBoxEmpty.new()
		for state in ["normal", "hover", "pressed", "focus"]:
			button.add_theme_stylebox_override(state, target_style)
		add_child(button)
		_buttons.append(button)
		var label := Button.new()
		label.name = "HubLabel_" + service_id.replace(":", "_")
		label.set_meta("service_id", service_id)
		label.set_meta("art_anchor", ART.label_anchor(service_id, _merchant, buy_index, _art_key))
		var cost := int(service.get("cost", 0))
		var role := ART.service_role(service_id)
		var caption := str({"rest": "Se reposer", "lore": "Écouter les noms", "branch": "Découverte", "wager": "Tribut du sang"}.get(role, service.title))
		label.text = caption + "\n" + ("Accompli" if bool(service.get("used", false)) else ("%d oboles" % cost if cost > 0 else "Découvrir"))
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", TEXT)
		label.tooltip_text = button.tooltip_text
		label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		label.pressed.connect(_select_service.bind(service_id))
		var style := ART_THEME.style("button", "selected" if str(service.id) == _selected else "normal")
		style.content_margin_left = 6
		style.content_margin_right = 6
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		label.add_theme_stylebox_override("normal", style)
		for state in ["hover", "pressed", "focus"]:
			var active_style := ART_THEME.style("button", state)
			active_style.content_margin_left = 6
			active_style.content_margin_right = 6
			active_style.content_margin_top = 4
			active_style.content_margin_bottom = 4
			label.add_theme_stylebox_override(state, active_style)
		add_child(label)
		ART_THEME.bind_button_motion(label)
		_labels.append(label)
		if role == "buy":
			buy_index += 1
	if not resized.is_connected(_layout):
		resized.connect(_layout)
	_layout()


func get_art_key() -> String:
	return _art_key


func get_art_status() -> String:
	return "ready" if _art_texture != null else ("pending" if not _art_key.is_empty() else "unmapped")


func get_art_rect() -> Rect2:
	return ART.fitted_rect(size)


func _select_service(service_id: String) -> void:
	zone_selected.emit(service_id)


func _layout() -> void:
	var art_rect := get_art_rect()
	# Targets stay on the painted objects; labels occupy measured clear ground below.
	var button_width := minf(188.0, art_rect.size.x * (0.235 if _merchant else 0.26))
	for button in _buttons:
		var anchor: Vector2 = button.get_meta("art_anchor")
		button.size = Vector2(30, 30)
		button.position = art_rect.position + art_rect.size * anchor - button.size * 0.5
	for label in _labels:
		var anchor: Vector2 = label.get_meta("art_anchor")
		label.size = Vector2(button_width, 42)
		label.position = art_rect.position + art_rect.size * anchor - label.size * 0.5
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("111b1a"))
	if _art_texture != null:
		draw_texture_rect(_art_texture, get_art_rect(), false)
		_draw_service_targets()
		return
	_draw_fallback()
	_draw_service_targets()


func _draw_service_targets() -> void:
	for index in _buttons.size():
		var button := _buttons[index]
		var point := button.position + button.size * 0.5
		var label := _labels[index]
		var label_edge := Vector2(label.position.x + label.size.x * 0.5, label.position.y)
		var selected := str(button.get_meta("service_id")) == _selected
		var color := GOLD if selected else Color("d4d0b9")
		draw_line(point + point.direction_to(label_edge) * 9.0, label_edge, Color(color, 0.65), 1.0, true)
		draw_circle(point, 9.0, Color(0.03, 0.06, 0.05, 0.60))
		draw_arc(point, 9.0, 0, TAU, 32, color, 2.0 if selected else 1.0, true)
		draw_circle(point, 2.5 if selected else 1.5, color)


func _draw_fallback() -> void:
	# A courtyard of stone, tents, a votive altar and a brazier, using our sober palette.
	var ground := PackedVector2Array([Vector2(8, size.y * .67), Vector2(size.x * .5, size.y * .14), Vector2(size.x - 8, size.y * .67), Vector2(size.x * .5, size.y + 40)])
	draw_colored_polygon(ground, Color("26322c"))
	for row in 9:
		var y := size.y * .38 + row * 26
		draw_line(Vector2(size.x * .08, y), Vector2(size.x * .92, y), Color(0.43, .47, .38, .12), 1)
	for column in 12:
		var x := 20 + column * (size.x - 40) / 12
		draw_line(Vector2(size.x * .5 + (x - size.x * .5) * .25, size.y * .25), Vector2(x, size.y), Color(.43, .47, .38, .12), 1)
	var tent := Vector2(size.x * .22, size.y * .20)
	draw_colored_polygon(PackedVector2Array([tent + Vector2(-65, 25), tent + Vector2(0, -36), tent + Vector2(66, 25)]), Color("6a6850"))
	draw_polyline(PackedVector2Array([tent + Vector2(-65, 25), tent + Vector2(0, -36), tent + Vector2(66, 25)]), GOLD, 2, true)
	draw_line(tent + Vector2(0, -36), tent + Vector2(0, 26), Color("28352b"), 5, true)
	var altar := Vector2(size.x * .77, size.y * .20)
	draw_rect(Rect2(altar + Vector2(-46, 5), Vector2(92, 17)), Color("7a7964"))
	for x in [-31, 31]:
		draw_rect(Rect2(altar + Vector2(x - 6, -39), Vector2(12, 44)), Color("96947d"))
	draw_colored_polygon(PackedVector2Array([altar + Vector2(-52, -39), altar + Vector2(0, -59), altar + Vector2(52, -39)]), Color("777969"))
	var fire := Vector2(size.x * .5, size.y * .51)
	for radius in [42, 29, 17]:
		draw_circle(fire, radius, Color(.81, .48, .20, .04 + float(45 - radius) * .003))
	draw_colored_polygon(PackedVector2Array([fire + Vector2(-11, 12), fire + Vector2(-6, -15), fire + Vector2(0, -4), fire + Vector2(9, -25), fire + Vector2(13, 12)]), Color("c18b48"))
	draw_line(fire + Vector2(-18, 17), fire + Vector2(18, 17), Color("847a60"), 5, true)
	draw_string(ThemeDB.fallback_font, Vector2(22, 29), "UNE HALTE SUR LE CHEMIN", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, GOLD)
	draw_string(ThemeDB.fallback_font, Vector2(22, 49), "Choisissez une zone pour rencontrer, commercer ou vous recueillir.", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, TEXT)
