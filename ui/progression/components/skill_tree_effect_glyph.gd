class_name SkillTreeEffectGlyph
extends Control

@export var glyph_id: StringName = &"generic":
	set(value):
		glyph_id = value
		queue_redraw()

var _texture: Texture2D = null
var _using_fallback := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()


func configure(
		wanted_glyph_id: StringName,
		texture: Texture2D = null
	) -> void:
	glyph_id = wanted_glyph_id if wanted_glyph_id != &"" else &"generic"
	_texture = texture
	_using_fallback = _texture == null
	queue_redraw()


func configure_effect(
		wanted_glyph_id: StringName,
		skin: SkillTreeSkinData
	) -> void:
	configure(
		wanted_glyph_id,
		skin.get_effect_glyph(wanted_glyph_id) if skin != null else null
	)


func configure_discipline(
		wanted_icon_id: StringName,
		skin: SkillTreeSkinData
	) -> void:
	configure(
		wanted_icon_id,
		skin.get_discipline_icon(wanted_icon_id) if skin != null else null
	)


func is_using_fallback() -> bool:
	return _using_fallback


func has_texture() -> bool:
	return _texture != null


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	if _texture != null:
		_draw_fitted_texture(_texture)
		return
	var rect := Rect2(Vector2.ZERO, size)
	var ink := _theme_color(
		"glyph_ink",
		Color(0.82, 0.88, 0.82, 1.0)
	)
	var accent := _theme_color(
		"glyph_accent",
		Color(0.78, 0.62, 0.3, 1.0)
	)
	var shadow := _theme_color(
		"glyph_shadow",
		Color(0.1, 0.13, 0.15, 0.95)
	)
	match glyph_id:
		&"damage":
			_draw_damage(rect, ink, accent)
		&"range":
			_draw_range(rect, ink, accent)
		&"push":
			_draw_push(rect, ink, accent)
		&"movement":
			_draw_movement(rect, ink, accent)
		&"bleed":
			_draw_bleed(rect, ink, accent)
		&"vulnerability":
			_draw_vulnerability(rect, ink, accent)
		&"collision":
			_draw_collision(rect, ink, accent)
		&"duration":
			_draw_duration(rect, ink, accent)
		&"area_or_pierce":
			_draw_pierce(rect, ink, accent)
		&"elf_archer":
			_draw_archer(rect, ink, accent)
		&"elf_assassin":
			_draw_assassin(rect, ink, accent)
		&"elf_mage":
			_draw_mage(rect, ink, accent)
		&"elf_healer":
			_draw_healer(rect, ink, accent)
		&"pending":
			_draw_pending(rect, ink, accent, shadow)
		&"future":
			_draw_future(rect, ink)
		_:
			_draw_generic(rect, ink, accent)


func _draw_fitted_texture(texture: Texture2D) -> void:
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var scale_factor := minf(
		size.x / texture_size.x,
		size.y / texture_size.y
	)
	var draw_size := texture_size * scale_factor
	var draw_rect := Rect2((size - draw_size) * 0.5, draw_size)
	draw_texture_rect(texture, draw_rect, false)


func _draw_damage(rect: Rect2, ink: Color, accent: Color) -> void:
	var a := rect.position + rect.size * Vector2(0.25, 0.2)
	var b := rect.position + rect.size * Vector2(0.75, 0.8)
	var c := rect.position + rect.size * Vector2(0.75, 0.2)
	var d := rect.position + rect.size * Vector2(0.25, 0.8)
	draw_line(a, b, ink, _stroke(0.1), true)
	draw_line(c, d, ink, _stroke(0.1), true)
	draw_circle(rect.get_center(), _unit() * 0.11, accent)


func _draw_range(rect: Rect2, ink: Color, accent: Color) -> void:
	var y := rect.get_center().y
	var start := Vector2(rect.position.x + rect.size.x * 0.16, y)
	var finish := Vector2(rect.end.x - rect.size.x * 0.12, y)
	draw_line(start, finish, ink, _stroke(0.075), true)
	for marker in [0.3, 0.5, 0.7]:
		var x := lerpf(rect.position.x, rect.end.x, marker)
		draw_circle(Vector2(x, y), _unit() * 0.06, accent)
	_draw_arrow_head(finish, Vector2.RIGHT, ink)


func _draw_push(rect: Rect2, ink: Color, accent: Color) -> void:
	var box := Rect2(
		rect.position + rect.size * Vector2(0.64, 0.31),
		rect.size * Vector2(0.22, 0.38)
	)
	draw_rect(box, accent, false, _stroke(0.07), true)
	var start := rect.position + rect.size * Vector2(0.14, 0.5)
	var finish := rect.position + rect.size * Vector2(0.58, 0.5)
	draw_line(start, finish, ink, _stroke(0.09), true)
	_draw_arrow_head(finish, Vector2.RIGHT, ink)


