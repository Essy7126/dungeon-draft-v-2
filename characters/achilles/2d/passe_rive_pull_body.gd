extends Sprite2D
## SE drawing sequence. A single scale and support anchor across all poses.
const CLIP := "PR_PULL_S25"
const DURATION := .89
const RELEASE := .40
const RELEASE_FRAME := 6
const SUPPORT := Vector2(-18.3333584, 17.19648)
const Appearance := preload("passe_rive_appearance.gd")
var data: Dictionary = { }
var source_frame := 0
var display_scale := .44


func configure(profile: AchillesSpriteVisualProfile) -> void:
	data = JSON.parse_string(
		FileAccess.get_file_as_string("res://assets/characters/PasseRive/sprites_s25/pull.json")
	)
	display_scale = profile.display_scale
	texture = preload("res://assets/characters/PasseRive/sprites_s25/pull.png")
	centered = false
	region_enabled = true
	region_filter_clip_enabled = true
	material = Appearance.material_for("")
	for group in data.palette:
		for field in ["gain", "center"]:
			var rgb: Array = data.palette[group][field]
			material.set_shader_parameter(group + "_" + field, Vector3(rgb[0], rgb[1], rgb[2]))
	material.set_shader_parameter("display_scale", display_scale)
	scale = Vector2.ONE * display_scale * Appearance.SOURCE_HEIGHT / float(data.source_height)
	hide()


func sample(seconds: float) -> void:
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
	position = SUPPORT * display_scale - Vector2(frame.pivot[0], frame.pivot[1]) * scale
	show()


func hand_position() -> Vector2:
	var hand: Array = data.frames[source_frame].hand
	return position + Vector2(hand[0], hand[1]) * scale
