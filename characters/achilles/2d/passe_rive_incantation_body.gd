extends Sprite2D
## Eight authored views with fixed anatomy, registered soles and active-hand sockets.
const CLIP := "PR_INCANTATION_S26"
const DURATION := 1.15
const RELEASE := .59
const RELEASE_FRAME := 6
const WIDTH_FACTOR := .80
const SUPPORT := Vector2(-18.3333584, 17.19648)
const Appearance := preload("passe_rive_appearance.gd")
const PATH := "res://assets/characters/PasseRive/sprites_s31_incantation/incantation.json"
var catalog: Dictionary = { }
var data: Dictionary = { }
var textures: Dictionary = { }
var source_frame := 0
var display_scale := .44
var facing := ""
var blend := 1.0


func configure(profile: AchillesSpriteVisualProfile) -> void:
	catalog = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	display_scale = profile.display_scale
	centered = false
	region_enabled = true
	region_filter_clip_enabled = true
	material = Appearance.material_for("")
	material.set_shader_parameter("display_scale", display_scale)
	for direction in catalog.views:
		textures[direction] = load(catalog.views[direction].texture)
	set_facing("SE")
	hide()


func set_facing(direction: String) -> void:
	if direction == facing:
		return
	facing = direction if catalog.views.has(direction) else "SE"
	data = catalog.views[facing]
	texture = textures[facing]
	Appearance.apply_palette(material, "")
	for group in data.palette:
		for field in ["gain", "center"]:
			var rgb: Array = data.palette[group][field]
			material.set_shader_parameter(group + "_" + field, Vector3(rgb[0], rgb[1], rgb[2]))
	scale = Vector2(float(data.width_factor), 1.0) * display_scale * Appearance.SOURCE_HEIGHT / float(
		data.source_height
	)


func sample(seconds: float, direction: String = "SE") -> float:
	set_facing(direction)
	var end := 0.0
	var index: int = data.sequence.size() - 1
	for i in data.sequence.size():
		end += float(data.duration_ms[i]) / 1000.0
		if seconds < end - .000001:
			index = i
			break
	source_frame = int(data.sequence[index])
	var frame: Dictionary = data.frames[source_frame]
	var region: Array = frame.region
	region_rect = Rect2(region[0], region[1], region[2], region[3])
	position = Vector2(data.support[0], data.support[1]) * display_scale - Vector2(
		frame.pivot[0],
		frame.pivot[1],
	) * scale
	blend = smoothstep(0.0, .06, seconds) * (1.0 - smoothstep(1.05, DURATION, seconds))
	self_modulate.a = blend
	show()
	return 1.0 - blend


func hand_position() -> Vector2:
	var hand: Array = data.frames[source_frame].hand
	return position + Vector2(hand[0], hand[1]) * scale