func _draw_movement(rect: Rect2, ink: Color, accent: Color) -> void:
	var base := rect.position + rect.size * Vector2(0.2, 0.68)
	var points := PackedVector2Array([
		base,
		rect.position + rect.size * Vector2(0.42, 0.25),
		rect.position + rect.size * Vector2(0.54, 0.52),
		rect.position + rect.size * Vector2(0.82, 0.6),
		rect.position + rect.size * Vector2(0.72, 0.78),
		rect.position + rect.size * Vector2(0.36, 0.75),
	])
	draw_polyline(points, ink, _stroke(0.085), true)
	draw_line(
		rect.position + rect.size * Vector2(0.2, 0.88),
		rect.position + rect.size * Vector2(0.76, 0.88),
		accent,
		_stroke(0.06),
		true
	)


func _draw_bleed(rect: Rect2, ink: Color, accent: Color) -> void:
	var center := rect.position + rect.size * Vector2(0.5, 0.58)
	var points := PackedVector2Array([
		rect.position + rect.size * Vector2(0.5, 0.12),
		rect.position + rect.size * Vector2(0.28, 0.58),
		center + rect.size * Vector2(-0.12, 0.2),
		center + rect.size * Vector2(0.12, 0.2),
		rect.position + rect.size * Vector2(0.72, 0.58),
	])
	draw_colored_polygon(points, accent)
	draw_polyline(points, ink, _stroke(0.045), true)
	draw_line(
		rect.position + rect.size * Vector2(0.24, 0.2),
		rect.position + rect.size * Vector2(0.76, 0.38),
		ink,
		_stroke(0.06),
		true
	)


func _draw_vulnerability(rect: Rect2, ink: Color, accent: Color) -> void:
	var shield := PackedVector2Array([
		rect.position + rect.size * Vector2(0.5, 0.12),
		rect.position + rect.size * Vector2(0.78, 0.27),
		rect.position + rect.size * Vector2(0.7, 0.68),
		rect.position + rect.size * Vector2(0.5, 0.86),
		rect.position + rect.size * Vector2(0.3, 0.68),
		rect.position + rect.size * Vector2(0.22, 0.27),
		rect.position + rect.size * Vector2(0.5, 0.12),
	])
	draw_polyline(shield, ink, _stroke(0.07), true)
	var crack := PackedVector2Array([
		rect.position + rect.size * Vector2(0.58, 0.2),
		rect.position + rect.size * Vector2(0.43, 0.45),
		rect.position + rect.size * Vector2(0.58, 0.53),
		rect.position + rect.size * Vector2(0.38, 0.79),
	])
	draw_polyline(crack, accent, _stroke(0.07), true)


func _draw_collision(rect: Rect2, ink: Color, accent: Color) -> void:
	var left_box := Rect2(
		rect.position + rect.size * Vector2(0.12, 0.32),
		rect.size * Vector2(0.23, 0.36)
	)
	var right_box := Rect2(
		rect.position + rect.size * Vector2(0.65, 0.32),
		rect.size * Vector2(0.23, 0.36)
	)
	draw_rect(left_box, ink, false, _stroke(0.06), true)
	draw_rect(right_box, ink, false, _stroke(0.06), true)
	draw_line(left_box.end, rect.get_center(), accent, _stroke(0.07), true)
	draw_line(right_box.position, rect.get_center(), accent, _stroke(0.07), true)
	draw_circle(rect.get_center(), _unit() * 0.08, accent)


func _draw_duration(rect: Rect2, ink: Color, accent: Color) -> void:
	var top_left := rect.position + rect.size * Vector2(0.27, 0.16)
	var top_right := rect.position + rect.size * Vector2(0.73, 0.16)
	var bottom_left := rect.position + rect.size * Vector2(0.27, 0.84)
	var bottom_right := rect.position + rect.size * Vector2(0.73, 0.84)
	draw_line(top_left, top_right, ink, _stroke(0.07), true)
	draw_line(bottom_left, bottom_right, ink, _stroke(0.07), true)
	draw_line(top_left, bottom_right, ink, _stroke(0.06), true)
	draw_line(top_right, bottom_left, ink, _stroke(0.06), true)
	draw_circle(rect.get_center(), _unit() * 0.07, accent)


func _draw_pierce(rect: Rect2, ink: Color, accent: Color) -> void:
	var y := rect.get_center().y
	for x_factor in [0.36, 0.62]:
		draw_circle(
			rect.position + rect.size * Vector2(x_factor, 0.5),
			_unit() * 0.13,
			accent,
			false,
			_stroke(0.055),
			true
		)
	var start := rect.position + rect.size * Vector2(0.12, 0.5)
	var finish := rect.position + rect.size * Vector2(0.88, 0.5)
	draw_line(start, finish, ink, _stroke(0.075), true)
	_draw_arrow_head(finish, Vector2.RIGHT, ink)


