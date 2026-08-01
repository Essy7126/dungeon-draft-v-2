@tool
class_name SkyLightRays
extends CanvasLayer

## Rayons de lumiere (god rays) animes dans le ciel, cales sur le soleil du fond
## peint (haut-droite). Le support est un ColorRect plein ecran ; les rayons sont
## concentres en haut (ciel) et s'estompent avant le sol (falloff), donc ils
## n'ecrasent pas les persos. Data-driven : @export documentes -> materiau.
##
## Coherence sol/ciel : garder `speed` proche de `cloud_speed` de la lumiere au
## sol, et `angle` cale sur la meme direction de soleil.

## Le materiau god-rays a piloter (res://battle/iso/sky_light_rays.tres).
@export var rays_material: ShaderMaterial:
	set(value):
		rays_material = value
		_bind_rect()
		_apply()

@export_group("Direction (vers le soleil haut-droite)")
## Inclinaison des rayons, en radians. Plus grand = plus rasant (couche de soleil).
@export var angle := 0.75:
	set(value): angle = value; _apply()
## Position/decalage de la source des rayons (valeurs typiques -0.3..0.6).
@export_range(-1.0, 1.5) var source_x := 0.5:
	set(value): source_x = value; _apply()

@export_group("Aspect")
## Couleur des rayons (RGBA ; l'alpha dose l'intensite globale).
@export var color := Color(1.0, 0.92, 0.7, 0.2):
	set(value): color = value; _apply()
## Etalement des rayons.
@export_range(0.0, 1.0) var spread := 0.5:
	set(value): spread = value; _apply()
## Attenuation vers le bas (les rayons s'estompent avant le sol).
@export_range(0.0, 1.0) var falloff := 0.4:
	set(value): falloff = value; _apply()
## Adoucissement des bords lateraux de la nappe de rayons.
@export_range(0.0, 1.0) var edge_fade := 0.15:
	set(value): edge_fade = value; _apply()
## Densite des rayons larges.
@export var ray1_density := 10.0:
	set(value): ray1_density = value; _apply()
## Densite des rayons fins.
@export var ray2_density := 30.0:
	set(value): ray2_density = value; _apply()
## Intensite des rayons fins.
@export_range(0.0, 1.0) var ray2_intensity := 0.35:
	set(value): ray2_intensity = value; _apply()

@export_group("Mouvement (a garder proche du sol)")
## Vitesse de scintillement/derive des rayons.
@export var speed := 0.5:
	set(value): speed = value; _apply()

@export_group("Masque")
## Sprite de fond : les rayons sont limites a sa zone a l'ecran (pas de rayons
## sur les bandes noires / letterbox). Vide = plein ecran.
@export var background_sprite_path := NodePath("../MountainBackground/CaveSprite")

var _rect: ColorRect = null


func _ready() -> void:
	_bind_rect()
	_apply()
	_clip_to_background()


func _process(_delta: float) -> void:
	# Recale le rectangle sur la zone du fond a chaque frame (suit la camera).
	_clip_to_background()


func _bind_rect() -> void:
	_rect = get_node_or_null("RaysRect") as ColorRect
	if _rect != null:
		_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if rays_material != null:
			_rect.material = rays_material


## Limite le ColorRect a la projection ecran du sprite de fond -> les rayons ne
## debordent plus sur les bandes noires. Repli plein ecran si pas de fond.
func _clip_to_background() -> void:
	if not is_instance_valid(_rect):
		return
	var bg := get_node_or_null(background_sprite_path) as Sprite2D
	if bg == null or bg.texture == null:
		_rect.position = Vector2.ZERO
		_rect.size = get_viewport().get_visible_rect().size
		return
	var half: Vector2 = bg.texture.get_size() * 0.5
	if not bg.centered:
		half = Vector2.ZERO
	var ct := get_viewport().get_canvas_transform()
	var s_tl: Vector2 = ct * bg.to_global(-half)
	var s_br: Vector2 = ct * bg.to_global(bg.texture.get_size() - half)
	_rect.position = s_tl
	_rect.size = s_br - s_tl


func _apply() -> void:
	if rays_material == null:
		return
	rays_material.set_shader_parameter("angle", angle)
	rays_material.set_shader_parameter("position", source_x)
	rays_material.set_shader_parameter("color", color)
	rays_material.set_shader_parameter("spread", spread)
	rays_material.set_shader_parameter("falloff", falloff)
	rays_material.set_shader_parameter("edge_fade", edge_fade)
	rays_material.set_shader_parameter("ray1_density", ray1_density)
	rays_material.set_shader_parameter("ray2_density", ray2_density)
	rays_material.set_shader_parameter("ray2_intensity", ray2_intensity)
	rays_material.set_shader_parameter("speed", speed)
