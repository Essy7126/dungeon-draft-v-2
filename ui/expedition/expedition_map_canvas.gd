class_name ExpeditionMapCanvas
extends Control

## Inspection only: committing a destination belongs to the containing screen.
signal node_selected(node_id: String)

const BG := Color("ddc79a")
const INK := Color("3b2d22")
const MUTED := Color("82745b")
const GOLD := Color("906321")
const TEAL := Color("366150")
const RED := Color("973e2e")
const ART_THEME := preload("res://ui/expedition/catabase_ui_theme.gd")
const ROW_HEIGHT := 132.0
const CARD_HEIGHT := 78.0
const TOP := 100.0
const LEFT := 54.0
const RIGHT := 54.0
const GAP := 12.0
const ROMANS: Array[String] = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII", "XIII", "XIV", "XV", "XVI", "XVII", "XVIII", "XIX", "XX"]
const KIND_LABELS := {"normal": "COMBAT", "elite": "ÉPREUVE", "boss": "BOSS",
	"hub": "REFUGE", "merchant": "MARCHAND", "sanctuary": "SANCTUAIRE", "lore": "MÉMOIRE",
	"cache": "CACHE", "event": "RENCONTRE", "unknown": "INCONNU", "hidden": "PASSAGE SECRET"}
const REWARD_LABELS := {"melee": "Technique · mêlée", "ranged": "Technique · distance",
	"armor": "Protection · airain", "mobility": "Mobilité · esquive", "control": "Technique · contrôle",
	"healing": "Souffle · récupération", "elemental": "Technique · éléments", "discovery": "Technique · découverte",
	"vitality": "Vitalité · pari", "signature": "Butin d'épreuve", "victory": "Fin de l'expédition",
	"unknown": "Récompense inconnue"}

var _route: ExpeditionRouteState
var _preview_nodes: Array[Dictionary] = []
var _by_id: Dictionary = {}
var _buttons: Dictionary = {}
var _rects: Dictionary = {}
var _reachable: Dictionary = {}
var _selected_path: Dictionary = {}
var _depth_y: Dictionary = {}
var _selected_id: String = ""
var _layout_queued: bool = false
var _overview_height := 0.0
var subtitle_text := "Les routes se dessinent. Leurs secrets restent à découvrir."
var footer_text := "Choisir un nœud ouvre sa fiche. Le départ se confirme ensuite."


func _init() -> void:
	custom_minimum_size = Vector2(580, 3280)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS


func _ready() -> void:
	resized.connect(_schedule_layout)
	_layout_map()


func set_route(state: ExpeditionRouteState) -> void:
	_route = state
	for button in _buttons.values():
		remove_child(button)
		button.queue_free()
	_buttons.clear()
	_by_id.clear()
	_preview_nodes.clear()
	if state != null:
		_preview_nodes = state.get_visible_nodes()
	for node in _preview_nodes:
		_by_id[String(node["id"])] = node
	_compute_reachable()
	_selected_path.clear()
	for node in _preview_nodes:
		_make_button(node)
	if not _by_id.has(_selected_id):
		_selected_id = ""
	_layout_map()


func select_node(node_id: String) -> void:
	if not _buttons.has(node_id):
		return
	_selected_id = node_id
	_selected_path.clear()
	if _route != null:
		for id in _route.get_choice_preview(node_id).get("path_ids", []):
			_selected_path[str(id)] = true
	_restyle_buttons()
	queue_redraw()


func set_overview_height(height: float) -> void:
	_overview_height = maxf(440.0, height)
	_layout_map()


func get_depth_scroll_position(depth: int) -> int:
	# Include rows reserved for revealed passages when restoring progression.
	return maxi(0, roundi(float(_depth_y.get(clampi(depth, 1, 20), TOP)) - TOP))


