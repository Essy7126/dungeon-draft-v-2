extends Sprite2D
## Eight authored views with fixed anatomy, registered soles and active-hand sockets.
const CLIP := "PR_GUARD_S27"
const DURATION := .72
const RELEASE := .24
const RELEASE_FRAME := 5
const WIDTH_FACTOR := .93
const SUPPORT := Vector2(-18.3333584, 17.19648)
const Appearance := preload("passe_rive_appearance.gd")
const PATH := "res://assets/characters/PasseRive/sprites_s31_guard/guard.json"
const Ward := preload("res://vfx/class_cards/passe_rive_guard_ward.gd")
var seconds := 0.0
var ward: Node2D
var ward_confirmed := false
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
	ward = Ward.new()
	add_child(ward)
	reset_ward()
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


func sample(at: float, direction: String = "SE") -> float:
	seconds = at
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
	blend = smoothstep(0.0, .03, seconds) * (1.0 - smoothstep(.62, DURATION, seconds))
	self_modulate.a = blend
	show()
	_update_ward()
	return 1.0 - blend


func hand_position() -> Vector2:
	var hand: Array = data.frames[source_frame].hand
	return position + Vector2(hand[0], hand[1]) * scale


func reset_ward() -> void:
	ward_confirmed = false
	if is_instance_valid(ward):
		ward.hide()


func confirm_ward() -> void:
	if not visible or seconds < RELEASE or ward_confirmed:
		return
	ward_confirmed = true
	_update_ward()


func _update_ward() -> void:
	var angle := float(data.ward_angle)
	# Keep the approved SE arc's physical size independent of each drawing's pixel size.
	var canonical_scale := Vector2(WIDTH_FACTOR, 1.0) * display_scale * Appearance.SOURCE_HEIGHT / 336.0
	var offset := (Vector2(9.0, 22.0) * canonical_scale).rotated(angle)
	var target := Transform2D(angle, canonical_scale, 0.0, hand_position() + offset)
	ward.transform = transform.affine_inverse() * target
	ward.sample(seconds - RELEASE, ward_confirmed)
