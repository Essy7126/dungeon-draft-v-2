extends Node2D

## Atmosphere traced over the native 1376 x 768 Halle sous les racines painting.
## The parent owns the common clock and scales this layer with the painting.
const STEAM_SHADER: Shader = preload("res://tools/labs/apothecary_living_map/steam.gdshader")
const WARM_MOTES: Array[Vector2] = [
	Vector2(327, 321), Vector2(377, 390), Vector2(469, 340),
	Vector2(530, 303), Vector2(584, 250), Vector2(672, 245),
	Vector2(774, 282), Vector2(854, 276), Vector2(940, 357),
	Vector2(1019, 301), Vector2(1086, 389), Vector2(911, 432),
]
const WATER_MOTES: Array[Vector2] = [
	Vector2(32, 486), Vector2(91, 524), Vector2(155, 564),
	Vector2(213, 592), Vector2(1060, 580), Vector2(1113, 604),
	Vector2(1176, 631), Vector2(1264, 657), Vector2(512, 755),
	Vector2(813, 754),
]
const FOUNTAIN_RIPPLES: Array[Vector2] = [
	Vector2(589, 479), Vector2(617, 492),
	Vector2(653, 492), Vector2(677, 476),
]
const FOUNTAIN_NOZZLE: Vector2 = Vector2(632, 428)

var _effect_time: float = 0.0
var _strength: float = 1.0
var _effects_enabled: bool = true
var _water_enabled: bool = true
var _vapor_materials: Array[ShaderMaterial] = []
var _vapor_panels: Array[ColorRect] = []


func _ready() -> void:
	# Each panel is shallow and positioned over a channel, away from the floor.
	_add_channel_mist(Rect2(-10, 445, 180, 70), 0.0)
	_add_channel_mist(Rect2(92, 516, 195, 72), 2.7)
	_add_channel_mist(Rect2(994, 531, 170, 78), 5.2)
	_add_channel_mist(Rect2(1126, 586, 190, 68), 8.6)
	_add_channel_mist(Rect2(430, 702, 195, 79), 11.3)
	_add_channel_mist(Rect2(724, 704, 210, 78), 14.8)
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
	for vapor_material in _vapor_materials:
		vapor_material.set_shader_parameter("effect_time", _effect_time)
		vapor_material.set_shader_parameter("effect_strength", _strength)
	for vapor_panel in _vapor_panels:
		vapor_panel.visible = _water_enabled
	queue_redraw()


func _add_channel_mist(bounds: Rect2, phase: float) -> void:
	var vapor := ColorRect.new()
	vapor.position = bounds.position
	vapor.size = bounds.size
	vapor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vapor_material := ShaderMaterial.new()
	vapor_material.shader = STEAM_SHADER
	vapor_material.set_shader_parameter("vapor_color", Color(0.50, 0.94, 0.88, 0.16))
	vapor_material.set_shader_parameter("phase", phase)
	vapor.material = vapor_material
	add_child(vapor)
	_vapor_materials.append(vapor_material)
	_vapor_panels.append(vapor)


func _draw() -> void:
	if not _effects_enabled or _strength <= 0.0:
		return
	_draw_warm_motes()
	if _water_enabled:
		_draw_water_motes()
		_draw_fountain_droplets()
		_draw_fountain_ripples()


func _draw_warm_motes() -> void:
	for index in WARM_MOTES.size():
		var phase: float = float(index) * 2.39996
		var age: float = fposmod(_effect_time * (0.033 + float(index % 3) * 0.004) + phase, 1.0)
		var fade: float = pow(sin(age * PI), 2.0)
		var mote_position: Vector2 = WARM_MOTES[index] + Vector2(
			sin(_effect_time * 0.18 + phase) * 12.0,
			(0.5 - age) * 34.0
		)
		_draw_soft_mote(mote_position, 0.68 + float(index % 3) * 0.13, Color(1.0, 0.79, 0.44), fade * 0.44)


func _draw_water_motes() -> void:
	for index in WATER_MOTES.size():
		var phase: float = float(index) * 0.173
		var age: float = fposmod(_effect_time * 0.073 + phase, 1.0)
		var fade: float = pow(sin(age * PI), 2.0)
		var mote_position: Vector2 = WATER_MOTES[index] + Vector2(
			sin(_effect_time * 0.32 + float(index)) * 5.0,
			-age * 16.0
		)
		_draw_soft_mote(mote_position, 0.62 + float(index % 2) * 0.16, Color(0.49, 1.0, 0.94), fade * 0.47)


func _draw_fountain_droplets() -> void:
	for index in 7:
		var cycle: float = fposmod(_effect_time * 0.92 + float(index) * 0.137, 1.0)
		if cycle > 0.68:
			continue
		var age: float = cycle / 0.68
		var direction: float = -1.0 if index % 2 == 0 else 1.0
		var travel: float = 6.0 + float(index % 4) * 3.0
		var droplet_position: Vector2 = FOUNTAIN_NOZZLE + Vector2(
			direction * travel * age,
			-35.0 * age * (1.0 - age) + 19.0 * age
		)
		var fade: float = sin(age * PI)
		_draw_soft_mote(droplet_position, 0.70, Color(0.66, 1.0, 0.96), fade * 0.65)


func _draw_fountain_ripples() -> void:
	for index in FOUNTAIN_RIPPLES.size():
		var cycle: float = fposmod(_effect_time / 3.7 + float(index) * 0.238, 1.0)
		if cycle > 0.29:
			continue
		var age: float = cycle / 0.29
		var radius: float = lerpf(0.9, 5.0, age)
		var alpha: float = sin(age * PI) * (1.0 - age) * 0.30 * _strength
		var ring := PackedVector2Array()
		for point_index in 17:
			var angle: float = float(point_index) / 16.0 * TAU
			ring.append(FOUNTAIN_RIPPLES[index] + Vector2(cos(angle) * radius, sin(angle) * radius * 0.42))
		draw_polyline(ring, Color(0.66, 1.0, 0.96, alpha), 0.7, true)


func _draw_soft_mote(mote_position: Vector2, radius: float, tint: Color, alpha: float) -> void:
	tint.a = alpha * 0.20 * _strength
	draw_circle(mote_position, radius * 2.0, tint, true, -1.0, true)
	tint.a = alpha * _strength
	draw_circle(mote_position, radius, tint, true, -1.0, true)
