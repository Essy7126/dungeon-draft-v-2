extends Node2D
## Authored body, hand-bound vitality and transient bronze facets share one clock.
const CLIP := "PR_RENEW_S30"
const DURATION := 1.12
const RELEASE := .45
const SHORT_DURATION := .82
const SHORT_RELEASE := .25
const SUPPORT := Vector2(-18.3333584, 17.19648)
const Appearance := preload("passe_rive_appearance.gd")
var catalog: Dictionary = { }
var textures: Dictionary = { }
var facing := ""
var data: Dictionary = { }
var drawing: Sprite2D
var plumes: Array[Sprite2D] = []
var facets: Array[Sprite2D] = []
var display_scale := .44
var compact := false
var painted := false
var seconds := 0.0
var source_frame := 0
var blend := 0.0
var confirmed := false
var healing := 0
var guard_gain := 0
var healing_visible := false
var guard_visible := false


func configure(profile: AchillesSpriteVisualProfile) -> void:
	catalog = JSON.parse_string(
		FileAccess.get_file_as_string(
			"res://assets/characters/PasseRive/sprites_s31_renew/renew.json"
		)
	)
	display_scale = profile.display_scale
	drawing = _sprite(null)
	drawing.material = Appearance.material_for("")
	drawing.material.set_shader_parameter("display_scale", display_scale)
	for direction in catalog.views:
		textures[direction] = load(catalog.views[direction].texture)
	set_facing("SE")
	for i in 2:
		var plume := _sprite(preload("res://assets/characters/PasseRive/sprites_s30/vfx.png"))
		# Sibling order keeps the light behind the body without putting it below tiles.
		move_child(plume, 0)
		plumes.append(plume)
	for i in 3:
		var facet := _sprite(preload("res://assets/characters/PasseRive/sprites_s30/vfx.png"))
		if i == 1:
			move_child(facet, 0)
		facets.append(facet)
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


func _sprite(atlas: Texture2D) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = atlas
	sprite.centered = false
	sprite.region_enabled = true
	sprite.region_filter_clip_enabled = true
	add_child(sprite)
	return sprite


func reset(short_version := false) -> void:
	compact = short_version
	seconds = 0.0
	confirmed = false
	healing = 0
	guard_gain = 0
	healing_visible = false
	guard_visible = false
	for sprite in plumes + facets:
		sprite.hide()
	hide()


func duration() -> float:
	return SHORT_DURATION if compact else DURATION


func release_time() -> float:
	return SHORT_RELEASE if compact else RELEASE


func confirm_result(actual_healing: int, actual_guard: int) -> bool:
	if not visible or confirmed or seconds + .000001 < release_time():
		return false
	confirmed = true
	healing = maxi(0, actual_healing)
	guard_gain = maxi(0, actual_guard)
	_update_effects()
	return true


func sample(at: float, direction: String = "SE") -> float:
	seconds = at
	set_facing(direction)
	painted = true
	var sequence: Array = data.short_sequence if compact else data.sequence
	var durations: Array = data.short_duration_ms if compact else data.duration_ms
	var end := 0.0
	source_frame = int(sequence.back())
	for i in sequence.size():
		end += float(durations[i]) / 1000.0
		if at < end - .000001:
			source_frame = int(sequence[i])
			break
	var frame: Dictionary = data.frames[source_frame]
	_region(drawing, frame)
	drawing.position = Vector2(data.support[0], data.support[1]) * display_scale - Vector2(
		frame.pivot[0],
		frame.pivot[1],
	) * drawing.scale
	blend = smoothstep(0.0, .09, at) * (1.0 - smoothstep(duration() - .17, duration() - .04, at))
	drawing.self_modulate.a = blend
	drawing.visible = painted and blend > 0.0
	_update_effects()
	show()
	return 1.0 - blend


func hand_position(index := 0) -> Vector2:
	if not painted:
		return Vector2(-55 if index == 0 else 55, -115) * display_scale
	var hand: Array = data.frames[source_frame].hands[index]
	return drawing.position + Vector2(hand[0], hand[1]) * drawing.scale


func _region(sprite: Sprite2D, frame: Dictionary) -> void:
	var r: Array = frame.region
	sprite.region_rect = Rect2(r[0], r[1], r[2], r[3])


func _update_effects() -> void:
	var after := seconds - release_time()
	var gathering := seconds >= .10 and after < 0.0
	healing_visible = confirmed and healing > 0 and after >= 0.0 and after < .34
	var plume_frame := 0 if seconds < release_time() * .65 else 1
	if after >= 0.0:
		plume_frame = 2 if after < .16 else 3
	for i in plumes.size():
		var sprite := plumes[i]
		sprite.visible = gathering or healing_visible
		if not sprite.visible:
			continue
		_region(sprite, data.vfx.frames[plume_frame])
		var base := Vector2(-25 if i == 0 else 30, 10) * display_scale
		var ray := hand_position(i) - base
		var angle := ray.angle() + PI * .5
		var amplitude := .78 if compact else 1.0
		var factor := Vector2(
			display_scale * .25 * amplitude,
			ray.length() / float(data.vfx.plume_height),
		)
		if i == 0:
			factor.x *= -1.0
		var anchor: Array = data.vfx.plume_anchor
		if plume_frame > 0:
			# Fit the drawn tip to the hand, accounting for the source plume's curve.
			var row: Dictionary = data.vfx.frames[plume_frame]
			anchor = row.base
			var authored := Vector2(row.tip[0] - anchor[0], row.tip[1] - anchor[1])
			var lateral := authored.x * factor.x
			factor.y = sqrt(maxf(.001, ray.length_squared() - lateral * lateral)) / absf(authored.y)
			angle = ray.angle() - (authored * factor).angle()
		var x := Vector2(factor.x, 0).rotated(angle)
		var y := Vector2(0, factor.y).rotated(angle)
		sprite.transform = Transform2D(x, y, base - x * float(anchor[0]) - y * float(anchor[1]))
		sprite.self_modulate.a = (
			.45 * smoothstep(.10, .20, seconds)
			if gathering
			else 1.0 - smoothstep(.20, .34, after)
		)
	guard_visible = confirmed and guard_gain > 0 and after >= .10 and seconds < duration() - .025
	var guard_time := maxf(0.0, after - .10)
	var facet_frame := 4 if guard_time < .065 else (5 if guard_time < .14 else 6)
	if seconds > duration() - .15:
		facet_frame = 7
	var placements := [Vector2(-64, -102), Vector2(62, -120), Vector2(25, -53)]
	for i in facets.size():
		var sprite := facets[i]
		sprite.visible = guard_visible
		if not sprite.visible:
			continue
		_region(sprite, data.vfx.frames[facet_frame])
		var factor := display_scale * Appearance.SOURCE_HEIGHT * (.16 if compact else .21) / float(
			data.vfx.facet_height
		)
		var direction := -1.0 if i == 1 else 1.0
		var angle := -.55 if i == 2 else (.1 if i == 0 else -.2)
		var x := Vector2(factor * direction, 0).rotated(angle)
		var y := Vector2(0, factor).rotated(angle)
		var center: Array = data.vfx.facet_center
		var position: Vector2 = placements[i] * display_scale
		position.x *= lerpf(1.14, 1.0, smoothstep(0.0, .20, guard_time))
		sprite.transform = Transform2D(x, y, position - x * float(center[0]) - y * float(center[1]))
		sprite.self_modulate.a = smoothstep(0.0, .06, guard_time) * (
			1.0 - smoothstep(duration() - .16, duration() - .025, seconds)
		)
