class_name CellSurfaceState
extends RefCounted

## Donnees d'une cellule de surface. Le terrain de base reste immuable : les
## sorts ne modifient que la couche dynamique et ses metadonnees temporaires.

enum BaseSurface {
	NORMAL,
	## Alias conservé pour les contrats Forest Dynamic Grid antérieurs au Studio 2.0.
	FOREST_NEUTRAL = 0,
	WATER,
	ICE,
	LAVA,
	VOID,
	WALL,
	OBSTACLE,
}

enum DynamicSurface {
	NONE,
	FIRE,
	WATER,
	ICE,
}

var base_surface: BaseSurface = BaseSurface.NORMAL
var base_cell_type: int = GridData.CellType.NORMAL
var base_terrain_id: StringName = &"normal"
var dynamic_surface: DynamicSurface = DynamicSurface.NONE
var duration_turns := 0
var source_unit = null
var gameplay_flags: Dictionary = {}


func configure_base(cell_type: int, has_obstacle := false) -> void:
	base_cell_type = cell_type
	if has_obstacle:
		base_surface = BaseSurface.OBSTACLE
		return
	match cell_type:
		GridData.CellType.ICE:
			base_surface = BaseSurface.ICE
		GridData.CellType.LAVA:
			base_surface = BaseSurface.LAVA
		GridData.CellType.HOLE:
			base_surface = BaseSurface.VOID
		GridData.CellType.WALL:
			base_surface = BaseSurface.WALL
		_:
			base_surface = BaseSurface.NORMAL


func configure_base_terrain(
		terrain_id: StringName,
		cell_type: int,
		has_obstacle := false
	) -> void:
	base_terrain_id = terrain_id
	configure_base(cell_type, has_obstacle)
	if has_obstacle:
		return
	match terrain_id:
		&"water":
			base_surface = BaseSurface.WATER
		&"ice":
			base_surface = BaseSurface.ICE
		&"lava":
			base_surface = BaseSurface.LAVA
		&"void", &"hole":
			base_surface = BaseSurface.VOID
		&"wall":
			base_surface = BaseSurface.WALL


func configure(
		surface: DynamicSurface,
		duration: int,
		source,
		flags: Dictionary
	) -> void:
	dynamic_surface = surface
	duration_turns = maxi(0, duration)
	source_unit = source
	gameplay_flags = flags.duplicate(true)


func clear_dynamic() -> void:
	dynamic_surface = DynamicSurface.NONE
	duration_turns = 0
	source_unit = null
	gameplay_flags.clear()


func is_dynamic() -> bool:
	return dynamic_surface != DynamicSurface.NONE
