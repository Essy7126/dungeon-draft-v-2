class_name HudGrayboxAnnotation
extends Control

const FLOW := ["REPOS", "SURVOL", "SÉLECTION", "CIBLAGE", "VALIDATION", "RÉSOLUTION"]

const TITLES := {
	&"idle": "01 · REPOS",
	&"hover": "02 · SURVOL",
	&"selected": "03 · SÉLECTION",
	&"unavailable": "PA INSUFFISANTS",
	&"cooldown": "RECHARGE",
	&"locked": "VERROUILLÉ",
	&"targeting_valid": "05 · CIBLE VALIDE",
	&"targeting_invalid": "04 · CIBLE INVALIDE",
	&"resolving": "06 · RÉSOLUTION",
	&"enemy_turn": "TOUR ADVERSE",
}

var state_id: StringName = &"idle":
	set(value):
		state_id = value
		queue_redraw()

var _font: Font = null
var _font_bold: Font = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	_font_bold = ThemeDB.fallback_font
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	var scale_factor := clampf(size.x / 1600.0, 0.78, 1.15)
	var margin := 22.0 * scale_factor
	var header_height := 46.0 * scale_factor
	var title_width := 260.0 * scale_factor
	_draw_panel(Rect2(margin, margin, title_width, header_height), true)
	_draw_text(
		"UX GRAYBOX · ACHILLE",
		Vector2(margin + 16.0 * scale_factor, margin + 30.0 * scale_factor),
		14.0 * scale_factor,
		Color("f2f2ed")
	)
	var state_title := str(TITLES.get(state_id, String(state_id).to_upper()))
	var state_width := 230.0 * scale_factor
	_draw_panel(
		Rect2(size.x - margin - state_width, margin, state_width, header_height),
		true
	)
	_draw_text(
		state_title,
		Vector2(size.x - margin - state_width + 16.0 * scale_factor, margin + 30.0 * scale_factor),
		14.0 * scale_factor,
		Color("f2f2ed")
	)
	_draw_flow(scale_factor, margin, header_height)


func _draw_flow(scale_factor: float, margin: float, header_height: float) -> void:
	var gap := 5.0 * scale_factor
	var available_width := size.x - 2.0 * margin
	var chip_width := minf(142.0 * scale_factor, (available_width - gap * 5.0) / 6.0)
	var total_width := chip_width * 6.0 + gap * 5.0
	var start_x := (size.x - total_width) * 0.5
	var y := margin + header_height + 9.0 * scale_factor
	var active_index := _active_flow_index()
	for index in FLOW.size():
		var active := index == active_index
		var rect := Rect2(
			start_x + float(index) * (chip_width + gap),
			y,
			chip_width,
			25.0 * scale_factor
		)
		_draw_panel(rect, active)
		var color := Color("f4f4ef") if active else Color("a9adb0")
		_draw_centered_text(FLOW[index], rect, 10.0 * scale_factor, color)


func _active_flow_index() -> int:
	match state_id:
		&"idle":
			return 0
		&"hover":
			return 1
		&"selected":
			return 2
		&"targeting_invalid":
			return 3
		&"targeting_valid":
			return 4
		&"resolving":
			return 5
		_:
			return -1


func _draw_panel(rect: Rect2, active: bool) -> void:
	var fill := Color(0.11, 0.12, 0.13, 0.94) if active else Color(0.08, 0.09, 0.10, 0.88)
	var border := Color("d8d8d2") if active else Color("5e6368")
	draw_style_box(_style_box(fill, border, 6), rect)


func _style_box(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style


func _draw_text(text: String, baseline: Vector2, font_size: float, color: Color) -> void:
	if _font_bold == null:
		return
	draw_string(
		_font_bold,
		baseline,
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		maxi(8, int(round(font_size))),
		color
	)


func _draw_centered_text(text: String, rect: Rect2, font_size: float, color: Color) -> void:
	if _font == null:
		return
	var resolved_size := maxi(8, int(round(font_size)))
	var text_size := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, resolved_size)
	var baseline := rect.position + Vector2(
		(rect.size.x - text_size.x) * 0.5,
		(rect.size.y + text_size.y * 0.55) * 0.5
	)
	draw_string(
		_font,
		baseline,
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		resolved_size,
		color
	)
