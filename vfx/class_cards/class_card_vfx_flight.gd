extends Node2D
## Follows the existing gameplay delay; never invents an impact.
const Catalog := preload("class_card_vfx_catalog.gd")
var elapsed := 0.0
var duration := .2
var closed := false
var mat: ShaderMaterial
var echo := false
var manual := false


func configure(
	entry: Dictionary,
	from: Vector2,
	to: Vector2,
	seconds: float,
	instant := false,
) -> void:
	global_position = from
	global_rotation = (to - from).angle()
	duration = maxf(.05, seconds)
	echo = instant
	var rect := ColorRect.new()
	rect.position = Vector2(0, -32)
	rect.size = Vector2(maxf(1.0, from.distance_to(to)), 64)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new()
	mat.shader = preload("cel/flight.gdshader")
	mat.set_shader_parameter("artwork", preload("cel/recipes.gd").texture("pierce"))
	mat.set_shader_parameter("span", rect.size.x)
	var colors: Array = Catalog.PALETTES[entry.family]
	mat.set_shader_parameter("body_color", Color(colors[0]))
	mat.set_shader_parameter("core_color", Color(colors[1]))
	mat.set_shader_parameter("echo", echo)
	mat.set_shader_parameter("dagger", entry.get("flight_motif", "") == "dagger")
	rect.material = mat
	add_child(rect)
	z_index = 3


func _process(delta: float) -> void:
	if closed or mat == null or manual:
		return
	sample(elapsed + delta)
	if (echo and elapsed >= duration) or elapsed > duration + 1.0:
		cancel()


func sample(seconds: float) -> void:
	elapsed = seconds
	mat.set_shader_parameter("progress", clampf(elapsed / duration, 0.0, 1.0))


func cancel() -> void:
	if closed:
		return
	closed = true
	visible = false
	queue_free()