func _draw_archer(rect: Rect2, ink: Color, accent: Color) -> void:
	var center := rect.get_center()
	draw_arc(
		center + Vector2(_unit() * 0.08, 0.0),
		_unit() * 0.33,
		-PI * 0.5,
		PI * 0.5,
		16,
		ink,
		_stroke(0.065),
		true
	)
	var string_top := center + Vector2(_unit() * 0.08, -_unit() * 0.33)
	var string_bottom := center + Vector2(_unit() * 0.08, _unit() * 0.33)
	draw_line(string_top, center - Vector2(_unit() * 0.08, 0), accent, _stroke(0.04), true)
	draw_line(center - Vector2(_unit() * 0.08, 0), string_bottom, accent, _stroke(0.04), true)
	var arrow_start := center - Vector2(_unit() * 0.3, 0.0)
	var arrow_end := center + Vector2(_unit() * 0.36, 0.0)
	draw_line(arrow_start, arrow_end, ink, _stroke(0.055), true)
	_draw_arrow_head(arrow_end, Vector2.RIGHT, ink)


func _draw_assassin(rect: Rect2, ink: Color, accent: Color) -> void:
	draw_line(
		rect.position + rect.size * Vector2(0.28, 0.78),
		rect.position + rect.size * Vector2(0.72, 0.2),
		ink,
		_stroke(0.09),
		true
	)
	draw_line(
		rect.position + rect.size * Vector2(0.25, 0.62),
		rect.position + rect.size * Vector2(0.43, 0.8),
		accent,
		_stroke(0.06),
		true
	)


func _draw_mage(rect: Rect2, ink: Color, accent: Color) -> void:
	var center := rect.get_center()
	var diamond := PackedVector2Array([
		center + Vector2(0.0, -_unit() * 0.35),
		center + Vector2(_unit() * 0.26, 0.0),
		center + Vector2(0.0, _unit() * 0.35),
		center + Vector2(-_unit() * 0.26, 0.0),
		center + Vector2(0.0, -_unit() * 0.35),
	])
	draw_polyline(diamond, ink, _stroke(0.07), true)
	draw_circle(center, _unit() * 0.11, accent)


func _draw_healer(rect: Rect2, ink: Color, accent: Color) -> void:
	var center := rect.get_center()
	draw_line(
		center - Vector2(_unit() * 0.28, 0),
		center + Vector2(_unit() * 0.28, 0),
		ink,
		_stroke(0.1),
		true
	)
	draw_line(
		center - Vector2(0, _unit() * 0.28),
		center + Vector2(0, _unit() * 0.28),
		ink,
		_stroke(0.1),
		true
	)
	draw_arc(center, _unit() * 0.35, 0, TAU, 20, accent, _stroke(0.04), true)


func _draw_pending(
		rect: Rect2,
		ink: Color,
		accent: Color,
		shadow: Color
	) -> void:
	var center := rect.get_center()
	draw_circle(center, _unit() * 0.42, shadow)
	draw_arc(center, _unit() * 0.4, 0, TAU, 24, accent, _stroke(0.07), true)
	draw_line(
		center - Vector2(0, _unit() * 0.2),
		center + Vector2(0, _unit() * 0.08),
		ink,
		_stroke(0.08),
		true
	)
	draw_circle(center + Vector2(0, _unit() * 0.24), _unit() * 0.045, ink)


func _draw_future(rect: Rect2, ink: Color) -> void:
	var center := rect.get_center()
	var diamond := PackedVector2Array([
		center + Vector2(0, -_unit() * 0.28),
		center + Vector2(_unit() * 0.28, 0),
		center + Vector2(0, _unit() * 0.28),
		center + Vector2(-_unit() * 0.28, 0),
		center + Vector2(0, -_unit() * 0.28),
	])
	draw_polyline(diamond, ink, _stroke(0.055), true)


func _draw_generic(rect: Rect2, ink: Color, accent: Color) -> void:
	_draw_future(rect, ink)
	draw_circle(rect.get_center(), _unit() * 0.08, accent)


func _draw_arrow_head(
		point: Vector2,
		direction: Vector2,
		color: Color
	) -> void:
	var normal := Vector2(-direction.y, direction.x)
	var length := _unit() * 0.16
	var wing := _unit() * 0.1
	draw_line(
		point,
		point - direction * length + normal * wing,
		color,
		_stroke(0.055),
		true
	)
	draw_line(
		point,
		point - direction * length - normal * wing,
		color,
		_stroke(0.055),
		true
	)


func _unit() -> float:
	return minf(size.x, size.y)


func _stroke(factor: float) -> float:
	return maxf(1.25, _unit() * factor)


func _theme_color(name: StringName, fallback: Color) -> Color:
	return (
		get_theme_color(name, "SkillTreeGlyphView")
		if has_theme_color(name, "SkillTreeGlyphView")
		else fallback
	)
