extends Node2D

## Thin vapor and sparse motes aligned to the original 1376 x 768 painting.
## The owner supplies time and scales this node together with the background.
const STEAM_SHADER: Shader = preload("res://tools/labs/apothecary_living_map/steam.gdshader")
const MOTE_ANCHORS: Array[Vector2] = [
	Vector2(319, 303), Vector2(438, 258), Vector2(575, 302),
	Vector2(660, 175), Vector2(739, 332), Vector2(852, 219),
	Vector2(927, 299), Vector2(1041, 361), Vector2(1104, 448),
	Vector2(1027, 516), Vector2(922, 550), Vector2(836, 433),
	Vector2(745, 506), Vector2(646, 393), Vector2(522, 492),
	Vector2(399, 449), Vector2(516, 591), Vector2(700, 628),
]
const BUBBLE_ANCHORS: Array[Vector2] = [
	Vector2(770, 269), Vector2(814, 282), Vector2(858, 269),
	Vector2(894, 285), Vector2(801, 260), Vector2(868, 288),
]

var _effect_time: float = 0.0
var _strength: float = 1.0
var _effects_enabled: bool = true
var _water_enabled: bool = true
var _steam_materials: Array[ShaderMaterial] = []
var _water_vapor: Array[ColorRect] = []


func _ready() -> void:
	# The bottom edges stop inside the basin, behind its painted front rim.
	_water_vapor.append(_add_vapor(
		Rect2(725, 176, 138, 100), Color(0.64, 0.94, 0.88, 0.13), 0.0
	))
	_water_vapor.append(_add_vapor(
		Rect2(835, 195, 126, 86), Color(0.64, 0.94, 0.88, 0.105), 3.6
	))
	# A faint wisp at the copper tube joint, rather than a smoking vessel.
	_add_vapor(Rect2(1047, 246, 71, 78), Color(0.94, 0.85, 0.68, 0.075), 8.4)
	set_effect_state(_effect_time, _strength, _effects_enabled, _water_enabled)


func set_effect_state(
	time_seconds: float,
	strength: float,
	enabled: bool,
	water_enabled: bool = true
) -> void:
	_effect_time = time_seconds
	_strength = clampf(strength, 0.0, 2.0)
	_effects_enabled = enabled
	_water_enabled = water_enabled
	visible = _effects_enabled and _strength > 0.0
	for vapor_material in _steam_materials:
		vapor_material.set_shader_parameter("effect_time", _effect_time)
		vapor_material.set_shader_parameter("effect_strength", _strength)
	for vapor in _water_vapor:
		vapor.visible = _water_enabled
	queue_redraw()


func _add_vapor(bounds: Rect2, tint: Color, phase: float) -> ColorRect:
	var vapor := ColorRect.new()
	vapor.position = bounds.position
	vapor.size = bounds.size
	vapor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vapor_material := ShaderMaterial.new()
	vapor_material.shader = STEAM_SHADER
	vapor_material.set_shader_parameter("vapor_color", tint)
	vapor_material.set_shader_parameter("phase", phase)
	vapor.material = vapor_material
	add_child(vapor)
	_steam_materials.append(vapor_material)
	return vapor


func _draw() -> void:
	if not _effects_enabled or _strength <= 0.0:
		return
	_draw_motes()
	if _water_enabled:
		_draw_bubbles()


func _draw_motes() -> void:
	for index in MOTE_ANCHORS.size():
		var phase: float = float(index) * 2.39996
		var cycle: float = fposmod(_effect_time * (0.027 + float(index % 4) * 0.003) + phase, 1.0)
		var fade: float = sin(cycle * PI)
		fade *= fade
		var mote_position: Vector2 = MOTE_ANCHORS[index] + Vector2(
			sin(_effect_time * 0.14 + phase) * 16.0 + cos(_effect_time * 0.07 + phase) * 7.0,
			(0.5 - cycle) * 41.0
		)
		var near_water: bool = index >= 4 and index <= 6
		var tint: Color = Color(0.56, 0.94, 0.88) if near_water else Color(1.0, 0.80, 0.48)
		var radius: float = 0.55 + float(index % 3) * 0.17
		# A soft, tiny skirt makes the core readable without a hard halo.
		tint.a = fade * 0.07 * _strength
		draw_circle(mote_position, radius * 2.2, tint, true, -1.0, true)
		tint.a = fade * 0.33 * _strength
		draw_circle(mote_position, radius, tint, true, -1.0, true)


func _draw_bubbles() -> void:
	for index in BUBBLE_ANCHORS.size():
		var phase: float = float(index) * 0.174
		var cycle: float = fposmod(_effect_time / 8.7 + phase, 1.0)
		# Each surface bubble appears for less than a second every 8.7 seconds.
		if cycle > 0.11:
			continue
		var age: float = cycle / 0.11
		var radius: float = lerpf(0.8, 3.8, age)
		var alpha: float = sin(age * PI) * (1.0 - age) * 0.24 * _strength
		var ring := PackedVector2Array()
		for point_index in 17:
			var angle: float = float(point_index) / 16.0 * TAU
			ring.append(BUBBLE_ANCHORS[index] + Vector2(cos(angle) * radius, sin(angle) * radius * 0.42))
		draw_polyline(ring, Color(0.69, 1.0, 0.95, alpha), 0.65, true)
