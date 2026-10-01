extends Node2D
## Recentrage: authored body and confirmed draw glyphs on the same action clock.
const CLIP := "PR_RECENTER_S32"
const DURATION := .8
const RELEASE := .36
const RELEASE_FRAME := 6
const Appearance := preload("passe_rive_appearance.gd")
var catalog: Dictionary = { }
var textures: Dictionary = { }
var facing := ""
var data: Dictionary = { }
var drawing: Sprite2D
var glyphs: Array[Sprite2D] = []
var display_scale := .44
var seconds := 0.0
var source_frame := 0
var blend := 0.0
var confirmed := false
var drawn := 0
var glyph_count := 0


func configure(profile: AchillesSpriteVisualProfile) -> void:
	catalog = JSON.parse_string(
		FileAccess.get_file_as_string("res://assets/characters/PasseRive/sprites_s32/recenter.json")
	)
	display_scale = profile.display_scale
	drawing = Sprite2D.new()
	drawing.centered = false
	drawing.region_enabled = true
	drawing.region_filter_clip_enabled = true
	drawing.material = Appearance.material_for("")
	drawing.material.set_shader_parameter("display_scale", display_scale)
	add_child(drawing)
	for direction in catalog.views:
		textures[direction] = load(catalog.views[direction].texture)
	for i in 3:
		var glyph := Sprite2D.new()
		glyph.texture = preload("res://assets/characters/PasseRive/sprites_s32/glyph.png")
		glyph.scale = Vector2.ONE * display_scale * 22.0 / float(catalog.glyph_height)
		add_child(glyph)
		glyphs.append(glyph)
	set_facing("SE")
	reset()


func set_facing(direction: String) -> void:
	if direction == facing:
		return
	facing = direction if catalog.views.has(direction) else "SE"
	data = catalog.views[facing]
	drawing.texture = textures[facing]
	Appearance.apply_palette(drawing.material, "")
	for group in data.palette:
		for field in ["gain", "center"]:
			var rgb: Array = data.palette[group][field]
			drawing.material.set_shader_parameter(
				group + "_" + field,
				Vector3(rgb[0], rgb[1], rgb[2]),
			)
	drawing.scale = Vector2(float(data.width_factor), 1.0) * display_scale * Appearance.SOURCE_HEIGHT / float(
		data.source_height
	)
	# Front-facing hands are occluded in the three rear views, as on the drawings.
	for glyph in glyphs:
		move_child(glyph, 0 if facing in ["N", "NE", "NW"] else get_child_count() - 1)


func reset() -> void:
	seconds = 0.0
	confirmed = false
	drawn = 0
	glyph_count = 0
	for glyph in glyphs:
		glyph.hide()
	hide()


func confirm_result(actual_draw: int) -> bool:
	if not visible or confirmed or seconds + .000001 < RELEASE:
		return false
	confirmed = true
	drawn = clampi(actual_draw, 0, 3)
	_update_effects()
	return true


func sample(at: float, direction: String) -> float:
	seconds = at
	set_facing(direction)
	var edge := 0.0
	source_frame = int(data.sequence.back())
	for i in data.sequence.size():
		edge += float(data.duration_ms[i]) / 1000.0
		if at < edge - .000001:
			source_frame = int(data.sequence[i])
			break
	var frame: Dictionary = data.frames[source_frame]
	var r: Array = frame.region
	drawing.region_rect = Rect2(r[0], r[1], r[2], r[3])
	drawing.position = Vector2(data.support[0], data.support[1]) * display_scale - Vector2(
		frame.pivot[0],
		frame.pivot[1],
	) * drawing.scale
	blend = smoothstep(0.0, .065, at) * (1.0 - smoothstep(.72, .78, at))
	drawing.self_modulate.a = blend
	drawing.visible = blend > 0.0
	_update_effects()
	show()
	return 1.0 - blend


func hand_position() -> Vector2:
	var hand: Array = data.frames[source_frame].hand
	return drawing.position + Vector2(hand[0], hand[1]) * drawing.scale


func _update_effects() -> void:
	var after := seconds - RELEASE
	glyph_count = drawn if confirmed and after >= 0.0 and after < .30 else 0
	for i in glyphs.size():
		var glyph := glyphs[i]
		glyph.visible = i < glyph_count
		if not glyph.visible:
			continue
		var phase := clampf(after / .30, 0.0, 1.0)
		var side := -1.0 if facing in ["W", "SW", "NW"] else 1.0
		var spread := (float(i) - float(drawn - 1) * .5) * 26.0
		var offset := Vector2(
			side * (spread + 8.0 * sin(phase * PI)),
			-34.0 - 9.0 * sin(phase * PI + float(i)),
		)
		glyph.position = hand_position() + offset * display_scale * (
			1.0 - smoothstep(.10, 1.0, phase)
		)
		glyph.rotation = side * (.12 + .3 * sin(phase * PI + float(i)))
		glyph.self_modulate.a = smoothstep(0.0, .035, after) * (1.0 - smoothstep(.20, .30, after))
