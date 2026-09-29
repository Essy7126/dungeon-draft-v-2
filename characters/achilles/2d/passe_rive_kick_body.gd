extends Sprite2D
## One fixed anatomical scale per authored view, with registered supporting soles.
const Appearance := preload("passe_rive_appearance.gd")
const PATH := "res://assets/characters/PasseRive/sprites_s31_kick/kick.json"
var catalog: Dictionary = { }
var data: Dictionary = { }
var textures: Dictionary = { }
var source_frame := 0
var display_scale := 0.44
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


func sample_frame(frame: int, direction: String, seconds: float = -1.0) -> float:
	set_facing(direction)
	source_frame = int(data.sequence[frame])
	var pose: Dictionary = data.frames[source_frame]
	var region: Array = pose.region
	region_rect = Rect2(region[0], region[1], region[2], region[3])
	position = Vector2(data.support[0], data.support[1]) * display_scale - Vector2(
		pose.pivot[0],
		pose.pivot[1],
	) * scale
	blend = 1.0
	if seconds >= 0.0:
		blend = smoothstep(0.0, 0.06, seconds) * (1.0 - smoothstep(0.55, 0.65, seconds))
	self_modulate.a = blend
	show()
	return 1.0 - blend


func heel_position() -> Vector2:
	var pivot: Array = data.frames[4].pivot
	return Vector2(data.support[0], data.support[1]) * display_scale + (
		Vector2(data.contact[0], data.contact[1]) - Vector2(pivot[0], pivot[1])
	) * scale
