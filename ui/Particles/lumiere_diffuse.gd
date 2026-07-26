extends ColorRect

@export var angle: float = 20.0
@export var position_ray: float = 0.0
@export var spread: float = 0.95
@export var cutoff: float = 0.05
@export var height: float = 0.4
@export var falloff: float = 0.18
@export var edge_fade: float = 0.3
@export var speed: float = 0.15
@export var ray_density: float = 3.0
@export var diffusion: float = 0.5
@export var intensity: float = 2.2
@export var couleur: Color = Color(1.0, 0.93, 0.78, 0.4)
@export var hdr: bool = false
@export var ray_seed: float = 5.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	material.set_shader_parameter("angle", angle)
	material.set_shader_parameter("position", position_ray)
	material.set_shader_parameter("spread", spread)
	material.set_shader_parameter("cutoff", cutoff)
	material.set_shader_parameter("height", height)
	material.set_shader_parameter("falloff", falloff)
	material.set_shader_parameter("edge_fade", edge_fade)
	material.set_shader_parameter("speed", speed)
	material.set_shader_parameter("ray_density", ray_density)
	material.set_shader_parameter("diffusion", diffusion)
	material.set_shader_parameter("intensity", intensity)
	material.set_shader_parameter("color", couleur)
	material.set_shader_parameter("hdr", hdr)
	material.set_shader_parameter("seed", ray_seed)
