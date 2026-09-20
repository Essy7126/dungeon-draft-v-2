extends Node2D
## Follows the existing gameplay delay; never invents an impact.
const Catalog := preload("class_card_vfx_catalog.gd")
var elapsed := 0.0
var duration := .2
var closed := false
var mat: ShaderMaterial
var echo := false


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
	mat.shader = preload("ethereal/flight.gdshader")
	var colors: Array = Catalog.PALETTES[entry.family]
	mat.set_shader_parameter("body_color", Color(colors[0]))
	mat.set_shader_parameter("core_color", Color(colors[1]))
	mat.set_shader_parameter("echo", echo)
	rect.material = mat
	add_child(rect)
	z_index = 3


func _process(delta: float) -> void:
	if closed or mat == null:
		return
	elapsed += delta
	mat.set_shader_parameter("progress", clampf(elapsed / duration, 0.0, 1.0))
	if (echo and elapsed >= duration) or elapsed > duration + 1.0:
		cancel()


func cancel() -> void:
	if closed:
		return
	closed = true
	visible = false
	queue_free()
