extends ColorRect

## L'angle d'inclinaison de la lumière, comme si le soleil était plus ou moins penché sur le côté.
@export var angle: float = 20.0

## Décale la source de lumière sur le côté (à gauche ou à droite).
@export var position_ray: float = 0.0

## La largeur du faisceau de lumière. Petit nombre = faisceau étroit, grand nombre = faisceau très large.
@export var spread: float = 0.95

## Où commence le bord du faisceau sur les côtés. Change surtout la largeur visible de la lumière.
@export var cutoff: float = 0.05

## La hauteur, dans l'écran, où la lumière s'arrête complètement en descendant. 0 = tout en haut, 1 = tout en bas.
@export var height: float = 0.4

## La largeur de la zone où la lumière s'estompe en bas, autour de la hauteur définie par height. Grand nombre = transition douce, petit nombre = coupure nette.
@export var falloff: float = 0.18

## La largeur de la zone où la lumière s'estompe sur les côtés, près du bord du faisceau.
@export var edge_fade: float = 0.3

## La vitesse du petit tremblement/scintillement à l'intérieur des rayons de lumière.
@export var speed: float = 0.15

## La vitesse à laquelle les rayons ondulent doucement de gauche à droite (un léger va-et-vient, la lumière ne se déplace jamais vraiment).
@export var drift_speed: float = 0.05

## La vitesse à laquelle la lumière "respire", c'est-à-dire devient un peu plus ou un peu moins forte en boucle lente.
@export var pulse_speed: float = 0.25

## De combien la lumière respire. 0 = pas de respiration du tout, 1 = variation très forte.
@export var pulse_amplitude: float = 0.1

## Le nombre de rayons visibles dans la lumière. Grand nombre = beaucoup de fines rayures, petit nombre = grosses bandes larges.
@export var ray_density: float = 3.0

## À quel point les rayons sont flous/doux plutôt que nets. Grand nombre = lumière très diffuse, petit nombre = rayons plus marqués.
@export var diffusion: float = 0.5

## La force générale de la lumière. Plus le nombre est grand, plus elle est lumineuse/intense.
@export var intensity: float = 1.6

## La couleur de la lumière (et sa transparence, avec le 4e chiffre du Alpha).
@export var couleur: Color = Color(1.0, 0.93, 0.78, 0.4)

## Une option technique pour les couleurs très lumineuses (HDR). Laisse décoché si tu n'es pas sûr.
@export var hdr: bool = false

## Un nombre de départ pour générer le motif aléatoire de la lumière. Le changer donne un motif différent mais avec le même style.
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
	material.set_shader_parameter("drift_speed", drift_speed)
	material.set_shader_parameter("pulse_speed", pulse_speed)
	material.set_shader_parameter("pulse_amplitude", pulse_amplitude)
	material.set_shader_parameter("ray_density", ray_density)
	material.set_shader_parameter("diffusion", diffusion)
	material.set_shader_parameter("intensity", intensity)
	material.set_shader_parameter("color", couleur)
	material.set_shader_parameter("hdr", hdr)
	material.set_shader_parameter("seed", ray_seed)
