class_name ExpeditionTreeCanvas
extends Control
## Edges are the same prerequisites checked by the build state.
signal technique_selected(node_id: String)

const INK := Color("17221f")
const GOLD := Color("d0b585")
const TEAL := Color("84c7ad")
const TEXT := Color("f0eadc")
const ART_THEME := preload("res://ui/expedition/catabase_ui_theme.gd")
const CARD_HEIGHT := 112.0
const COLUMN_GAP := 20.0
const ROW_PITCH := CARD_HEIGHT + 34.0
var _offers: Array[Dictionary] = []
var _buttons: Dictionary = {}
var _rects: Dictionary = {}
var _ranks: Dictionary = {}
var _selected := ""


func configure(offers: Array[Dictionary], selected: String) -> void:
	for button in _buttons.values():
		remove_child(button)
		button.queue_free()
	_buttons.clear()
	_rects.clear()
	_ranks.clear()
	_offers = offers
	_selected = selected
	custom_minimum_size = Vector2(580, 600)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for offer in _offers:
		var button := Button.new()
		button.name = "Technique_" + str(offer.id).replace(".", "_")
		button.icon = CatabasePaintedIconCatalog.node_icon(offer) if bool(offer.get("discovered", true)) else null
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 52)
		button.add_theme_constant_override("h_separation", 12)
		var status := "Acquis" if bool(offer.owned) else "%d point%s" % [int(offer.cost), "s" if int(offer.cost) > 1 else ""]
		if not bool(offer.get("discovered", true)):
			status = "À découvrir"
		button.text = str(offer.title) + "\n" + status
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 15)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.tooltip_text = str(offer.description) + "\n" + str(offer.get("reason", ""))
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(_on_technique_pressed.bind(str(offer.id)))
		add_child(button)
		ART_THEME.bind_button_motion(button)
		_buttons[str(offer.id)] = button
	if not resized.is_connected(_layout):
		resized.connect(_layout)
	_layout()


func _on_technique_pressed(node_id: String) -> void:
	_selected = node_id
	for offer in _offers:
		var button: Button = _buttons[str(offer.id)]
		_style_button(button, offer)
	technique_selected.emit(node_id)


func _rank(id: String, trail: Array[String] = []) -> int:
	if _ranks.has(id):
		return int(_ranks[id])
	if trail.has(id):
		return 0
	trail = trail.duplicate()
	trail.append(id)
	var result := 0
	for offer in _offers:
		if str(offer.id) != id:
			continue
		for prerequisite in offer.get("prerequisites", []):
			if _buttons.has(str(prerequisite)):
				result = maxi(result, _rank(str(prerequisite), trail) + 1)
	_ranks[id] = result
	return result


func _layout() -> void:
	_rects.clear()
	_ranks.clear()
	var layers: Dictionary = {}
	for offer in _offers:
		var rank := _rank(str(offer.id))
		if not layers.has(rank): layers[rank] = []
		layers[rank].append(offer)
	var width := maxf(size.x, 580)
	var height := 0.0
	var ordered_ranks := layers.keys()
	ordered_ranks.sort()
	var row_top := 32.0
	var max_columns := clampi(floori((width - 32.0 + COLUMN_GAP) / (218.0 + COLUMN_GAP)), 1, 3)
	for rank in ordered_ranks:
		var layer: Array = layers[rank]
		var columns := mini(layer.size(), max_columns)
		var card_width := minf(276.0, (width - 32.0 - (columns - 1) * COLUMN_GAP) / columns)
		for index in layer.size():
			var row := floori(float(index) / float(columns))
			var column := index % columns
			var used := mini(columns, layer.size() - row * columns)
			var start := (width - (used * card_width + (used - 1) * COLUMN_GAP)) * 0.5
			var rect := Rect2(start + column * (card_width + COLUMN_GAP), row_top + row * ROW_PITCH, card_width, CARD_HEIGHT)
			var offer: Dictionary = layer[index]
			_rects[str(offer.id)] = rect
			var button: Button = _buttons[str(offer.id)]
			button.position = rect.position
			button.size = rect.size
			_style_button(button, offer)
			height = maxf(height, rect.end.y + 30)
		row_top += ceilf(float(layer.size()) / float(columns)) * ROW_PITCH + 22.0
	custom_minimum_size.y = maxf(400, height)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("101a20"))
	var fresco: Texture2D = ART_THEME.texture("tree_fresco")
	if fresco != null:
		# Crop uniformly; the painting never positions or joins gameplay nodes.
		var scale_factor := maxf(size.x / fresco.get_width(), size.y / fresco.get_height())
		var source_size := size / scale_factor
		var source_rect := Rect2((fresco.get_size() - source_size) * 0.5, source_size)
		draw_texture_rect_region(fresco, Rect2(Vector2.ZERO, size), source_rect, Color(1, 1, 1, 0.36))
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.07, 0.09, 0.30))
	for offer in _offers:
		var target_id := str(offer.id)
		if not _rects.has(target_id): continue
		for source_id in offer.get("prerequisites", []):
			if not _rects.has(str(source_id)): continue
			var from_rect: Rect2 = _rects[str(source_id)]
			var to_rect: Rect2 = _rects[target_id]
			var start := Vector2(from_rect.get_center().x, from_rect.end.y)
			var finish := Vector2(to_rect.get_center().x, to_rect.position.y)
			var points := PackedVector2Array()
			if finish.y - start.y > ROW_PITCH:
				# Later rows route through the column gutter, never through a node.
				var gutter := to_rect.position.x - 7.0
				points = PackedVector2Array([start, Vector2(start.x, start.y + 16), Vector2(gutter, start.y + 16), Vector2(gutter, finish.y - 12), Vector2(finish.x, finish.y - 12), finish])
			else:
				var mid := (start.y + finish.y) * 0.5
				points = PackedVector2Array([start, Vector2(start.x, mid), Vector2(finish.x, mid), finish])
			var edge_color := TEAL if bool(offer.owned) else (GOLD if bool(offer.available) else Color("54666a"))
			draw_polyline(points, Color(0.02, 0.05, 0.06, 0.9), 6, true)
			draw_polyline(points, edge_color, 2.5 if bool(offer.owned) else 1.6, true)
			var socket := finish + Vector2(0, -7)
			draw_colored_polygon(PackedVector2Array([socket + Vector2(0, -4), socket + Vector2(4, 0), socket + Vector2(0, 4), socket + Vector2(-4, 0)]), edge_color)
			draw_circle(start + Vector2(0, 5), 3, edge_color)


func _style_button(button: Button, offer: Dictionary) -> void:
	var discovered := bool(offer.get("discovered", true))
	var selected := String(offer.id) == _selected
	var owned := bool(offer.owned)
	var locked := not discovered or (not bool(offer.available) and not owned)
	var presentation := "selected" if selected or owned else ("locked" if locked else "normal")
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := ART_THEME.style("slot", presentation if state == "normal" else state).duplicate() as StyleBox
		style.content_margin_left = 15
		style.content_margin_right = 15
		style.content_margin_top = 10
		style.content_margin_bottom = 10
		button.add_theme_stylebox_override(state, style)
	var text_color := TEXT if discovered else Color("9eaeae")
	button.add_theme_color_override("font_color", TEAL if owned else text_color)
	button.add_theme_color_override("font_hover_color", TEXT)
	button.add_theme_color_override("font_focus_color", TEXT)
	button.add_theme_color_override("icon_normal_color", Color.WHITE if discovered else Color("89999b"))
	button.set_meta("art_state", "owned" if owned else ("selected" if selected else ("locked" if locked else "available")))
