@tool
class_name TerrainPlaceableCatalog
extends Resource

## Catalogue des éléments qui ne peuvent pas être découverts directement dans
## les catalogues de sols et de murs existants.

@export var entries: Array[TerrainPlaceableDefinition] = []


func valid_entries() -> Array[TerrainPlaceableDefinition]:
	var result: Array[TerrainPlaceableDefinition] = []
	for entry in entries:
		if entry != null and entry.stable_id != &"":
			result.append(entry)
	return result
