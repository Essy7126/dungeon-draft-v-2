@tool
extends Polygon2D

## Nombre max de points de contour envoyes au shader. DOIT etre identique a la
## taille du tableau `bords[MAX_BORDS]` dans brume_vivante.gdshader.
const MAX_BORDS := 256

## Brume atmospherique "vivante" (shader brume_vivante.gdshader).
## Data-driven : chaque parametre est expose ici et pousse vers le materiau.
## @tool => les reglages se voient EN DIRECT dans l'editeur (inutile de lancer
## le jeu). Le degrade vertical se cale tout seul sur la forme du polygone.

## La taille des formes de brume. Petit = grosses masses molles ; grand = plein
## de petits details serres.
@export var echelle: float = 0.004

## Etire les volutes vers le haut. 1 = rond ; grand = filaments hauts et fins.
@export var etirement_vertical: float = 1.6

## A quel point les volutes se tordent (domain warping). 0 = sage ; grand = tres
## nuageux et torture.
@export var turbulence: float = 2.0

## Vitesse a laquelle les formes se DEFORMENT sur place (le coeur de l'effet
## vivant). Petit = brume paresseuse ; grand = ca bouillonne.
@export var vitesse: float = 0.06

## Derive laterale, comme un vent doux. Negatif = vers la gauche.
@export var derive: float = 0.04

## Convection : la brume monte lentement des gorges. Positif = vers le haut.
@export var montee: float = 0.12

## Vitesse de la "respiration" (variation lente de densite en boucle).
@export var respiration_vitesse: float = 0.25

## Amplitude de la respiration. 0 = aucune ; 1 = tres marquee.
@export var respiration_amplitude: float = 0.1

## Force generale de la brume. Plus grand = plus visible/epaisse partout.
@export var densite: float = 1.0

## En dessous de cette valeur de bruit, pas de brume (cree les trous).
@export var seuil_bas: float = 0.15

## Au-dessus de cette valeur, brume pleine. Entre les deux : transition douce.
@export var seuil_haut: float = 0.9

## Quantite MINIMALE de brume en haut de la zone. 0 = rien en haut ; 1 = autant
## qu'en bas. C'est le reglage "visible partout, mais plus dense en bas".
@export var plancher_haut: float = 0.4

## Courbe du degrade bas(dense) -> haut(leger). 1 = lineaire ; >1 = le dense
## reste concentre en bas ; <1 = ca remonte vite.
@export var degrade: float = 1.5

## Largeur du fondu de bord, en pixels. La brume se dissout vers le contour du
## polygone sur cette distance -> le polygone devient invisible. 0 = bord net.
@export var marge_bord: float = 60.0

## Couleur de la brume dense et eclairee (les cretes du nuage).
@export var couleur_fumee: Color = Color(0.90, 0.85, 0.75, 1.0)

## Couleur des creux plus sombres/froids a l'interieur de la brume.
@export var couleur_ombre: Color = Color(0.66, 0.66, 0.68, 1.0)


func _ready() -> void:
	# En editeur : on reapplique en continu pour refleter les sliders ET les
	# deplacements de points du polygone. En jeu : une seule fois suffit.
	set_process(Engine.is_editor_hint())
	_appliquer()


func _process(_delta: float) -> void:
	_appliquer()


func _appliquer() -> void:
	if material == null:
		return

	# Bornes verticales reelles du polygone -> le degrade suit la forme, meme
	# apres avoir deplace les points a la main.
	var zone_haut := INF
	var zone_bas := -INF
	for point in polygon:
		zone_haut = min(zone_haut, point.y)
		zone_bas = max(zone_bas, point.y)
	if zone_haut == INF:
		zone_haut = 0.0
		zone_bas = 100.0

	material.set_shader_parameter("echelle", echelle)
	material.set_shader_parameter("etirement_vertical", etirement_vertical)
	material.set_shader_parameter("turbulence", turbulence)
	material.set_shader_parameter("vitesse", vitesse)
	material.set_shader_parameter("derive", derive)
	material.set_shader_parameter("montee", montee)
	material.set_shader_parameter("respiration_vitesse", respiration_vitesse)
	material.set_shader_parameter("respiration_amplitude", respiration_amplitude)
	material.set_shader_parameter("densite", densite)
	material.set_shader_parameter("seuil_bas", seuil_bas)
	material.set_shader_parameter("seuil_haut", seuil_haut)
	material.set_shader_parameter("plancher_haut", plancher_haut)
	material.set_shader_parameter("degrade", degrade)
	material.set_shader_parameter("couleur_fumee", couleur_fumee)
	material.set_shader_parameter("couleur_ombre", couleur_ombre)
	material.set_shader_parameter("zone_haut", zone_haut)
	material.set_shader_parameter("zone_bas", zone_bas)

	# Contour du polygone pour le fondu de bord (taille fixe cote shader : 256).
	material.set_shader_parameter("marge_bord", marge_bord)
	material.set_shader_parameter("bords", _contour_pour_shader())
	material.set_shader_parameter("nb_bords", mini(polygon.size(), MAX_BORDS))


## Renvoie le contour du polygone dans un tableau de taille fixe MAX_BORDS
## (exigee par l'uniforme vec2[256] du shader). Si le polygone a trop de points,
## on l'echantillonne regulierement ; sinon on complete avec le dernier point
## (jamais lu au-dela de nb_bords).
func _contour_pour_shader() -> PackedVector2Array:
	var sortie := PackedVector2Array()
	sortie.resize(MAX_BORDS)
	var total := polygon.size()
	if total == 0:
		return sortie
	if total <= MAX_BORDS:
		for i in total:
			sortie[i] = polygon[i]
		for i in range(total, MAX_BORDS):
			sortie[i] = polygon[total - 1]
	else:
		# Trop de points : echantillonnage regulier sur MAX_BORDS.
		for i in MAX_BORDS:
			var index := int(float(i) / float(MAX_BORDS) * float(total))
			sortie[i] = polygon[index]
	return sortie
