extends "res://tools/labs/apothecary_living_map/hall_player.gd"

var light_positions: Array[Vector2] = []
var water_positions: Array[Vector2] = []
var water_tint := Color("48d896")


func _ready() -> void:
	super._ready()
	if _hall_material != null:
		_hall_material.shader = load("res://hub/painted_halt/actor_light.gdshader")
		_hall_material.set_shader_parameter("display_scale", display_scale)
		_hall_material.set_shader_parameter("water_tint", water_tint)


func set_environment_time(time_seconds: float, position_native: Vector2) -> void:
	if _hall_material == null:
		return
	var torso := position_native + Vector2(0, -65)
	var warm := 0.0
	var side := 0.0
	for index in light_positions.size():
		var offset := (torso - light_positions[index]) / Vector2(270, 220)
		var influence := pow(maxf(0.0, 1.0 - offset.length()), 1.3)
		influence *= 0.94 + sin(time_seconds * 7.1 + index * 1.731) * 0.06
		warm += influence
		side += clampf((light_positions[index].x - torso.x) / 110.0, -1, 1) * influence
	_warm_light = clampf(warm, 0, 1)
	_cool_light = 0.0
	for center in water_positions:
		_cool_light = maxf(
			_cool_light,
			maxf(0, 1.0 - ((position_native - center) / Vector2(450, 270)).length()),
		)
	_hall_material.set_shader_parameter("warm_light", _warm_light)
	_hall_material.set_shader_parameter("warm_direction", side / maxf(warm, 0.001))
	_hall_material.set_shader_parameter("cool_light", _cool_light)
