extends Sprite2D
## Registered drain poses; confirmed damage and healing only affect presentation.
const CLIP := "PR_DRAIN_S28"
const DURATION := 0.94
const RELEASE := 0.33
const RELEASE_FRAME := 5
const SUPPORT := Vector2(-18.3333584, 17.19648)
const WIDTH_FACTOR := 0.84
const Appearance := preload("passe_rive_appearance.gd")
const Siphon := preload("res://vfx/class_cards/passe_rive_drain_siphon.gd")
var data: Dictionary = { }
var source_frame := 0
var display_scale := 0.44
var seconds := 0.0
var siphon: Node2D
var siphon_confirmed := false
var target_global := Vector2.ZERO
var hp_damage := 0
var hp_healing := 0


func configure(profile: AchillesSpriteVisualProfile) -> void:
	data = JSON.parse_string(
		FileAccess.get_file_as_string("res://assets/characters/PasseRive/sprites_s28/drain.json")
	)
	display_scale = profile.display_scale
	texture = preload("res://assets/characters/PasseRive/sprites_s28/drain.png")
	centered = false
	region_enabled = true
	region_filter_clip_enabled = true
	material = Appearance.material_for("")
	for group in data.palette:
		for field in ["gain", "center"]:
			var rgb: Array = data.palette[group][field]
			material.set_shader_parameter(group + "_" + field, Vector3(rgb[0], rgb[1], rgb[2]))
	material.set_shader_parameter("display_scale", display_scale)
	scale = Vector2(WIDTH_FACTOR, 1.0) * display_scale * Appearance.SOURCE_HEIGHT / float(
		data.source_height
	)
	siphon = Siphon.new()
	add_child(siphon)
	reset_siphon()
	hide()


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


func sample(at: float) -> void:
	seconds = at
	var end := 0.0
	var index: int = data.sequence.size() - 1
	for i in data.sequence.size():
		end += float(data.duration_ms[i]) / 1000.0
		if at < end - 0.000001:
			index = i
			break
	source_frame = int(data.sequence[index])
	var frame: Dictionary = data.frames[source_frame]
	var region: Array = frame.region
	region_rect = Rect2(region[0], region[1], region[2], region[3])
	position = SUPPORT * display_scale - Vector2(frame.pivot[0], frame.pivot[1]) * scale
	show()
	_update_siphon()


func hand_position() -> Vector2:
	var hand: Array = data.frames[source_frame].hands[0]
	return position + Vector2(hand[0], hand[1]) * scale


func _update_siphon() -> void:
	var hand: Array = data.frames[source_frame].hands[0]
	siphon.sample(
		seconds - RELEASE,
		siphon_confirmed and hp_damage > 0,
		hp_healing > 0,
		to_local(target_global),
		Vector2(hand[0], hand[1]),
	)
