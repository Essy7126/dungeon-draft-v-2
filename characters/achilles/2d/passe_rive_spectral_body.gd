extends Node2D
## Body and veil share one clock; only confirmed relocation permits the arrival.
const CLIP := "PR_SPECTRAL_S29"
const DURATION := 0.86
const RELEASE := 0.31
const RELEASE_FRAME := 5
const SUPPORT := Vector2(-18.3333584, 17.19648)
const Appearance := preload("passe_rive_appearance.gd")
var catalog: Dictionary = { }
var textures: Dictionary = { }
var facing := ""
var data: Dictionary = { }
var drawing: Sprite2D
var veil: Sprite2D
var source_frame := 0
var seconds := 0.0
var display_scale := 0.44
var painted := false
var arrival_confirmed := false
var body_alpha := 1.0
var native_weight := 1.0
var veil_frame := -1


func configure(profile: AchillesSpriteVisualProfile) -> void:
	catalog = JSON.parse_string(
		FileAccess.get_file_as_string(
			"res://assets/characters/PasseRive/sprites_s31_spectral/passage.json"
		)
	)
	display_scale = profile.display_scale
	drawing = _sprite(null)
	drawing.material = Appearance.material_for("")
	drawing.material.set_shader_parameter("display_scale", display_scale)
	for direction in catalog.views:
		textures[direction] = load(catalog.views[direction].texture)
	set_facing("SE")
	veil = _sprite(preload("res://assets/characters/PasseRive/sprites_s29/veil.png"))
	veil.scale = Vector2.ONE * display_scale * Appearance.SOURCE_HEIGHT / float(
		data.veil.source_height
	)
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
	var node := Sprite2D.new()
	node.texture = atlas
	node.centered = false
	node.region_enabled = true
	node.region_filter_clip_enabled = true
	add_child(node)
	return node


func reset() -> void:
	arrival_confirmed = false
	seconds = 0.0
	body_alpha = 1.0
	native_weight = 1.0
	veil_frame = -1
	if is_instance_valid(veil):
		veil.hide()
	hide()


func sample(at: float, direction: String = "SE") -> float:
	seconds = at
	set_facing(direction)
	painted = true
	var end := 0.0
	source_frame = data.frames.size() - 1
	for i in data.duration_ms.size():
		end += float(data.duration_ms[i]) / 1000.0
		if at < end - .000001:
			source_frame = i
			break
	body_alpha = 1.0 - smoothstep(.21, .29, at)
	if at >= .37:
		body_alpha = smoothstep(.37, .49, at) if arrival_confirmed else 0.0
	# A cancelled/failed relocation cannot strand an invisible character.
	# Restore the original idle without claiming a successful arrival.
	if not arrival_confirmed and at >= .62:
		body_alpha = smoothstep(.62, .80, at)
	var blend := smoothstep(0.0, .09, at) * (1.0 - smoothstep(.68, .81, at))
	if not painted or (not arrival_confirmed and at >= .62):
		blend = 0.0
	native_weight = (1.0 - blend) * body_alpha
	_place(drawing, data.frames[source_frame])
	drawing.self_modulate.a = blend * body_alpha
	drawing.visible = painted and drawing.self_modulate.a > 0.0
	veil_frame = _veil_at(at)
	veil.visible = veil_frame >= 0
	if veil.visible:
		_place(veil, data.veil.frames[veil_frame])
		veil.self_modulate.a = 1.0 - smoothstep(.70, .84, at)
	show()
	return native_weight


func _place(sprite: Sprite2D, frame: Dictionary) -> void:
	var region: Array = frame.region
	sprite.region_rect = Rect2(region[0], region[1], region[2], region[3])
	var support := Vector2(data.support[0], data.support[1]) if sprite == drawing else SUPPORT
	sprite.position = support * display_scale - Vector2(frame.pivot[0], frame.pivot[1]) * sprite.scale


func _veil_at(at: float) -> int:
	if at < .12 or at >= .84:
		return -1
	if at < .18:
		return 0
	if at < .23:
		return 1
	if at < .28:
		return 2
	if at < RELEASE:
		return 3
	if at < .37:
		return 4
	if not arrival_confirmed:
		return 4 if at < .50 else -1
	if at < .51:
		return 5
	if at < .68:
		return 6
	return 7