func _make_button(node: Dictionary) -> void:
	var node_id := String(node["id"])
	var button := Button.new()
	button.name = "Destination_%s" % node_id
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.clip_contents = true
	button.tooltip_text = "%s\n%s\n%s\n%s\nSélectionner pour inspecter cette destination." % [
		String(node["title"]), _kind_label(node), String(node.get("hint", "")), _status_label(node)]
	var presentation_kind := CatabasePaintedIconCatalog.route_presentation_kind(node)
	button.set_meta("presentation_kind", presentation_kind)
	button.pressed.connect(_on_pressed.bind(node_id))
	add_child(button)
	ART_THEME.bind_button_motion(button)
	_buttons[node_id] = button
	var content := VBoxContainer.new()
	content.name = "Content"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 10
	content.offset_top = 7
	content.offset_right = -10
	content.offset_bottom = -7
	content.add_theme_constant_override("separation", 2)
	button.add_child(content)
	var marker: Texture2D = CatabasePaintedIconCatalog.map_node_icon(node)
	var kind := _label("Kind", "?" if presentation_kind == "unknown" and marker == null else "", 28)
	kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kind.custom_minimum_size.y = 49
	kind.add_theme_color_override("font_color", _accent(node))
	content.add_child(kind)
	if marker != null:
		var icon := TextureRect.new()
		icon.name = "DestinationIcon"
		icon.texture = marker
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		icon.offset_left = -24
		icon.offset_top = -24
		icon.offset_right = 24
		icon.offset_bottom = 24
		icon.modulate = _accent(node)
		icon.set_meta("presentation_kind", presentation_kind)
		kind.add_child(icon)
	if bool(node.get("visited", false)) and not bool(node.get("completed", false)):
		var current: Texture2D = CatabasePaintedIconCatalog.map_icon("current")
		if current != null:
			var badge := TextureRect.new()
			badge.name = "CurrentPositionIcon"
			badge.texture = current
			badge.modulate = TEAL
			badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			badge.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
			badge.offset_left = 15
			badge.offset_top = 0
			badge.offset_right = 39
			badge.offset_bottom = 24
			kind.add_child(badge)
	var title := _label("Title", String(node["title"]), 14)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.max_lines_visible = 2
	title.size_flags_vertical = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", INK if _is_emphasized(node) else MUTED)
	content.add_child(title)
	var reward := _label("Reward", _kind_label(node), 10)
	reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward.add_theme_color_override("font_color", GOLD if bool(node["completed"]) else MUTED)
	content.add_child(reward)
	var status := _label("Status", _status_label(node), 10)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_color_override("font_color", _accent(node))
	content.add_child(status)


func _label(label_name: String, text_value: String, font_size: int) -> Label:
	var label := Label.new()
	label.name = label_name
	label.text = text_value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", font_size)
	# Paper uses flat ink; the dark modal theme's embossed text is unreadable here.
	label.add_theme_constant_override("outline_size", 0)
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 0)
	label.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	return label


func _compute_reachable() -> void:
	_reachable.clear()
	var pending: Array[String] = []
	for node in _preview_nodes:
		if bool(node["available"]) or (bool(node["visited"]) and not bool(node["completed"])):
			pending.append(String(node["id"]))
	while not pending.is_empty():
		var node_id: String = pending.pop_back()
		if _reachable.has(node_id) or not _by_id.has(node_id):
			continue
		_reachable[node_id] = true
		for next_id in _by_id[node_id]["edges"]:
			pending.append(String(next_id))


func _schedule_layout() -> void:
	if _layout_queued:
		return
	_layout_queued = true
	call_deferred("_layout_map")


