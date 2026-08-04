class_name CellSurfaceState
extends RefCounted

## Donnees d'une cellule de surface. Le terrain de base reste immuable : les
## sorts ne modifient que la couche dynamique et ses metadonnees temporaires.

enum BaseSurface {
	FOREST_NEUTRAL,
}

enum DynamicSurface {
	NONE,
	FIRE,
	WATER,
	ICE,
}

var base_surface: BaseSurface = BaseSurface.FOREST_NEUTRAL
var dynamic_surface: DynamicSurface = DynamicSurface.NONE
var duration_turns := 0
var source_unit = null
var gameplay_flags: Dictionary = {}


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

