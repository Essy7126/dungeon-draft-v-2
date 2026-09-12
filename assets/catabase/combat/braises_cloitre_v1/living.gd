extends Node2D
var effect_time := 0.0
var _material: ShaderMaterial
var _reduced := false


func _ready() -> void:
	_material = get_parent().get_node("Land").material as ShaderMaterial
	_reduced = GameManager.is_reduced_motion_enabled()
	GameManager.reduced_motion_changed.connect(_on_reduced_motion)
	seek_for_review(0.0)


func _process(delta: float) -> void:
	if not _reduced:
		seek_for_review(effect_time + delta)


func _on_reduced_motion(value: bool) -> void:
	_reduced = value


func seek_for_review(seconds: float) -> void:
	effect_time = seconds
	_material.set_shader_parameter("effect_time", effect_time)
