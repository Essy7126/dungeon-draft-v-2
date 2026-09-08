extends "res://hub/sanctuary_prototype/sanctuary_player.gd"

## Hall presentation only. The map owns movement and keeps this root on the floor.
## Authored 243–257 px idle silhouettes become 126–134 native map pixels.
const HALL_TINT := preload("res://tools/labs/apothecary_living_map/hall_actor_tint.gdshader")
const HALF_STRIDE_NATIVE := 38.0
const LANTERN_POSITIONS := [
	Vector2(343, 358), Vector2(578, 275), Vector2(625, 230),
	Vector2(835, 244), Vector2(893, 277), Vector2(1055, 349),
]

var _hall_material: ShaderMaterial
var _warm_light := 0.0
var _cool_light := 0.0
var _walking := false
var _ground_stride := 0.0


func _init() -> void:
	display_scale = 0.52
	isometric_vertical_ratio = 0.50
	initial_facing = "S"


func _ready() -> void:
	super._ready()
	if not is_visual_ready():
		return
	# Map displacement owns the walk clock, including pause and movie recording.
	_backend.set_process(false)
	# Replace the shared backend's small hard ellipse locally; never stack shadows.
	var original_shadow := _backend.get_node_or_null("ContactShadow") as CanvasItem
	if original_shadow != null:
		original_shadow.hide()
	_hall_material = ShaderMaterial.new()
	_hall_material.shader = HALL_TINT
	_hall_material.set_shader_parameter("display_scale", display_scale)
	_backend.animated_sprite.material = _hall_material
	set_environment_time(0.0, position)
	queue_redraw()


func play_walk(direction := Vector2.ZERO) -> bool:
	var started := super.play_walk(direction)
	if started and not _walking:
		_ground_stride = 0.0
		_backend.update_movement_stride(0, 0.0)
	_walking = started
	return started


## Distance must be measured on the floor: length(Vector2(dx, dy / 0.5)).
func advance_ground_stride(distance: float) -> void:
	if not _walking or not is_visual_ready() or not is_finite(distance):
		return
	_ground_stride += maxf(distance, 0.0)
	var half_steps := _ground_stride / HALF_STRIDE_NATIVE
	_backend.update_movement_stride(floori(half_steps), fposmod(half_steps, 1.0))


func play_idle() -> bool:
	_walking = false
	_ground_stride = 0.0
	return super.play_idle()


func cancel_movement_feedback() -> void:
	_walking = false
	_ground_stride = 0.0
	super.cancel_movement_feedback()


func _draw() -> void:
	if not is_visual_ready():
		return
	# Nested translucent ellipses give a feathered contact shadow without an asset.
	# The fixed ground anchor never inherits the animation's changes of pose.
	var relative_scale := display_scale / 0.52
	for layer in 14:
		var radius := lerpf(22.0, 3.0, float(layer) / 13.0) * relative_scale
		var points := PackedVector2Array()
		for point in 48:
			var angle := TAU * float(point) / 48.0
			points.append(Vector2(2.0 + cos(angle) * radius, -1.8 + sin(angle) * radius * 0.29))
		draw_colored_polygon(points, Color(0.022, 0.044, 0.037, 0.023))


## Pixel coordinates refer to the 1376 × 768 painting, independent of camera zoom.
## A paused scene may pass the same time repeatedly: no autonomous flicker clock.
func set_environment_time(time_seconds: float, position_native: Vector2) -> void:
	if _hall_material == null:
		return
	var torso := position_native + Vector2(0.0, -67.0)
	var warm_total := 0.0
	var warm_direction := 0.0
	for index in LANTERN_POSITIONS.size():
		var lantern: Vector2 = LANTERN_POSITIONS[index]
		var offset := (torso - lantern) / Vector2(205.0, 168.0)
		var influence := pow(maxf(0.0, 1.0 - offset.length()), 1.4)
		var flicker := 0.95 + 0.035 * sin(time_seconds * 5.1 + float(index) * 1.7) \
			+ 0.015 * sin(time_seconds * 9.7 + float(index) * 2.3)
		var light := influence * flicker
		warm_total += light
		warm_direction += clampf((lantern.x - torso.x) / 90.0, -1.0, 1.0) * light
	_warm_light = clampf(warm_total, 0.0, 1.0)
	warm_direction /= maxf(warm_total, 0.001)
	var fountain_offset := (position_native - Vector2(635.0, 486.0)) / Vector2(260.0, 190.0)
	var fountain := pow(maxf(0.0, 1.0 - fountain_offset.length()), 1.3)
	var foreground_water := smoothstep(625.0, 805.0, position_native.y) * 0.38
	var orb_offset := (torso - Vector2(962.0, 328.0)) / Vector2(160.0, 145.0)
	var orb := maxf(0.0, 1.0 - orb_offset.length()) * 0.35
	_cool_light = clampf(fountain + foreground_water + orb, 0.0, 1.0)
	_hall_material.set_shader_parameter("warm_light", _warm_light)
	_hall_material.set_shader_parameter("warm_direction", warm_direction)
	_hall_material.set_shader_parameter("cool_light", _cool_light)


func get_visual_state() -> Dictionary:
	var state := super.get_visual_state()
	state["display_scale"] = display_scale
	state["isometric_vertical_ratio"] = isometric_vertical_ratio
	state["hall_lighting"] = _hall_material != null
	state["warm_light"] = _warm_light
	state["cool_light"] = _cool_light
	state["ground_stride"] = _ground_stride
	return state
