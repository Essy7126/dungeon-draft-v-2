@tool
class_name ArenaVisualProfile
extends Resource

## Correspondance entre les types logiques et leurs images temporaires.
## Remplacer une texture ici ne change ni la generation ni le gameplay.

@export_group("Textures")
@export var normal_texture: Texture2D
@export var wall_texture: Texture2D
@export var hole_texture: Texture2D
@export var lava_texture: Texture2D
@export var ice_texture: Texture2D

@export_group("Empreinte dans l'image")
## Points normalises mesures sur le losange superieur de la dalle.
## Le renderer les fait coincider avec les coins de la case Godot.
@export var source_top_ratio := Vector2(0.50, 0.245)
@export var source_right_ratio := Vector2(0.94, 0.50)
@export var source_left_ratio := Vector2(0.06, 0.50)
@export_range(0.0, 0.3, 0.01) var cell_inset_ratio := 0.08


func texture_for(cell_type: GridData.CellType) -> Texture2D:
	match cell_type:
		GridData.CellType.NORMAL:
			return normal_texture
		GridData.CellType.WALL:
			return wall_texture
		GridData.CellType.HOLE:
			return hole_texture
		GridData.CellType.LAVA:
			return lava_texture
		GridData.CellType.ICE:
			return ice_texture
		_:
			return null


func modulate_for(_cell_type: GridData.CellType) -> Color:
	return Color.WHITE
