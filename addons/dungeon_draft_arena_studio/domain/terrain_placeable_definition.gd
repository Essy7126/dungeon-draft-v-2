@tool
class_name TerrainPlaceableDefinition
extends Resource

## Description data-driven d'un élément visible dans la bibliothèque Terrain.
## Le service de placement interprète `placement_kind` et `payload` ; l'UI ne
## connaît ni les identifiants de gameplay ni les règles propres aux familles.

enum Family {
	FLOOR,
	OBSTACLE,
	SPAWN,
	INTERACTIVE,
	DECORATION,
}

enum PlacementKind {
	PERMANENT_TERRAIN,
	WALL,
	SPAWN_POINT,
	VORTEX_IMPULSE,
	VORTEX_PORTAL_TWO,
	VORTEX_PORTAL_MULTI,
	DECORATION_MARKER,
}

@export var stable_id: StringName = &"placeable"
@export var display_name := "Élément"
@export var family := Family.FLOOR
@export var placement_kind := PlacementKind.PERMANENT_TERRAIN
@export_multiline var result_in_game := ""
@export var badges: PackedStringArray = []
@export var thumbnail: Texture2D = null
@export var payload := {}
@export var editor_placeable := true
@export var production_placeable := true
@export var guided_visible := true
@export var minimum_cells := 1
@export var maximum_cells := 1


func family_label() -> String:
	return ["Sols", "Obstacles", "Départs", "Interactifs", "Décor"][family]


func is_multi_cell() -> bool:
	return maximum_cells < 0 or maximum_cells > 1


func tooltip_text() -> String:
	var lines := PackedStringArray([display_name, family_label()])
	if not result_in_game.strip_edges().is_empty():
		lines.append(result_in_game.strip_edges())
	if not badges.is_empty():
		lines.append("Comportement : %s" % ", ".join(badges))
	return "\n".join(lines)
