extends Node2D

@export var torch_base_a := Vector2(183.0, 190.0)
@export var torch_base_b := Vector2(403.0, 153.0)

var effect_time := 0.0
var _reduced := false
var _materials: Array[ShaderMaterial] = []


func _ready() -> void:
	for path: String in ["Vapor", "Torchlight"]:
		var layer := get_node(path) as ColorRect
		layer.material = layer.material.duplicate()
		_materials.append(layer.material as ShaderMaterial)
	# Decor is a child of the registered terrain composition; both surfaces
	# receive one clock so no seam appears between the painting and the water.
	for path: String in ["Land", "Water"]:
		var surface := get_parent().get_node_or_null(path) as Polygon2D
		if surface != null and surface.material is ShaderMaterial:
			_materials.append(surface.material as ShaderMaterial)
	for material in _materials:
		for uniform: Dictionary in material.shader.get_shader_uniform_list():
			if uniform.name == "torch_base_a":
				material.set_shader_parameter("torch_base_a", torch_base_a)
			elif uniform.name == "torch_base_b":
				material.set_shader_parameter("torch_base_b", torch_base_b)
	_reduced = GameManager.is_reduced_motion_enabled()
	GameManager.reduced_motion_changed.connect(_on_reduced_motion)
	_push_time()


func _process(delta: float) -> void:
	if not _reduced:
		effect_time += delta
		_push_time()


func _on_reduced_motion(enabled: bool) -> void:
	_reduced = enabled


func _push_time() -> void:
	for material in _materials:
		material.set_shader_parameter("effect_time", effect_time)


func seek_for_review(seconds: float) -> void:
	effect_time = seconds
	_push_time()


func animation_report() -> Dictionary:
	return { "clock": effect_time, "materials": _materials.size(), "reduced_motion": _reduced }
