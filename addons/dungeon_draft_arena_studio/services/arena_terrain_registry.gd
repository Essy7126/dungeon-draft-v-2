@tool
class_name ArenaTerrainRegistry
extends RefCounted

## Facade de compatibilite. Les valeurs resident dans des
## ArenaTerrainDefinition chargees par ArenaCatalogService.


static func has(terrain_id: StringName) -> bool:
	return ArenaCatalogService.has_terrain(terrain_id)


static func definition_for(terrain_id: StringName) -> ArenaTerrainDefinition:
	return ArenaCatalogService.terrain(terrain_id)


static func get_entry(terrain_id: StringName) -> Dictionary:
	var definition := definition_for(terrain_id)
	return definition.to_legacy_entry() if definition != null else {}


static func all_ids(dynamic_only := false) -> Array[StringName]:
	return ArenaCatalogService.terrain_ids(dynamic_only)


static func configure_cell(definition: ArenaCellDefinition, terrain_id: StringName) -> bool:
	var terrain := definition_for(terrain_id)
	if definition == null or terrain == null:
		return false
	definition.terrain_id = terrain_id
	definition.defined = terrain_id != &"void"
	definition.playable = terrain.walkable
	definition.cell_type = terrain.cell_type
	return true


static func texture_for(terrain_id: StringName) -> Texture2D:
	var definition := definition_for(terrain_id)
	return definition.base_texture if definition != null else null


static func color_for(terrain_id: StringName) -> Color:
	var definition := definition_for(terrain_id)
	return definition.editor_color if definition != null else Color.WHITE


static func terrain_id_for_lab_surface(surface: int) -> StringName:
	var definition := ArenaCatalogService.terrain_for_lab_surface(surface)
	return definition.stable_id if definition != null else &"stone"


static func lab_surface_for(terrain_id: StringName) -> int:
	return ArenaCatalogService.surface_for_terrain(terrain_id)


static func interaction_element_for_lab_surface(surface: int) -> StringName:
	var definition := ArenaCatalogService.terrain_for_lab_surface(surface)
	return definition.interaction_element if definition != null else &"NONE"
