extends ColorRect

@export var densite: float = 0.5
@export var vitesse: float = 0.048
@export var echelle: float = 3.75
@export var durete: float = 2.0
@export var couleur: Color = Color(1, 1, 1, 1)


func _ready() -> void:
	var vp = get_viewport_rect()
	position = Vector2.ZERO
	size = vp.size
	mouse_filter = MOUSE_FILTER_IGNORE
	material.set_shader_parameter("densite", densite)
	material.set_shader_parameter("vitesse", vitesse)
	material.set_shader_parameter("echelle", echelle)
	material.set_shader_parameter("durete", durete)
	material.set_shader_parameter("couleur_fumee", couleur)
