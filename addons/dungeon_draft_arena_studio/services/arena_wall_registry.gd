@tool
class_name ArenaWallRegistry
extends RefCounted

const BASE_CONFIG: WallConfig = preload("res://battle/dynamic_terrain/configs/wall_base.tres")
const FIRE_CONFIG: WallConfig = preload("res://battle/dynamic_terrain/configs/wall_fire.tres")
const ICE_CONFIG: WallConfig = preload("res://battle/dynamic_terrain/configs/wall_ice.tres")

const ENTRIES := {
	&"normal": {"name": "Mur normal", "config": BASE_CONFIG, "variant": DynamicWall.WallVariant.BASE, "visual": "res://tools/labs/dynamic_arena/assets/normalized/wall_base.png"},
	&"fire": {"name": "Mur feu", "config": FIRE_CONFIG, "variant": DynamicWall.WallVariant.FIRE, "visual": "res://tools/labs/dynamic_arena/assets/normalized/wall_fire.png"},
	&"ice": {"name": "Mur glace", "config": ICE_CONFIG, "variant": DynamicWall.WallVariant.ICE, "visual": "res://tools/labs/dynamic_arena/assets/normalized/wall_ice.png"},
}


static func has(wall_id: StringName) -> bool:
	return ENTRIES.has(wall_id)


static func get_entry(wall_id: StringName) -> Dictionary:
	return (ENTRIES.get(wall_id, {}) as Dictionary).duplicate(false)


static func all_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(ENTRIES.keys())
	return result


static func config_for(wall_id: StringName) -> WallConfig:
	return get_entry(wall_id).get("config") as WallConfig


static func id_for_variant(variant: int) -> StringName:
	for wall_id in ENTRIES:
		if int(ENTRIES[wall_id].variant) == variant:
			return wall_id
	return &""


static func id_for_config(config: WallConfig) -> StringName:
	if config == null:
		return &""
	for wall_id in ENTRIES:
		if ENTRIES[wall_id].config == config \
				or (ENTRIES[wall_id].config as WallConfig).variant_id == config.variant_id:
			return wall_id
	return &""
