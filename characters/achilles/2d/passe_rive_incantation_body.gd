extends Sprite2D
## Approved SE ritual, with one fixed projection calibration for the whole atlas.
const CLIP := "PR_INCANTATION_S26"
const DURATION := 1.15
const RELEASE := 0.59
const RELEASE_FRAME := 6
const SUPPORT := Vector2(-18.3333584, 17.19648)
const WIDTH_FACTOR := 0.80
const Appearance := preload("passe_rive_appearance.gd")
var data: Dictionary = { }
var source_frame := 0
var display_scale := 0.44


func configure(profile: AchillesSpriteVisualProfile) -> void:
	data = JSON.parse_string(
		FileAccess.get_file_as_string(
			"res://assets/characters/PasseRive/sprites_s26/incantation.json"
		)
	)
	display_scale = profile.display_scale
	texture = preload("res://assets/characters/PasseRive/sprites_s26/incantation.png")
	centered = false
	region_enabled = true
	region_filter_clip_enabled = true
	material = Appearance.material_for("")
	for group in data.palette:
		for field in ["gain", "center"]:
			var rgb: Array = data.palette[group][field]
			material.set_shader_parameter(group + "_" + field, Vector3(rgb[0], rgb[1], rgb[2]))
	material.set_shader_parameter("display_scale", display_scale)
	# Fixed correction of the wider painted projection, never a per-pose fit.
	scale = Vector2(WIDTH_FACTOR, 1.0) * display_scale * Appearance.SOURCE_HEIGHT / float(
		data.source_height
	)
	hide()


func sample(seconds: float) -> void:
	var end := 0.0
	var index: int = data.sequence.size() - 1
	for i in data.sequence.size():
		end += float(data.duration_ms[i]) / 1000.0
		if seconds < end - 0.000001:
			index = i
			break
	source_frame = int(data.sequence[index])
	var frame: Dictionary = data.frames[source_frame]
	var region: Array = frame.region
	region_rect = Rect2(region[0], region[1], region[2], region[3])
	position = SUPPORT * display_scale - Vector2(frame.pivot[0], frame.pivot[1]) * scale
	show()


func hand_position() -> Vector2:
	var hand: Array = data.frames[source_frame].hands[1]
	return position + Vector2(hand[0], hand[1]) * scale
