extends ColorRect

@export var angle: float = 0.0
@export var position_ray: float = 0.5
@export var spread: float = 0.3
@export var cutoff: float = 0.05
@export var falloff: float = 0.5
@export var edge_fade: float = 0.15
@export var speed: float = 0.4
@export var ray1_density: float = 8.0
@export var ray2_density: float = 25.0
@export var ray2_intensity: float = 0.3
@export var couleur: Color = Color(1.0, 0.85, 0.4, 0.35)
@export var ray_seed: float = 5.0
@export var largeur: float = 220.0
@export var hauteur: float = 380.0


func _ready() -> void:
	size = Vector2(largeur, hauteur)
	mouse_filter = MOUSE_FILTER_IGNORE
	material.set_shader_parameter("angle", angle)
	material.set_shader_parameter("position", position_ray)
	material.set_shader_parameter("spread", spread)
	material.set_shader_parameter("cutoff", cutoff)
	material.set_shader_parameter("falloff", falloff)
	material.set_shader_parameter("edge_fade", edge_fade)
	material.set_shader_parameter("speed", speed)
	material.set_shader_parameter("ray1_density", ray1_density)
	material.set_shader_parameter("ray2_density", ray2_density)
	material.set_shader_parameter("ray2_intensity", ray2_intensity)
	material.set_shader_parameter("color", couleur)
	material.set_shader_parameter("seed", ray_seed)
