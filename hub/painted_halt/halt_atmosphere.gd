extends Node2D

const MIST := preload("res://tools/labs/apothecary_living_map/steam.gdshader")
var definition: Dictionary
var extent := Vector2.ONE
var clock := 0.0
var amount := 1.0
var water_on := true
var fire_on := true
var _mists: Array[ColorRect] = []


func _ready() -> void:
	for region: Dictionary in definition.get("mist", []):
		var r: Array = region.rect
		_add_mist(
			Vector2(r[0], r[1]) * extent,
			Vector2(r[2], r[3]) * extent,
			Color(str(region.color), float(region.alpha)),
			false,
		)
	for torch: Dictionary in definition.get("torches", []):
		var p := Vector2(torch.point[0], torch.point[1]) * extent
		_add_mist(
			p - Vector2(48, 163),
			Vector2(95, 175),
			Color(0.48, 0.48, 0.39, 0.16 * float(torch.get("smoke_strength", 1.0))),
			true,
		)


func _add_mist(at: Vector2, dimensions: Vector2, color: Color, smoke: bool) -> void:
	var panel := ColorRect.new()
	panel.position = at
	panel.size = dimensions
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_meta("smoke", smoke)
	var shader := ShaderMaterial.new()
	shader.shader = MIST
	shader.set_shader_parameter("vapor_color", color)
	shader.set_shader_parameter("phase", float(_mists.size()) * 2.71)
	panel.material = shader
	add_child(panel)
	_mists.append(panel)


func set_state(time: float, strength: float, water: bool, fire: bool, enabled: bool) -> void:
	clock = time
	amount = strength if enabled else 0.0
	water_on = water
	fire_on = fire
	visible = amount > 0.0
	for panel in _mists:
		panel.visible = fire_on if bool(panel.get_meta("smoke")) else water_on
		panel.material.set_shader_parameter("effect_time", clock)
		panel.material.set_shader_parameter("effect_strength", amount)
	queue_redraw()


func _draw() -> void:
	if amount <= 0:
		return
	if fire_on:
		for i: int in definition.torches.size():
			var torch: Dictionary = definition.torches[i]
			var source := Vector2(torch.point[0], torch.point[1]) * extent
			for j: int in clampi(int(torch.get("ember_count", 7)), 0, 12):
				var phase := i * 1.71 + j * 0.137
				var age := fposmod(clock * (0.24 + j * 0.017) + phase, 1.0)
				var at := source + Vector2(
					sin(age * 5.1 + phase) * 10.0 * age,
					-age * float(torch.get("ember_rise", 100.0)),
				)
				var color := Color(
					1.0,
					0.55 + j * 0.035,
					0.14,
					sin(age * PI) * (1.0 - age) * 0.9 * amount
					* float(torch.get("ember_strength", 1.0)),
				)
				draw_circle(at, 1.4, color, true, -1, true)
	if water_on:
		for i: int in definition.cascades.size():
			var cascade: Dictionary = definition.cascades[i]
			var source := Vector2(cascade.splash[0], cascade.splash[1]) * extent
			var width := float(cascade.width) * extent.x / float(definition.source.size[0])
			for j: int in 10:
				var age := fposmod(clock * 0.94 + j * 0.113 + i * 0.139, 1.0)
				var side := -1.0 if j % 2 == 0 else 1.0
				var at := source + Vector2(
					side * width * age,
					-38.0 * age * (1.0 - age) + age * 11.0,
				)
				draw_circle(
					at,
					1.1,
					Color(0.66, 1.0, 0.83, sin(age * PI) * 0.52 * amount),
					true,
					-1,
					true,
				)
			var cycle := fposmod(clock * 0.48 + i * 0.231, 1.0)
			var ring := PackedVector2Array()
			for j: int in 33:
				var angle := j / 32.0 * TAU
				ring.append(
					source + Vector2(cos(angle), sin(angle) * 0.37) * (cycle * width * 1.65 + 3.0)
				)
			draw_polyline(
				ring,
				Color(0.54, 1.0, 0.76, sin(cycle * PI) * (1.0 - cycle) * 0.23 * amount),
				0.9,
				true,
			)
	# Sparse motes confined to the side margins leave the main paths clear.
	var motes: Dictionary = definition.get("ambient_motes", { })
	var mote_color := Color(str(motes.get("color", "#bdf58f")))
	for i: int in clampi(int(motes.get("count", 28)), 0, 40):
		var phase := float(i) * 2.39996
		var age := fposmod(clock * 0.035 + i * 0.173, 1.0)
		var x := (0.065 + fposmod(phase, 0.18)) if i % 2 == 0 else (0.78 + fposmod(phase, 0.15))
		var at := Vector2(x, 0.28 + fposmod(i * 0.217, 0.48)) * extent + Vector2(
			sin(clock * 0.4 + phase) * 18,
			-age * 55,
		)
		draw_circle(
			at,
			1.1,
			Color(mote_color, pow(sin(age * PI), 2) * float(motes.get("alpha", 0.48)) * amount),
			true,
			-1,
			true,
		)