func _layout_map() -> void:
	_layout_queued = false
	_rects.clear()
	_depth_y.clear()
	var canvas_width := maxf(size.x, 580.0)
	var usable_width := minf(canvas_width - LEFT - RIGHT, 720.0)
	var map_left := (canvas_width - usable_width) * 0.5
	var overview := _overview_height > 0.0
	var pitch := (_overview_height - 90.0) / 20.0 if overview else ROW_HEIGHT
	var extent := minf(30.0, pitch - 3.0) if overview else CARD_HEIGHT
	var card_width := extent if overview else 78.0
	var cursor_y := 58.0 if overview else TOP
	var ordered_ids: Array[String] = []
	for depth in range(1, 21):
		_depth_y[depth] = cursor_y
		var layer: Array[Dictionary] = []
		for node in _preview_nodes:
			if int(node["depth"]) == depth:
				layer.append(node)
		layer.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["lane"]) < int(b["lane"]))
		var previous_right := map_left - GAP
		for index in layer.size():
			var node: Dictionary = layer[index]
			# The same winding positions in both views preserve spatial orientation.
			# Revealed passages occupy their own lane, never an inserted extra depth.
			var fraction := 0.5
			if layer.size() > 1:
				fraction = 0.08 + 0.84 * float(index) / float(layer.size() - 1)
			var drift := sin(float(depth) * 1.71 + float(index) * 0.9) * 0.065
			fraction = float(node.get("map_x", clampf(fraction + drift, 0.0, 1.0)))
			var right_limit := map_left + usable_width - card_width - (layer.size() - index - 1) * (card_width + GAP)
			var x := clampf(map_left + fraction * (usable_width - card_width), previous_right + GAP, right_limit)
			previous_right = x + card_width
			var rect := Rect2(Vector2(x, cursor_y), Vector2(card_width, extent))
			_place_button(String(node["id"]), rect)
			ordered_ids.append(String(node["id"]))
		cursor_y += pitch
	custom_minimum_size.y = _overview_height if overview else cursor_y + 38.0
	_restyle_buttons()
	_set_keyboard_neighbors(ordered_ids)
	queue_redraw()


func _place_button(node_id: String, rect: Rect2) -> void:
	_rects[node_id] = rect
	if not _buttons.has(node_id):
		return
	var button: Button = _buttons[node_id]
	button.position = rect.position
	var content := button.get_node("Content") as VBoxContainer
	var overview := _overview_height > 0.0
	content.offset_left = 0 if overview else 6
	content.offset_right = 0 if overview else -6
	content.offset_top = 0 if overview else 7
	content.offset_bottom = 0 if overview else -7
	for label_name in ["Title", "Reward", "Status"]:
		content.get_node(label_name).visible = not overview and label_name == "Status"
	var kind := content.get_node("Kind") as Label
	kind.custom_minimum_size.y = rect.size.y if overview else 49.0
	kind.add_theme_font_size_override("font_size", 16 if overview else 28)
	var icon := kind.get_node_or_null("DestinationIcon") as TextureRect
	if icon != null:
		var half := rect.size.y * 0.44 if overview else 24.0
		icon.offset_left = -half
		icon.offset_right = half
		icon.offset_top = -half
		icon.offset_bottom = half
	var badge := kind.get_node_or_null("CurrentPositionIcon") as TextureRect
	if badge != null:
		badge.visible = not overview
	button.size = rect.size

func _set_keyboard_neighbors(ordered_ids: Array[String]) -> void:
	for index in ordered_ids.size():
		var button: Button = _buttons[ordered_ids[index]]
		if index > 0:
			button.focus_previous = button.get_path_to(_buttons[ordered_ids[index - 1]])
		if index + 1 < ordered_ids.size():
			button.focus_next = button.get_path_to(_buttons[ordered_ids[index + 1]])
		var current: Dictionary = _by_id[ordered_ids[index]]
		for direction in ["left", "right", "top", "bottom"]:
			var best_id := ""
			var best_distance := INF
			var origin: Vector2 = _rects[ordered_ids[index]].get_center()
			for candidate_id in ordered_ids:
				if candidate_id == ordered_ids[index]:
					continue
				var candidate: Dictionary = _by_id[candidate_id]
				var offset: Vector2 = _rects[candidate_id].get_center() - origin
				if direction in ["left", "right"]:
					if int(candidate["depth"]) != int(current["depth"]):
						continue
					if (direction == "left" and offset.x >= -1.0) or (direction == "right" and offset.x <= 1.0):
						continue
				elif (direction == "top" and offset.y >= -1.0) or (direction == "bottom" and offset.y <= 1.0):
					continue
				var distance := absf(offset.y) * 3.0 + absf(offset.x)
				if distance < best_distance:
					best_distance = distance
					best_id = candidate_id
			if not best_id.is_empty():
				button.set("focus_neighbor_%s" % direction, button.get_path_to(_buttons[best_id]))


