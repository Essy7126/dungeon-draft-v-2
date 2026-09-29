extends Sprite2D
## Eight authored views with fixed anatomy, registered soles and active-hand sockets.
const CLIP := "PR_DRAIN_S28"
const DURATION := .94
const RELEASE := .33
const RELEASE_FRAME := 5
const WIDTH_FACTOR := .84
const SUPPORT := Vector2(-18.3333584, 17.19648)
const Appearance := preload("passe_rive_appearance.gd")
const PATH := "res://assets/characters/PasseRive/sprites_s31_drain/drain.json"
const Siphon := preload("res://vfx/class_cards/passe_rive_drain_siphon.gd")
var seconds := 0.0
var siphon: Node2D
var siphon_confirmed := false
var target_global := Vector2.ZERO
var hp_damage := 0
var hp_healing := 0
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
	siphon = Siphon.new()
	add_child(siphon)
	reset_siphon()
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
	blend = smoothstep(0.0, .04, seconds) * (1.0 - smoothstep(.84, DURATION, seconds))
	self_modulate.a = blend
	show()
	_update_siphon()
	return 1.0 - blend


func hand_position() -> Vector2:
	var hand: Array = data.frames[source_frame].hand
	return position + Vector2(hand[0], hand[1]) * scale


func reset_siphon() -> void:
	siphon_confirmed = false
	hp_damage = 0
	hp_healing = 0
	if is_instance_valid(siphon):
		siphon.hide()


func confirm_siphon(point: Vector2, damage: int, healing: int) -> void:
	if not visible or seconds < RELEASE or siphon_confirmed:
		return
	siphon_confirmed = true
	target_global = point
	hp_damage = maxi(damage, 0)
	hp_healing = maxi(healing, 0) if hp_damage > 0 else 0
	_update_siphon()


func _update_siphon() -> void:
	# Keep stroke width and curvature independent of source sprite resolution.
	var canonical := Transform2D(
		0.0,
		Vector2(WIDTH_FACTOR, 1.0) * display_scale * Appearance.SOURCE_HEIGHT / 343.0,
		0.0,
		Vector2.ZERO,
	)
	siphon.transform = transform.affine_inverse() * canonical
	var hand_global: Vector2 = get_parent().to_global(hand_position())
	siphon.sample(
		seconds - RELEASE,
		siphon_confirmed and hp_damage > 0,
		hp_healing > 0,
		siphon.to_local(target_global),
		siphon.to_local(hand_global),
	)
