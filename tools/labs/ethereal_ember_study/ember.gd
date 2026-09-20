extends Node2D
## Independent visual prototype. Time in seconds is explicit for scrubbing/capture.

const DURATION := 1.9
const FireShader := preload("ember.gdshader")
const SmokeShader := preload("smoke.gdshader")
var materials: Array[ShaderMaterial] = []


func _ready() -> void:
	for shader in [SmokeShader, FireShader]:
		var rect := ColorRect.new()
		rect.position = Vector2(-128, -215.04)
		rect.size = Vector2(256, 256)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat := ShaderMaterial.new()
		mat.shader = shader
		rect.material = mat
		materials.append(mat)
		add_child(rect)
	sample(0.0)


func sample(time: float) -> void:
	visible = time > 0.0 and time < DURATION
	for mat in materials:
		mat.set_shader_parameter("age", maxf(time, 0.0))