func _restyle_buttons() -> void:
	for node_id in _buttons:
		var node: Dictionary = _by_id[node_id]
		var button: Button = _buttons[node_id]
		var selected: bool = String(node_id) == _selected_id
		var border := GOLD if selected else _accent(node)
		var fill := Color.TRANSPARENT
		button.add_theme_stylebox_override("normal", _style(fill, Color.TRANSPARENT, 0))
		button.add_theme_stylebox_override("hover", _style(Color(1, 0.96, 0.78, 0.30), border, 1))
		button.add_theme_stylebox_override("pressed", _style(Color(0.54, 0.36, 0.13, 0.16), GOLD, 1))
		var focus := _style(Color.TRANSPARENT, INK, 2)
		focus.expand_margin_left = 3
		focus.expand_margin_right = 3
		focus.expand_margin_top = 3
		focus.expand_margin_bottom = 3
		button.add_theme_stylebox_override("focus", focus)


func _style(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(24 if _overview_height > 0.0 else 7)
	return style


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	_draw_parchment()
	_draw_motifs()
	var font: Font = ThemeDB.fallback_font
	draw_string(font, Vector2(LEFT, 29), "LE CHEMIN DES OMBRES", HORIZONTAL_ALIGNMENT_CENTER, size.x - LEFT - RIGHT, 20, INK)
	draw_string(font, Vector2(LEFT, 50), subtitle_text, HORIZONTAL_ALIGNMENT_CENTER, size.x - LEFT - RIGHT, 12, MUTED)
	if _overview_height <= 0.0:
		_draw_legend(font)
	for node in _preview_nodes:
		var from_id := String(node["id"])
		if not _rects.has(from_id):
			continue
		var source: Rect2 = _rects[from_id]
		for target_id in node["edges"]:
			if not _rects.has(target_id):
				continue
			var target_node: Dictionary = _by_id[target_id]
			var target: Rect2 = _rects[target_id]
			var travelled := bool(node["completed"]) and bool(target_node["visited"])
			var reachable: bool = _reachable.has(from_id) and _reachable.has(target_id)
			if bool(node["completed"]) and bool(target_node["available"]):
				reachable = true
			var planned := _selected_path.has(from_id) and _selected_path.has(str(target_id))
			var line_color := RED if travelled else (Color("667055") if reachable else Color("b3a07d"))
			if planned and not travelled:
				line_color = TEAL
			var start := Vector2(source.get_center().x, source.end.y - 4.0)
			var finish := Vector2(target.get_center().x, target.position.y)
			if _overview_height > 0.0:
				var direction := (target.get_center() - source.get_center()).normalized()
				start = source.get_center() + direction * source.size.y * 0.55
				finish = target.get_center() - direction * target.size.y * 0.55
			var points := PackedVector2Array()
			var segments := maxi(2, ceili(start.distance_to(finish) / 4.0))
			for step in segments + 1:
				var t := float(step) / float(segments)
				points.append(start.lerp(finish, t) + Vector2(sin(t * PI * 2.0) * 3.0, 0))
			if travelled or planned:
				draw_polyline(points, line_color, 2.3, true)
			else:
				# Fixed-length marks stay readable at both zoom levels.
				for step in range(0, segments, 2):
					draw_line(points[step], points[step + 1], line_color, 1.3, true)
		var center := source.get_center() if _overview_height > 0.0 else Vector2(source.get_center().x, source.position.y + 31.5)
		var accent := _accent(node)
		var radius := source.size.y * 0.48 if _overview_height > 0.0 else 26.0
		if from_id == _selected_id or bool(node.get("available", false)) or (bool(node.get("visited", false)) and not bool(node.get("completed", false))):
			# A loose ink circle marks interaction, leaving ordinary glyphs unframed.
			draw_arc(center, radius, -0.12, TAU - 0.28, 40, RED if from_id == _selected_id else accent, 1.5, true)
		if _overview_height <= 0.0:
			_draw_symbol(CatabasePaintedIconCatalog.route_presentation_kind(node), center, accent)
	for depth in _depth_y:
		var y: float = _depth_y[depth] + (15.0 if _overview_height > 0.0 else 44.0)
		draw_string(font, Vector2(9, y), ROMANS[int(depth) - 1], HORIZONTAL_ALIGNMENT_LEFT, 35, 12, GOLD.darkened(0.25))
		draw_line(Vector2(39, y - 4), Vector2(46, y - 4), MUTED, 1.0)
	draw_string(font, Vector2(LEFT, custom_minimum_size.y - 14),
		footer_text, HORIZONTAL_ALIGNMENT_CENTER, size.x - LEFT - RIGHT, 11, MUTED)


func _draw_legend(font: Font) -> void:
	var captions := ["À choisir", "Résolue", "Spirale : inconnue", "Grisé : autre chemin"]
	var colors := [TEAL, GOLD, INK, MUTED]
	var widths: Array[float] = []
	var total_width := 0.0
	for index in captions.size():
		var width := font.get_string_size(captions[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + (13.0 if index < 2 else 0.0)
		widths.append(width)
		total_width += width
	var left := (size.x - total_width - 18.0 * (captions.size() - 1)) * 0.5
	for index in captions.size():
		var color: Color = colors[index]
		if index < 2:
			draw_circle(Vector2(left + 3, 71), 3, color)
		draw_string(font, Vector2(left + (13.0 if index < 2 else 0.0), 75), captions[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, color)
		left += widths[index] + 18.0


func _kind_label(node: Dictionary) -> String:
	return String(KIND_LABELS.get(CatabasePaintedIconCatalog.route_presentation_kind(node), "DESTINATION"))


func _status_label(node: Dictionary) -> String:
	if bool(node["completed"]):
		return "RÉSOLUE"
	if bool(node["visited"]):
		return "EN COURS"
	if bool(node["available"]):
		return "À CHOISIR"
	return "À VENIR" if _reachable.has(String(node["id"])) else "AUTRE VOIE"


func _accent(node: Dictionary) -> Color:
	var kind := CatabasePaintedIconCatalog.route_presentation_kind(node)
	if bool(node["completed"]):
		return GOLD
	if not _reachable.has(String(node["id"])) and not bool(node["visited"]):
		return Color("a99776")
	if kind in ["elite", "boss"]:
		return RED
	if bool(node["available"]) or kind in ["hub", "merchant", "sanctuary", "lore"]:
		return TEAL
	if kind == "hidden":
		return GOLD
	return Color("79664a")


func _draw_motifs() -> void:
	# Thin Greek meanders frame the paper; laurel leaves mark the major thresholds.
	var ink := Color(0.32, 0.23, 0.12, 0.16)
	for side in [0, 1]:
		var x := 3.0 if side == 0 else size.x - 14.0
		for y in range(88, int(size.y) - 28, 36):
			draw_polyline(PackedVector2Array([
				Vector2(x, y + 32), Vector2(x, y), Vector2(x + 10, y),
				Vector2(x + 10, y + 23), Vector2(x + 5, y + 23), Vector2(x + 5, y + 8),
			]), ink, 1.0, true)
	for depth in [7, 15, 20]:
		var y := float(_depth_y.get(depth, TOP))
		var c := Vector2(size.x - 30, y + 12)
		draw_arc(c, 12, -1.2, 1.2, 16, ink, 1.0, true)
		for leaf in 4:
			var angle := -0.9 + leaf * 0.6
			var point := c + Vector2(cos(angle), sin(angle)) * 12.0
			draw_line(point, point + Vector2(5, -4), ink, 2.0, true)


func _draw_parchment() -> void:
	var paper: Texture2D = ART_THEME.texture("route_parchment")
	if paper != null:
		if _overview_height > 0.0:
			draw_texture_rect(paper, Rect2(Vector2.ZERO, size), false)
			return
		# Keep the painted corners only at the ends. Repeat the quiet centre at
		# uniform scale so ornaments never reappear behind destinations midway.
		var scale_factor := size.x / float(paper.get_width())
		var cap_source_height := paper.get_height() * 0.18
		var cap_height := minf(cap_source_height * scale_factor, size.y * 0.5)
		var section_height := (paper.get_height() - cap_source_height * 2.0) * scale_factor
		if scale_factor > 0 and section_height > 0:
			draw_texture_rect_region(paper, Rect2(0, 0, size.x, cap_height), Rect2(0, 0, paper.get_width(), cap_height / scale_factor))
			var top := cap_height
			while top < size.y - cap_height:
				var visible_height := minf(section_height, size.y - cap_height - top)
				var source := Rect2(0, cap_source_height, paper.get_width(), visible_height / scale_factor)
				draw_texture_rect_region(paper, Rect2(0, top, size.x, visible_height), source)
				top += section_height
			draw_texture_rect_region(paper, Rect2(0, size.y - cap_height, size.x, cap_height), Rect2(0, paper.get_height() - cap_height / scale_factor, paper.get_width(), cap_height / scale_factor))
			return
	# Stable fallback fibres retain readable paper while an optional asset imports.
	for strip in 14:
		var opacity := 0.065 * (1.0 - float(strip) / 14.0)
		draw_rect(Rect2(Vector2(strip, 0), Vector2(size.x - strip * 2, size.y)), Color(0.28, 0.15, 0.05, opacity), false, 1)
	for i in 430:
		var x := fmod(float(i * 193 + 37), maxf(size.x - 24, 1)) + 12
		var y := fmod(float(i * 317 + 59), maxf(size.y - 40, 1)) + 20
		draw_line(Vector2(x, y), Vector2(x + 2 + i % 7, y + 1), Color(0.33, 0.23, 0.12, 0.055), 1)
	for row in range(180, int(size.y) - 40, 360):
		for contour in 3:
			var points := PackedVector2Array()
			for step in 15:
				points.append(Vector2(size.x - 15 - contour * 7 - sin(step * 0.42) * 22, row + step * 7))
			draw_polyline(points, Color(0.44, 0.32, 0.18, 0.12), 1, true)


func _draw_symbol(kind: String, c: Vector2, ink: Color) -> void:
	if CatabasePaintedIconCatalog.map_icon(kind) != null:
		return # The TextureRect on the destination button owns the drawn symbol.
	if kind == "unknown":
		return
	if kind in ["normal", "elite", "boss"]:
		for direction in [-1.0, 1.0]:
			draw_line(c + Vector2(-12 * direction, 13), c + Vector2(12 * direction, -13), ink, 2.5, true)
			draw_line(c + Vector2(-11 * direction, 3), c + Vector2(-3 * direction, 11), ink, 2, true)
		if kind != "normal":
			draw_circle(c + Vector2(0, -13), 3, ink)
	elif kind in ["hub", "cache", "event", "hidden"]:
		draw_polyline(PackedVector2Array([c + Vector2(-15, 10), c + Vector2(0, -13), c + Vector2(15, 10), c + Vector2(-15, 10)]), ink, 2, true)
		draw_line(c + Vector2(0, -5), c + Vector2(0, 11), ink, 2, true)
	elif kind == "merchant":
		draw_arc(c + Vector2(0, 3), 11, 0, TAU, 32, ink, 2, true)
		draw_polyline(PackedVector2Array([c + Vector2(-7, -12), c + Vector2(7, -12), c + Vector2(4, -7), c + Vector2(-4, -7), c + Vector2(-7, -12)]), ink, 2, true)
		draw_line(c + Vector2(0, -2), c + Vector2(0, 9), ink, 2, true)
	elif kind == "sanctuary":
		draw_polyline(PackedVector2Array([c + Vector2(-15, -5), c + Vector2(0, -14), c + Vector2(15, -5)]), ink, 2, true)
		for x in [-10, 0, 10]:
			draw_line(c + Vector2(x, -3), c + Vector2(x, 11), ink, 2, true)
		draw_line(c + Vector2(-15, 13), c + Vector2(15, 13), ink, 2, true)
	else:
		draw_rect(Rect2(c + Vector2(-12, -12), Vector2(24, 24)), ink, false, 2)
		draw_line(c + Vector2(0, -12), c + Vector2(0, 12), ink, 1, true)
		for y in [-5, 1, 7]:
			draw_line(c + Vector2(4, y), c + Vector2(9, y), ink, 1, true)


func _is_emphasized(node: Dictionary) -> bool:
	return bool(node["available"]) or bool(node["visited"]) or _reachable.has(String(node["id"]))


func _on_pressed(node_id: String) -> void:
	select_node(node_id)
	node_selected.emit(node_id)
