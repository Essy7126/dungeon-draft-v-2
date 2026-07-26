extends Polygon2D

## La vitesse à laquelle la brume glisse sur le côté, comme poussée par le vent. Petit nombre = ça bouge lentement, grand nombre = ça bouge vite.
@export var vitesse: float = 0.03

## La taille des formes de brume. Petit nombre = grosses formes molles et larges. Grand nombre = plein de petits détails serrés.
@export var echelle: float = 0.006

## Étire les formes de brume vers le haut, pour qu'elles ressemblent à des filaments qui montent plutôt qu'à des boules rondes.
@export var etirement_vertical: float = 3.0

## La force générale de la brume. Plus le nombre est grand, plus elle est visible/épaisse partout.
@export var densite: float = 1.0

## En dessous de cette valeur, il n'y a pas de brume du tout (zone transparente). Sert à créer de vrais trous dans la brume.
@export var seuil_bas: float = 0.2

## Au-dessus de cette valeur, la brume est à fond, complètement opaque. Entre seuil_bas et seuil_haut, elle passe progressivement de rien à plein.
@export var seuil_haut: float = 0.75

## À quelle hauteur dans la zone la brume commence à apparaître. 0 = en haut de la zone, 1 = en bas de la zone.
@export var position_masque: float = 0.45

## La largeur de la transition entre "pas de brume" et "brume complète", autour de la hauteur définie par position_masque. Grand nombre = transition douce et étalée, petit nombre = coupure plus nette.
@export var douceur_masque: float = 0.4

## La couleur de la brume bien dense, la partie la plus visible du nuage.
@export var couleur_fumee: Color = Color(0.96, 0.94, 0.87, 1.0)

## La couleur des zones plus légères/creuses à l'intérieur de la brume, comme une petite ombre dans le nuage.
@export var couleur_ombre: Color = Color(0.78, 0.75, 0.68, 1.0)

## À quelle vitesse la brume "respire", c'est-à-dire devient un petit peu plus ou un petit peu moins visible en boucle lente.
@export var respiration_vitesse: float = 0.2

## De combien la brume respire. 0 = pas de respiration du tout, 1 = variation très forte.
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
