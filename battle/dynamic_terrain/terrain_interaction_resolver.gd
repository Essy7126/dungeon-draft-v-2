class_name TerrainInteractionResolver
extends RefCounted

## Table centrale et pure des interactions de surfaces. Les sorts fournissent
## uniquement un effet entrant ; cette classe decide du resultat et de la
## creation eventuelle de vapeur.


static func resolve(current: int, incoming: int) -> Dictionary:
	var none := CellSurfaceState.DynamicSurface.NONE
	var fire := CellSurfaceState.DynamicSurface.FIRE
	var water := CellSurfaceState.DynamicSurface.WATER
	var ice := CellSurfaceState.DynamicSurface.ICE
	if incoming == none:
		return {"surface": none, "steam": false}
	if current == none or current == incoming:
		return {"surface": incoming, "steam": false}
	if (current == fire and incoming == water) \
			or (current == water and incoming == fire):
		return {"surface": none, "steam": true}
	if current == fire and incoming == ice:
		return {"surface": water, "steam": true}
	if current == ice and incoming == fire:
		return {"surface": water, "steam": false}
	if (current == water and incoming == ice) \
			or (current == ice and incoming == water):
		return {"surface": ice, "steam": false}
	return {"surface": incoming, "steam": false}

