@tool
class_name IsoLayerFollowTerrain
extends TileMapLayer

## Verrouille CE TileMapLayer sur la grille du "TerrainLayer" designe.
##
## A quoi ca sert : la couche decor (ou est peinte la tuile drapeau) doit
## tomber EXACTEMENT sur les memes losanges que le terrain. Comme la couche
## decor vit ailleurs dans l'arbre (souvent sous un YSortedWorld avec sa propre
## echelle/inclinaison), elle derive du terrain. Ce script recopie en continu
## la projection ecran (global_transform) du terrain sur cette couche : chaque
## fois que tu modifies la perspective du terrain (skew, scale, position), la
## couche decor suit toute seule, sans reglage manuel.
##
## C'est le meme principe que iso_grid_view_test.gd applique a la couche
## "Geometry" de la grille de jeu, mais empaquete pour n'importe quelle couche.
##
## Usage : attacher ce script au TileMapLayer decor, puis renseigner
## "Terrain Layer Path" (ex: ../../TerrainLayer).

## Le terrain dont on recopie la grille. Repli automatique sur un noeud nomme
## "TerrainLayer" a la racine de la scene si laisse vide.
@export_node_path("TileMapLayer") var terrain_layer_path: NodePath

## Recalcule la synchro en continu dans l'editeur (live). Desactiver si ca rame.
@export var sync_live_in_editor := true

## Recopie aussi la GEOMETRIE de tuile du terrain (forme/agencement/taille) sur
## cette couche. A laisser desactive tant que la couche decor a deja la meme
## geometrie iso 64x32 : l'activer modifierait le TileSet partage du decor.
@export var sync_tile_geometry := false

var _terrain_layer: TileMapLayer = null
var _last_terrain_xform: Transform2D = Transform2D()


func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(sync_live_in_editor)
	_sync_to_terrain()


func _process(_delta: float) -> void:
	# En editeur seulement : si la transform du terrain a change, on recale.
	if not Engine.is_editor_hint():
		return
	var terrain := _resolve_terrain_layer()
	if terrain != null and terrain.global_transform != _last_terrain_xform:
		_sync_to_terrain()


## Cale la projection ecran (et optionnellement la geometrie de tuile) de cette
## couche sur celle du terrain. Les tuiles peintes ici tombent alors pile sur
## les losanges du terrain.
func _sync_to_terrain() -> void:
	var terrain := _resolve_terrain_layer()
	if terrain == null:
		return
	if sync_tile_geometry:
		_copy_tile_geometry(terrain)
	global_transform = terrain.global_transform
	_last_terrain_xform = terrain.global_transform


func _resolve_terrain_layer() -> TileMapLayer:
	if is_instance_valid(_terrain_layer):
		return _terrain_layer
	if terrain_layer_path != NodePath():
		_terrain_layer = get_node_or_null(terrain_layer_path) as TileMapLayer
	if _terrain_layer == null:
		# Repli pratique : un "TerrainLayer" a la racine de la scene courante.
		var root := get_tree().current_scene if get_tree() != null else null
		if root != null:
			_terrain_layer = root.get_node_or_null(^"TerrainLayer") as TileMapLayer
	return _terrain_layer


## Recopie forme/agencement/taille/axe de tuile du terrain sur le TileSet de
## cette couche. Optionnel : ne pas activer si le TileSet est partage et deja
## aligne, pour ne pas modifier la ressource commune.
func _copy_tile_geometry(terrain: TileMapLayer) -> void:
	if tile_set == null or terrain.tile_set == null:
		return
	tile_set.tile_size = terrain.tile_set.tile_size
	tile_set.tile_shape = terrain.tile_set.tile_shape
	tile_set.tile_layout = terrain.tile_set.tile_layout
	tile_set.tile_offset_axis = terrain.tile_set.tile_offset_axis
