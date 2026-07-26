extends Polygon2D

@export var vitesse: float = 0.03
@export var echelle: float = 0.006
@export var etirement_vertical: float = 3.0
@export var densite: float = 1.0
@export var seuil_bas: float = 0.2
@export var seuil_haut: float = 0.75
@export var position_masque: float = 0.45
@export var douceur_masque: float = 0.4
@export var couleur_fumee: Color = Color(0.96, 0.94, 0.87, 1.0)
@export var couleur_ombre: Color = Color(0.78, 0.75, 0.68, 1.0)
@export var respiration_vitesse: float = 0.2
@export var respiration_amplitude: float = 0.08


func _ready() -> void:
	var zone_haut := INF
	var zone_bas := -INF
	for point in polygon:
		zone_haut = min(zone_haut, point.y)
		zone_bas = max(zone_bas, point.y)

	material.set_shader_parameter("vitesse", vitesse)
	material.set_shader_parameter("echelle", echelle)
	material.set_shader_parameter("etirement_vertical", etirement_vertical)
	material.set_shader_parameter("densite", densite)
	material.set_shader_parameter("seuil_bas", seuil_bas)
	material.set_shader_parameter("seuil_haut", seuil_haut)
	material.set_shader_parameter("position_masque", position_masque)
	material.set_shader_parameter("douceur_masque", douceur_masque)
	material.set_shader_parameter("couleur_fumee", couleur_fumee)
	material.set_shader_parameter("couleur_ombre", couleur_ombre)
	material.set_shader_parameter("respiration_vitesse", respiration_vitesse)
	material.set_shader_parameter("respiration_amplitude", respiration_amplitude)
	material.set_shader_parameter("zone_haut", zone_haut)
	material.set_shader_parameter("zone_bas", zone_bas)
