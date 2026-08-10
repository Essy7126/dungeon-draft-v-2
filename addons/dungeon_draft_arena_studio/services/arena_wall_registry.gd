@tool
class_name ArenaWallRegistry
extends RefCounted

## Facade historique adossee aux ArenaWallDefinition data-driven.


static func has(wall_id: StringName) -> bool:
	return ArenaCatalogService.has_wall(wall_id)


static func definition_for(wall_id: StringName) -> ArenaWallDefinition:
	return ArenaCatalogService.wall(wall_id)


static func get_entry(wall_id: StringName) -> Dictionary:
	var definition := definition_for(wall_id)
	return definition.to_legacy_entry() if definition != null else {}


static func all_ids() -> Array[StringName]:
	return ArenaCatalogService.wall_ids()


static func config_for(wall_id: StringName) -> WallConfig:
	var definition := definition_for(wall_id)
	return definition.wall_config if definition != null else null


static func id_for_variant(variant: int) -> StringName:
	var definition := ArenaCatalogService.wall_for_variant(variant)
	return definition.stable_id if definition != null else &""


static func id_for_config(config: WallConfig) -> StringName:
	if config == null:
		return &""
	for wall_id in all_ids():
		var definition := definition_for(wall_id)
		if definition.wall_config == config \
				or (definition.wall_config != null \
					and definition.wall_config.variant_id == config.variant_id):
			return wall_id
	return &""


static func color_for_variant(variant: int) -> Color:
	var definition := ArenaCatalogService.wall_for_variant(variant)
	return definition.editor_color if definition != null else Color.WHITE
